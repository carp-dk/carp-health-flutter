package cachet.plugins.health.reading

import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthConstants
import java.time.Instant
import kotlin.reflect.KClass
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * getDataPage and getData over records that share a start time, from a Health Connect whose page tokens lose
 * count of them and skip rows of the read's join, as Android 15 does ([tiedTokenStore]): every data point comes
 * once, no page token comes twice, and no request carries an offset. The data are those of the device runs.
 */
class TiedTokenReadsTest {
    private val eight = Instant.parse("2016-11-02T08:00:00Z")
    private val start = eight.minusSeconds(3600)
    private val end = eight.plusSeconds(7200)
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    private fun store(type: KClass<out Record>, records: List<Record>, sdkInt: Int = 35): PageReplies =
        PageReplies(tiedTokenStore(records, fakeRecordStore(type, records), requests), sdkInt = sdkInt)

    private fun sources(replies: List<PageReply>): List<String> =
        replies.flatMap { page -> page.points.map { it.source } }

    private fun assertRead(replies: List<PageReply>) {
        assertNull(replies.last().error)
        assertNull(replies.last().token)
        val tokens = replies.map { it.token }
        assertEquals(tokens.distinct(), tokens)
        assertTrue("${requests.map { it.pageToken }}", noOffsets(requests))
    }

    @Test
    fun theMeasuredStepsComeOnceAtEveryPageSize() {
        // Five records at 08:00 and one at 08:10: on the device, round 3 failed with "The platform returned the
        // same page token twice" at pageSize 1 and 2.
        val records = tiedSteps(eight, 5) + tiedSteps(eight.plusSeconds(600), 1, first = 5)
        for (pageSize in 1..3) {
            requests.clear()
            val replies = store(StepsRecord::class, records).read(HealthConstants.STEPS, start, end, pageSize)
            assertRead(replies)
            assertEquals("$pageSize", (0..5).map { "app.s$it" }, sources(replies))
            // Newest first, the read with a limit.
            val limited =
                store(StepsRecord::class, records).read(HealthConstants.STEPS, start, end, pageSize, limit = 6)
            assertNull(limited.last().error)
            assertEquals("$pageSize", listOf(5, 0, 1, 2, 3, 4).map { "app.s$it" }, sources(limited))
        }
    }

    @Test
    fun speedSamplesComeOnce() {
        // Seven records of three samples at 09:00 and one at 09:10, read from 09:00, so that the first request asks
        // for one record: on the device, round 4 replied 41 points for these 24 samples at pageSize 20000.
        val nine = eight.plusSeconds(3600)
        val records = tiedSpeeds(nine, 7) + tiedSpeeds(nine.plusSeconds(600), 1, first = 7)
        for (pageSize in listOf(DEFAULT_PAGE_SIZE, 3)) {
            requests.clear()
            val replies = store(SpeedRecord::class, records).read(HealthConstants.SPEED, nine, end, pageSize)
            assertRead(replies)
            assertEquals("$pageSize", (0..7).flatMap { n -> List(3) { "app.v$n" } }, sources(replies))
            // The page of the seven is not read again with fewer records: they would come whole again.
            assertEquals("$pageSize", 1, tieReads(requests).size)
        }
    }

    @Test
    fun aSpeedPageThatEndsWithRecordsThatStartTogetherIsNotReadAgainIntoThem() {
        // One record at 09:00, four of 12,000 samples at 09:10 and one at 13:00: the second request asks for four
        // records and gets the four, more than twice pageSize samples, and fewer records would bring all four again.
        val nine = eight.plusSeconds(3600)
        val records = tiedSpeeds(nine, 1, samples = 1) + tiedSpeeds(nine.plusSeconds(600), 4, 12_000, first = 1) +
            tiedSpeeds(nine.plusSeconds(4 * 3600), 1, samples = 1, first = 5)
        val replies = store(SpeedRecord::class, records).read(HealthConstants.SPEED, nine, nine.plusSeconds(5 * 3600))
        assertRead(replies)
        val counts = sources(replies).groupingBy { it }.eachCount()
        assertEquals(mapOf("app.v0" to 1, "app.v5" to 1) + (1..4).associate { "app.v$it" to 12_000 }, counts)
        assertEquals(listOf(1, 4, 1), requests.filter { it.timeRangeFilter.startTime == nine }.map { it.pageSize })
        assertEquals(emptyList<ReadRecordsRequest<*>>(), tieReads(requests))
    }

