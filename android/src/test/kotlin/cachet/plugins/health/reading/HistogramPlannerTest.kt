package cachet.plugins.health.reading

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HistogramPlannerTest {
    private val hour = 3_600_000L

    /** Samples at [times]; counts the histograms the planner asks for. */
    private class Data(val times: List<Long>) {
        var histograms = 0

        suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long> {
            histograms++
            val counts = LongArray(((to - from + bucket - 1) / bucket).toInt())
            for (time in times) if (time in from until to) counts[((time - from) / bucket).toInt()]++
            return counts.asList()
        }

        fun plan(cursor: Long, end: Long, window: Long, budget: Int) =
            runBlocking { HistogramPlanner.plan(cursor, end, window, budget, ::histogram) }

        fun samples(from: Long, to: Long) = times.count { it in from until to }.toLong()
    }

    private fun everySecond(from: Long, seconds: Int) = List(seconds) { from + it * 1000L }

    /** The slices of [plan] from [cursor], each with at most [budget] samples, and the first counted right. */
    private fun assertSlices(data: Data, cursor: Long, plan: SlicePlan, budget: Int) {
        val starts = listOf(cursor) + plan.ends.dropLast(1)
        for ((from, to) in starts.zip(plan.ends)) {
            assertTrue("[$from, $to) holds ${data.samples(from, to)}", to > from && data.samples(from, to) <= budget)
        }
        assertEquals(data.samples(cursor, plan.ends.first()), plan.firstSamples)
    }

    @Test
    fun plansManyPagesFromOneHistogram() {
        val data = Data(everySecond(0, 36_000))
        val plan = data.plan(0, 10 * hour, 10 * hour, 2000)!!
        assertSlices(data, 0, plan, 2000)
        assertEquals(MAX_PLANNED_SLICES, plan.ends.size)
        assertTrue("${plan.firstSamples}", plan.firstSamples > 1500)
        assertEquals(1, data.histograms)
        // A page holds 2000 samples at one per second.
        assertEquals(2_000_000L, plan.pageSpan)
    }

    @Test
    fun plansTheWholeWindowWhenItFitsOnePage() {
        val data = Data(everySecond(0, 100))
        val plan = data.plan(0, 10 * hour, 10 * hour, 2000)!!
        assertEquals(listOf(10 * hour), plan.ends)
        assertEquals(100L, plan.firstSamples)
    }

    @Test
    fun plansADenseFirstBucketAgainInFinerBuckets() {
        // 5000 samples in the first ten seconds, then one per minute.
        val data = Data(List(5000) { it * 2L } + List(60) { 60_000L * (it + 1) })
        val plan = data.plan(0, hour, hour, 1000)!!
        assertSlices(data, 0, plan, 1000)
        assertEquals(2, data.histograms)
    }

    @Test
    fun stopsBeforeADenseBucketLaterInTheWindow() {
        // One sample per minute, and 5000 samples in a second at half past.
        val dense = 30 * 60_000L
        val data = Data(List(60) { it * 60_000L } + List(5000) { dense + it / 10 })
        val plan = data.plan(0, hour, hour, 1000)!!
        assertSlices(data, 0, plan, 1000)
        assertTrue("${plan.ends}", plan.ends.last() <= dense && plan.ends.last() > dense - hour / PLAN_BUCKETS)
        assertEquals(1, data.histograms)
    }

    @Test
    fun takesSamplesOfOneMomentAsOneSlice() {
        // No slice of a second or more holds fewer: the reader reads it with fewer records per request.
        val data = Data(List(5000) { 10_000L })
        val plan = data.plan(10_000L, hour, hour, 1000)!!
        assertEquals(1, plan.ends.size)
        assertEquals(5000L, plan.firstSamples)
        assertTrue("${plan.ends}", plan.ends.first() - 10_000L <= MIN_SLICE_MS)
    }

    @Test
    fun returnsNullForAWindowWithoutSamples() {
        val data = Data(everySecond(2 * hour, 10))
        assertNull(data.plan(0, 10 * hour, hour, 2000))
    }

    @Test
    fun extendsTheLastSliceOverAnEmptyRest() {
        // Samples in the first quarter of the window only: the next plan starts after the window.
        val data = Data(everySecond(0, 900))
        val plan = data.plan(0, 10 * hour, hour, 400)!!
        assertSlices(data, 0, plan, 400)
        assertEquals(hour, plan.ends.last())
    }
}
