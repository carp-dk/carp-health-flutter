package cachet.plugins.health.reading

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SlicePlannerTest {
    private val hour = 3_600_000L
    private val year = 365 * 24 * hour

    /** Samples at [times], each also the start of a record; counts the calls the planner makes. */
    private class Data(val times: List<Long>) {
        var calls = 0

        suspend fun count(from: Long, to: Long): Long {
            calls++
            return times.count { it in from until to }.toLong()
        }

        suspend fun first(from: Long, to: Long): Long? {
            calls++
            return times.filter { it in from until to }.minOrNull()
        }

        fun plan(cursor: Long, end: Long, span: Long, budget: Int) =
            runBlocking { SlicePlanner.plan(cursor, end, span, budget, ::count, ::first) }
    }

    private fun everySecond(from: Long, seconds: Int) = List(seconds) { from + it * 1000L }

    @Test
    fun takesTheWholeRangeWhenItFits() {
        val data = Data(everySecond(0, 100))
        assertEquals(PlannedSlice(0, 10 * hour, 100), data.plan(0, 10 * hour, 10 * hour, 1000))
        assertEquals(1, data.calls)
    }

    @Test
    fun narrowsADenseRangeToThePageSize() {
        val data = Data(everySecond(0, 36_000))
        val slice = data.plan(0, 10 * hour, 10 * hour, 2000)
        assertTrue("$slice", slice.samples in 500..2000)
        assertEquals(slice.samples, data.times.count { it < slice.end }.toLong())
        assertTrue("${data.calls} calls", data.calls <= 3)
    }

    @Test
    fun skipsALongGapWithOneProbe() {
        // Ten years with data only in the last hour, one sample per second.
        val data = Data(everySecond(10 * year - hour, 3600))
        val slice = data.plan(0, 10 * year, 10 * year, 2000)
        assertTrue("$slice", slice.samples in 500..2000 && slice.end > 10 * year - hour)
        assertTrue("${data.calls} calls", data.calls <= 6)
    }

    @Test
    fun reportsWhenNoRecordStartsInTheRest() {
        val data = Data(everySecond(0, 10))
        val slice = data.plan(hour, 10 * year, hour, 2000)
        assertEquals(PlannedSlice(hour, 10 * year, 0, hasRecords = false), slice)
        assertEquals(2, data.calls)
    }

    @Test
    fun takesAnEmptyRestWithoutProbing() {
        // Reading an empty range costs one call, the same as finding out that it is empty.
        val data = Data(everySecond(0, 10))
        assertEquals(PlannedSlice(hour, 10 * year, 0), data.plan(hour, 10 * year, 10 * year - hour, 2000))
        assertEquals(1, data.calls)
    }

    @Test
    fun widensASparseSliceTowardsThePageSize() {
        val data = Data(List(1000) { it * 60_000L })
        // One minute at the start holds a single sample; the slice grows instead of reading it alone.
        val slice = data.plan(0, 1000 * 60_000L, 60_000L, 400)
        assertTrue("$slice", slice.samples in 100..400)
    }

    @Test
    fun takesAnOversizedSliceWhenTimeCannotSplitIt() {
        // 5000 samples in the same millisecond: no slice of at least a second holds less.
        val data = Data(List(5000) { 10_000L })
        val slice = data.plan(10_000L, hour, hour, 1000)
        assertEquals(10_000L, slice.start)
        assertTrue("$slice", slice.end - slice.start <= MIN_SLICE_MS)
        assertEquals(5000L, slice.samples)
    }

    @Test
    fun narrowsQuicklyToSamplesThatSitAtTheStart() {
        // Just over a page of samples in one millisecond at the start, then ten years of sparse data.
        val data = Data(List(1001) { 0L } + List(10_000) { (it + 1) * 10 * 3_600_000L * 24 * 365 / 10_000 })
        val slice = data.plan(0, 10 * year, 10 * year, 1000)
        assertEquals(PlannedSlice(0, MIN_SLICE_MS, 1001), slice)
        assertTrue("${data.calls} calls", data.calls <= 4)
    }

    @Test
    fun stopsAfterTheStepLimit() {
        // A count that never fills a page (a few samples in any slice) keeps the slice growing.
        var calls = 0
        val slice = runBlocking {
            SlicePlanner.plan(0, 100 * year, 60_000L, 400, { _, _ -> calls++; 10L }) { _, _ -> error("not needed") }
        }
        assertEquals(MAX_PLAN_STEPS, calls)
        assertEquals(PlannedSlice(0, 60_000L * 1L.shl(2 * (MAX_PLAN_STEPS - 1)), 10), slice)
    }

    @Test
    fun readsAnEmptyRecordInsteadOfSearchingOn() {
        // A record starts in the first second but its samples are counted nowhere (it has none).
        var probes = 0
        val slice = runBlocking {
            SlicePlanner.plan(0, year, hour, 400, { _, _ -> 0L }) { _, _ -> probes++; 500L }
        }
        assertEquals(PlannedSlice(0, hour, 0), slice)
        assertEquals(1, probes)
        assertFalse(slice.samples > 0)
    }

    @Test
    fun nextSpanGrowsAtMostFourfoldAndNeverBelowASecond() {
        assertEquals(4000L, SlicePlanner.nextSpan(1000, 0, 2000))
        assertEquals(4000L, SlicePlanner.nextSpan(1000, 1, 2000))
        assertEquals(1500L, SlicePlanner.nextSpan(2000, 2000, 2000))
        assertEquals(MIN_SLICE_MS, SlicePlanner.nextSpan(1000, 1_000_000, 2000))
    }
}