    @Test
    fun sleepStagesComeOnce() {
        // Four nights from 22:00 and one from 23:30, each awake, light, then deep: on the device, round 4 replied
        // some light stages two or three times at pageSize 1 and 2.
        val ten = Instant.parse("2016-11-05T22:00:00Z")
        val nights = tiedNights(ten, 4) + tiedNights(ten.plusSeconds(5400), 1, first = 4)
        for (pageSize in listOf(1, 2)) {
            for (type in listOf(HealthConstants.SLEEP_LIGHT, HealthConstants.SLEEP_DEEP)) {
                requests.clear()
                val replies =
                    store(SleepSessionRecord::class, nights).read(type, ten, ten.plusSeconds(14_400), pageSize)
                assertRead(replies)
                assertEquals("$type $pageSize", (0..4).map { "app.n$it" }, sources(replies))
            }
        }
    }

    @Test
    fun poolSwimsComeOnceWithEveryLap() {
        // Three swims of two laps in two segments at 08:00 and one at 09:00: on the device, round 4 replied the
        // first two swims four times each at pageSize 1, some with one lap only.
        val swims = tiedSwims(eight, 3) + tiedSwims(eight.plusSeconds(3600), 1, first = 3)
        val replies = store(ExerciseSessionRecord::class, swims).read(HealthConstants.WORKOUT, start, end, 1)
        assertRead(replies)
        assertEquals((0..3).map { "app.w$it" }, sources(replies))

        val client = tiedTokenStore(swims)
        val read = mutableListOf<ExerciseSessionRecord>()
        var token: String? = null
        do {
            val range = TimeRangeFilter.between(start, end)
            val request = ReadRecordsRequest(ExerciseSessionRecord::class, range, emptySet(), true, 1, token)
            val page = runBlocking { client.readRecordsPage(request, 35) }
            read += page.records
            token = page.pageToken
        } while (token != null)
        assertEquals((0..3).map { "w$it" to 2 }, read.map { it.metadata.id to it.laps.size })
    }

    @Test
    fun heartRateSamplesComeOnce() {
        // A record of 100 samples a second at 13:00, five more 1 ms later and one at 13:30: on the device, round 4
        // replied 22,149 points for 500 samples of records that start together at pageSize 100. The first page
        // holds the first record alone, the second the five, read whole, and the next ones go on past them.
        val one = eight.plusSeconds(5 * 3600L).toEpochMilli()
        val tied = List(5) { heartRate("hr$it", one + 1, 100, end = one + 100_001L + it, packageName = "app.h$it") }
        val records = listOf(heartRate("lead", one, 100, packageName = "app.lead")) + tied +
            heartRate("late", one + 1_800_000, 100, packageName = "app.late")
        val expected = listOf("app.lead", "app.h0", "app.h1", "app.h2", "app.h3", "app.h4", "app.late")
            .flatMap { source -> List(100) { source } }.sorted()
        for (pageSize in listOf(100, 50, DEFAULT_PAGE_SIZE)) {
            requests.clear()
            val client = tiedTokenStore(records, fakeHeartRateStore(records), requests)
            val replies = PageReplies(client).read(
                HealthConstants.HEART_RATE, Instant.ofEpochMilli(one), Instant.ofEpochMilli(one + 3_600_000), pageSize,
            )
            assertRead(replies)
            assertEquals("$pageSize", expected, sources(replies).sorted())
            // A page that held the five alone goes on just after them.
            val past = HealthConnectPosition(false, one + 2, 0).encode()
            assertEquals("$pageSize", pageSize < DEFAULT_PAGE_SIZE, requests.any { it.pageToken == past })
        }
    }

    @Test
    fun theDeprecatedGetDataReadsEveryTieOnce() {
        // 3,000 records a millisecond apart, then 4,000 at 08:00, of which the first request holds 2,000.
        val early = (0 until 3000).flatMap { tiedSteps(start.plusMillis(it.toLong()), 1, first = it) }
        val records = early + tiedSteps(eight, 4000, first = 3000) + tiedSteps(end.minusSeconds(60), 1, first = 7000)
        val points = store(StepsRecord::class, records).legacy(HealthConstants.STEPS, start, end)

        assertEquals((0..7000).map { "app.s$it" }, points.map { it.source })
        assertEquals(listOf(HC_MAX_RECORDS, HC_MAX_RECORDS, HC_MAX_RECORDS), requests.map { it.pageSize })
        assertEquals(1, tieReads(requests).size)
        assertTrue(noOffsets(requests))
    }

    @Test
    fun theDeprecatedGetDataWithALimitReadsOneRequest() {
        // Its one page ends inside the records of 08:00, but no next page is read: they need not come whole.
        val records = tiedSteps(eight, 5) + tiedSteps(eight.plusSeconds(600), 1, first = 5)
        val points = store(StepsRecord::class, records).legacy(HealthConstants.STEPS, start, end, limit = 2)

        assertEquals(listOf("app.s5", "app.s0"), points.map { it.source })
        assertEquals(listOf(2), requests.map { it.pageSize })
    }
}
