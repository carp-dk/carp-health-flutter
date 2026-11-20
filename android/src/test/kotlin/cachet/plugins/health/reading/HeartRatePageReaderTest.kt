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

    private fun readAll(
        records: List<HeartRateRecord>,
        start: Long,
        end: Long,
        budget: Int,
        sdkInt: Int = 37,
        ownOnly: Boolean = false,
    ) = readHeartRate(FakeHeartRateSource(records), start, end, budget, sdkInt, ownOnly)

    private fun samples(records: List<HeartRateRecord>, start: Long, end: Long) = samplesOf(records, start, end)

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
    fun skipsTheLookBackWhenNoRecordOfTheAppReachesIntoTheRead() {
        // Only in a read of the app's own records, which Health Connect counts by their samples' time.
        val records = singles("spot", t0, 3 * 24 * 60, minute)
        val read = readAll(records, t0 + day, t0 + 2 * day, budget = 20000, ownOnly = true)
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
        // 50 records of ten minutes that all start together: one slice, too large to read at once. On the Health
        // Connect APK (before Android 14), whose tokens are no positions; from Android 14 on such records come whole
        // ([readPastTies]), and fewer records would bring them all again (HeartRateChainTest).
        val records = List(50) { heartRate("tie$it", t0, 600) }
        val read = readAll(records, t0, t0 + hour, budget = 2000, sdkInt = 33)
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
    fun aChainGoesOnAtFullSpeedAfterALongRecord() {
        // Review finding: a day at 1 Hz in one record, then 330 records of one sample in the same slice. The
        // slice is read again with the long record alone, and then went on at one record a request.
        val records = listOf(heartRate("day", t0 + hour, 86_400)) + singles("spot", t0 + hour + minute, 330, minute)
        val read = readAll(records, t0, t0 + 2 * day, budget = 20000)
        assertEverySampleOnce(records, read, t0, t0 + 2 * day)
        assertTrue("${read.pages.size} pages", read.pages.size <= 10)
    }

    @Test
    fun aRecordThatBeganBeforeTheReadCostsFewCallsAtAnyPageSize() {
        // Six hours at 1 Hz in one record, read from three hours in: once 10,809 calls at pageSize 3.
        val records = listOf(heartRate("six", t0, 6 * 3600))
        for (budget in listOf(3, 10, 20000)) {
            val read = readAll(records, t0 + 3 * hour, t0 + day, budget)
            assertEverySampleOnce(records, read, t0 + 3 * hour, t0 + day)
            assertTrue("$budget: ${read.source.calls} calls", read.source.calls <= 8)
        }
    }

    @Test
    fun aReadOfManyPagesLooksBackOverTheWholeDayWithinItsCalls() {
        // A record every two seconds: the first slice takes four requests and is a part of the read, so no
        // count rules out records that began earlier. The first page reads all 43,200 records of the day before.
        val records = singles("spot", t0, 64_800, 2000)
        val night = heartRate("night", t0 + day - hour, 120, stepMs = minute)
        for (data in listOf(records, records + night)) {
            val read = readAll(data, t0 + day, t0 + 2 * day, budget = 20000)
            assertEverySampleOnce(data, read, t0 + day, t0 + 2 * day)
            assertTrue(read.source.reads.any { it.from == t0 })
        }
    }

    @Test
    fun findsARecordThatBeganEarlierWithNoSampleInTheFirstSlice() {
        // Review finding: a watch's record from an hour before the read, off the wrist for its first six hours
        // there, and six hours of this app at 1 Hz. The first slice's count held only the app's samples, so the
        // watch's twelve samples after the gap were lost on Android 16 and later.
        val start = t0 + day
        val times = List(6) { start - hour + it * 10 * minute } + List(12) { start + 6 * hour + it * 10 * minute }
        val watch = HeartRateRecord(
            Instant.ofEpochMilli(start - hour), null, Instant.ofEpochMilli(start + 8 * hour), null,
            times.map { HeartRateRecord.Sample(Instant.ofEpochMilli(it), 70) },
            writtenBy("com.example.watch", "watch"),
        )
        val records = listOf(watch, heartRate("app", start, 6 * 3600))
        for (budget in listOf(300, 20000)) {
            val read = readAll(records, start, start + day, budget)
            assertEverySampleOnce(records, read, start, start + day)
            assertEquals(12, samples(read.records, start, start + day).count { it.first == "watch" })
        }
    }

    @Test
    fun findsARecordThatBeganEarlierBehindAFirstSliceOfManyRequests() {
        // Review finding: two apps' six-hour workouts at 1 Hz from a few seconds in, and a band's record from
        // 53 minutes before with a sample every ten minutes. The first slice is read a record a request, and a
        // count up to the start of the last record read covered five seconds: the band's samples were lost.
        val start = t0 + day
        val records = listOf(
            heartRate("band", start - 53 * minute, 12, stepMs = 10 * minute, packageName = "com.example.band"),
            heartRate("watch", start + 5_000, 6 * 3600, packageName = "com.example.watch"),
            heartRate("phone", start + 8_000, 6 * 3600, packageName = "com.example.phone"),
        )
        val read = readAll(records, start, start + day, budget = 20000)
        assertEverySampleOnce(records, read, start, start + day)
        assertEquals(6, samples(read.records, start, start + day).count { it.first == "band" })
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
    fun anEmptyReadCostsTwoCallsAndTheLookBack() {
        val records = singles("spot", t0, 10, minute)
        val own = readAll(records, t0 + day, t0 + 2 * day, budget = 20000, ownOnly = true)
        assertEquals(listOf<HeartRateRecord>(), own.records)
        assertEquals(2, own.source.calls)
        // A read of every app's records also reads the day before: a histogram and the records there.
        val all = readAll(records, t0 + day, t0 + 2 * day, budget = 20000)
        assertEquals(listOf<HeartRateRecord>(), all.records)
        assertEquals(4, all.source.calls)
    }
}
