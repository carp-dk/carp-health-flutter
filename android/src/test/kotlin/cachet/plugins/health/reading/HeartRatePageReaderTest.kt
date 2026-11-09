package cachet.plugins.health.reading

import androidx.health.connect.client.records.HeartRateRecord
import cachet.plugins.health.HealthErrors
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class HeartRatePageReaderTest {
    private val minute = 60_000L
    private val hour = 60 * minute
    private val day = 24 * hour
    private val t0 = 1_456_790_400_000L // 2016-03-01, the window of the device tests

    private class Read(val pages: List<HeartRatePage>, val source: FakeHeartRateSource) {
        val records get() = pages.flatMap { it.records }
        val maxRequest get() = source.reads.maxOf { it.samples }
    }

    /** Reads [start, end) page by page, sending each token back in its encoded form, as Dart does. */
    private fun readAll(records: List<HeartRateRecord>, start: Long, end: Long, budget: Int, sdkInt: Int = 37): Read {
        val source = FakeHeartRateSource(records)
        val reader = HeartRatePageReader(source, sdkInt)
        val pages = mutableListOf<HeartRatePage>()
        var token: String? = null
        do {
            val page = runBlocking {
                reader.readPage(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end), budget, SliceToken.decode(token))
            }
            pages += page
            val next = page.next?.encode()
            assertTrue("The token did not move: $next", next == null || next != token)
            token = next
        } while (token != null && pages.size < 10_000)
        return Read(pages, source)
    }

    /** (record id, sample time) of each sample in [start, end) that [records] hold, as the converter keeps them. */
    private fun samples(records: List<HeartRateRecord>, start: Long, end: Long) =
        records.flatMap { record ->
            record.samples.map { it.time.toEpochMilli() }.filter { it in start until end }.map { record.metadata.id to it }
        }.sortedWith(compareBy({ it.second }, { it.first }))

    private fun assertEverySampleOnce(records: List<HeartRateRecord>, read: Read, start: Long, end: Long) =
        assertEquals(samples(records, start, end), samples(read.records, start, end))

    /** [count] single-sample records, one every [every] ms. */
    private fun singles(id: String, from: Long, count: Int, every: Long) = List(count) { heartRate("$id$it", from + it * every, 1) }

    /** [count] back-to-back records of [samples] samples at 1 Hz. */
    private fun series(id: String, from: Long, count: Int, samples: Int) =
        List(count) { heartRate("$id$it", from + it * samples * 1000L, samples) }

    @Test
    fun readsEverySampleOnceAcrossSparseDenseAndGaps() {
        val records = singles("spot", t0, 600, minute) + series("watch", t0 + 10 * hour, 30, 600) +
            singles("later", t0 + 30 * day, 300, minute)
        val read = readAll(records, t0, t0 + 40 * day, budget = 1000)
        assertEverySampleOnce(records, read, t0, t0 + 40 * day)
        // A slice holds at most a page of samples, plus the rest of the one record that crosses its end.
        assertTrue("${read.maxRequest}", read.maxRequest <= 1000 + 600)
        assertTrue("${read.source.calls} calls for ${read.pages.size} pages", read.source.calls <= 3 * read.pages.size)
    }

    @Test
    fun sparseThenDenseNeverBuildsAHugeRequest() {
        // Review finding: after 2000 one-sample records, record-count paging asked for 500 dense records at once.
        val records = singles("phone", t0, 2000, minute) + series("device", t0 + 2000 * minute, 100, 600)
        val read = readAll(records, t0, t0 + 10 * day, budget = 2000)
        assertEverySampleOnce(records, read, t0, t0 + 10 * day)
        assertTrue("${read.maxRequest}", read.maxRequest <= 2000 + 600)
    }

    @Test
    fun findsALongRecordBehindManyShortOnes() {
        // Review finding: one-sample records every minute hid a record from 22:00 to 07:00 from a 100-record probe.
        val night = heartRate("night", t0 + 22 * hour, 9 * 60, stepMs = minute)
        val records = singles("spot", t0, 2 * 24 * 60, minute) + night
        val read = readAll(records, t0 + day, t0 + 2 * day, budget = 20000)
        assertEverySampleOnce(records, read, t0 + day, t0 + 2 * day)
        assertEquals(7 * 60, samples(read.records, t0 + day, t0 + 2 * day).count { it.first == "night" })
    }

    @Test
    fun skipsTheLookBackWhenNoRecordReachesIntoTheRead() {
        val records = singles("spot", t0, 3 * 24 * 60, minute)
        val read = readAll(records, t0 + day, t0 + 2 * day, budget = 20000)
        assertEverySampleOnce(records, read, t0 + day, t0 + 2 * day)
        assertTrue(read.source.reads.none { it.from < t0 + day })
        assertEquals(2, read.source.calls)
    }

    @Test
    fun keepsARecordThatEndsAtTheStartWithASampleThere() {
        // Its last sample is at the start: the window before leaves it out, so this one must not.
        val start = t0 + day
        val edge = heartRate("edge", start - 10 * minute, 11, stepMs = minute, end = start)
        val read = readAll(listOf(edge), start, start + hour, budget = 20000)
        assertEquals(listOf("edge" to start), samples(read.records, start, start + hour))
    }

    @Test
    fun readsADenseTieGroupInSmallRequests() {
        // 50 records of ten minutes that all start together: one slice, too large to read at once.
        val records = List(50) { heartRate("tie$it", t0, 600) }
        val read = readAll(records, t0, t0 + hour, budget = 2000)
        assertEverySampleOnce(records, read, t0, t0 + hour)
        // Only the first request, made before anything was known, held more than twice the page size,
        // and it was read again with fewer records before anything was converted.
        assertTrue(read.source.reads.drop(1).all { it.samples <= 2 * 2000 })
        assertTrue(read.pages.all { page -> page.records.sumOf { it.samples.size } <= 2 * 2000 })
        assertTrue("${read.pages.size} pages", read.pages.size <= 25)
    }

    @Test
    fun readsRecordsThatStartOnASliceBoundaryOnce() {
        // A record every millisecond: every slice ends where a record starts.
        val records = singles("ms", t0, 5000, 1)
        val read = readAll(records, t0, t0 + hour, budget = 1000)
        assertEverySampleOnce(records, read, t0, t0 + hour)
        assertTrue("${read.pages.size} pages", read.pages.size in 5..10)
    }

    @Test
    fun keepsTheRecordCountOfAChainBeforeAndroid14() {
        val records = List(50) { heartRate("tie$it", t0, 600) } + singles("spot", t0 + hour, 3000, 1000)
        val read = readAll(records, t0, t0 + day, budget = 2000, sdkInt = 33)
        assertEverySampleOnce(records, read, t0, t0 + day)
        val reads = read.source.reads
        for ((i, request) in reads.withIndex()) {
            if (request.pageToken == null) continue
            val previous = reads.subList(0, i).last { it.from == request.from && it.to == request.to }
            assertEquals(previous.records, request.records)
        }
    }

    @Test
    fun sparseRecordsCostFewCallsOnEveryVersion() {
        // Review finding: 30 days of one-sample records every minute cost 2,161 calls before Android 14.
        val records = singles("spot", t0, 30 * 24 * 60, minute)
        for (sdkInt in listOf(33, 37)) {
            val read = readAll(records, t0, t0 + 30 * day, budget = 20000, sdkInt = sdkInt)
            assertEverySampleOnce(records, read, t0, t0 + 30 * day)
            assertTrue("$sdkInt: ${read.source.calls} calls", read.source.calls <= 20)
        }
    }

    @Test
    fun endsSoonAfterTheLastRecord() {
        val records = singles("spot", t0, 600, minute)
        val read = readAll(records, t0, t0 + 365 * day, budget = 100)
        assertEverySampleOnce(records, read, t0, t0 + 365 * day)
        assertTrue("${read.source.calls} calls", read.source.calls <= 40)
    }

    @Test
    fun denseDataCostsLittleMoreThanOneCallPerPage() {
        val records = series("watch", t0, 7 * 24 * 6, 600) // a week at 1 Hz in records of ten minutes
        val read = readAll(records, t0, t0 + 7 * day, budget = 20000)
        assertEverySampleOnce(records, read, t0, t0 + 7 * day)
        assertTrue("${read.maxRequest}", read.maxRequest <= 20000 + 600)
        val pages = read.pages.size
        // A page holds a whole page of samples, 20,000 give or take a record.
        assertTrue("$pages pages", pages <= 7 * 24 * 3600 / 18000 + 1)
        // One histogram plans about eight pages.
        assertTrue("${read.source.calls} calls for $pages pages", read.source.calls <= pages + pages / 4 + 2)
    }

    @Test
    fun aTokenPastTheEndIsAnInvalidArgument() {
        val reader = HeartRatePageReader(FakeHeartRateSource(emptyList()), 37)
        val error = assertThrows(IllegalArgumentException::class.java) {
            runBlocking { reader.readPage(Instant.ofEpochMilli(t0), Instant.ofEpochMilli(t0 + hour), 100, SliceToken(t0 + hour, 1000)) }
        }
        assertEquals(HealthErrors.INVALID_ARGUMENT, HealthErrors.codeFor(error, null))
    }

    @Test
    fun anEmptyReadCostsTwoCalls() {
        val read = readAll(singles("spot", t0, 10, minute), t0 + day, t0 + 2 * day, budget = 20000)
        assertEquals(listOf<HeartRateRecord>(), read.records)
        assertEquals(2, read.source.calls)
    }
}
