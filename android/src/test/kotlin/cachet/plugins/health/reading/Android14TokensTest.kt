package cachet.plugins.health.reading

import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Velocity
import cachet.plugins.health.HealthConstants
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Reads over records that share a start time from Health Connect as android14-release reads them
 * ([readByStartTime]): more of them than a request holds give an empty page with the token of their time,
 * and one more request reads them whole ([readPastTies]), as on later versions.
 */
class Android14TokensTest {
    private val eight = Instant.parse("2016-11-02T08:00:00Z")
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    private fun token(at: Long): String = HealthConnectPosition(false, at, 0).encode()

    private fun covers(request: ReadRecordsRequest<*>, at: Long): Boolean = request.timeRangeFilter.let {
        it.startTime!!.toEpochMilli() <= at && at < it.endTime!!.toEpochMilli()
    }

    @Test
    fun recordsOfOneStartTimeComeOnlyTogether() {
        // 07:00, five at 08:00, 08:10.
        val records = listOf(steps(eight.minusSeconds(3600), "a")) + List(5) { steps(eight, "s${it + 1}") } +
            steps(eight.plusSeconds(600), "z")
        val range = TimeRangeFilter.between(eight.minusSeconds(7200), eight.plusSeconds(7200))
        val tie = eight.toEpochMilli()
        fun read(pageSize: Int, token: String?): Pair<List<String>, String?> {
            val request = ReadRecordsRequest(StepsRecord::class, range, emptySet(), true, pageSize, token)
            val page = readByStartTime(records, request)
            return page.records.map { it.metadata.id } to page.pageToken
        }
        val s = (1..5).map { "s$it" }
        assertEquals(listOf("a") to token(tie), read(1, null))
        // The records of 08:00 do not fit after 07:00: the token is 08:00.
        assertEquals(listOf("a") to token(tie), read(3, null))
        // More of them than the request holds: an empty page with the request's own token.
        assertEquals(emptyList<String>() to token(tie), read(3, token(tie)))
        assertEquals(emptyList<String>() to token(tie), read(4, token(tie)))
        assertEquals(s to token(eight.plusSeconds(600).toEpochMilli()), read(5, token(tie)))
        assertEquals(s + "z" to null, read(6, token(tie)))
    }

    @Test
    fun aFirstRequestThatGetsNoneOfTheRecordsOfItsFirstStartTimeReadsThemWhole() {
        // Three records at 08:00 and one at 08:10, one a request: an empty page with the token of 08:00, then all
        // three in one more request, then the page just after 08:00.
        val records = List(3) { steps(eight, "s$it") } + steps(eight.plusSeconds(600), "z")
        val client = tiedTokenStore(records, requests = requests, reads = ::readByStartTime)
        val range = TimeRangeFilter.between(eight.minusSeconds(3600), eight.plusSeconds(3600))
        val pages = mutableListOf<List<String>>()
        var token: String? = null
        do {
            val page = runBlocking {
                client.readPastTies(ReadRecordsRequest(StepsRecord::class, range, emptySet(), true, 1, token))
            }
            pages += page.records.map { it.metadata.id }
            token = page.pageToken
        } while (token != null)

        assertEquals(listOf(listOf("s0", "s1", "s2"), listOf("z")), pages)
        val at = eight.toEpochMilli()
        assertEquals(listOf(null, null, token(at + 1)), requests.map { it.pageToken })
        assertEquals(listOf(1, HC_MAX_RECORDS, 1), requests.map { it.pageSize })

        // As many as one request holds come whole in it, which reads one more to tell; more get an empty page with
        // the token of 08:00 again.
        val first = ReadRecordsRequest(StepsRecord::class, range, emptySet(), true, 1, null)
        val most = tiedTokenStore(List(HC_MAX_RECORDS) { steps(eight, "s$it") }, reads = ::readByStartTime)
        assertEquals(HC_MAX_RECORDS, runBlocking { most.readPastTies(first) }.records.size)
        val many = tiedTokenStore(List(HC_MAX_RECORDS + 1) { steps(eight, "s$it") }, reads = ::readByStartTime)
        val error = assertThrows(IllegalStateException::class.java) { runBlocking { many.readPastTies(first) } }
        assertTrue(error.message!!, error.message!!.startsWith("More than 5000 StepsRecord records start at"))
    }

    @Test
    fun getDataWithALimitReadsTheRecordsOfTheNewestStartTimeWhole() {
        // Two weights at 08:00, the newest: a request for one gets none of them and the token of 08:00, so one more
        // request reads both, and the first is kept.
        val weights = List(2) { WeightRecord(eight, null, Mass.kilograms(70.0 + it), writtenBy("app.w$it", "w$it")) } +
            WeightRecord(eight.minusSeconds(600), null, Mass.kilograms(69.0), writtenBy("app.old", "old"))
        // The record store only grants reading weights; the reads are those of android14-release.
        val permissions = fakeRecordStore(WeightRecord::class, emptyList())
        val client = tiedTokenStore(weights, permissions, requests, ::readByStartTime)
        val points = PageReplies(client, sdkInt = 34)
            .legacy(HealthConstants.WEIGHT, eight.minusSeconds(3600), eight.plusSeconds(3600), limit = 1)

        assertEquals(listOf("app.w0"), points.map { it.source })
        assertEquals(listOf(1, HC_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun theHeartRateLookbackReadsTiedRecordsWhole() {
        // Six records of another app that began an hour before the read, each of 10,000 samples: one look-back
        // slice, whose first request of 1 record gets none of them, and one more request all six.
        val tie = eight.toEpochMilli() - 3_600_000
        val tied = List(6) { heartRate("tie$it", tie, 10_000, end = tie + 10_000_000L + it, packageName = "app.other") }
        val inner = fakeHeartRateStore(tied, counting = Counting.ANDROID_15)
        val client = tiedTokenStore(tied, inner, requests, ::readByStartTime)
        val lookback = HeartRateLookback(HealthConnectHeartRateSource(client), sdkInt = 34)
        val found = runBlocking { lookback.find(eight.toEpochMilli(), 100, null, eight.toEpochMilli() + 3_600_000) }

        assertEquals(tied.map { it.metadata.id }, found.map { it.metadata.id })
        val tieReads = requests.filter { covers(it, tie) }
        assertEquals(listOf(1, HC_MAX_RECORDS, 2), tieReads.map { it.pageSize })
        assertEquals(listOf(null, null, token(tie + 1)), tieReads.map { it.pageToken })
    }

    @Test
    fun aSeriesReadReadsTiedRecordsWhole() {
        // A speed record of 10,000 samples, then three that start together: the second page asks for 2 records
        // (pageSize / 10,000), gets none with its own token, and reads the three in one more request.
        val start = eight.minusSeconds(3600)
        val records = listOf(speed(start, 10_000, "app.long")) + List(3) { speed(eight, 1, "app.t$it") }
        val client = tiedTokenStore(records, fakeRecordStore(SpeedRecord::class, records), requests, ::readByStartTime)
        val replies = PageReplies(client, sdkInt = 34).read(HealthConstants.SPEED, start, eight.plusSeconds(3600))

        assertNull(replies.last().error)
        val counts = replies.flatMap { it.points }.groupingBy { it.source }.eachCount()
        assertEquals(mapOf("app.long" to 10_000) + (0..2).associate { "app.t$it" to 1 }, counts)
        val reads = requests.filter { it.timeRangeFilter.startTime == start }
        assertEquals(listOf(1, 2, 5), reads.map { it.pageSize })
        val tie = eight.toEpochMilli()
        assertEquals(listOf(null, token(tie), token(tie + 1)), reads.map { it.pageToken })
        assertEquals(1, tieReads(requests).size)
        val tokens = replies.mapNotNull { it.token }
        assertEquals(tokens.distinct(), tokens)
    }

    @Test
    fun heartRateSlicesReadTiedRecordsWhole() {
        // A record of 1,000 samples and, 1 ms later, six of one sample, in one slice at 100 samples a page: the
        // first page reads the long record alone, the next one none of the six, and then all six in one more.
        val long = heartRate("long", eight.toEpochMilli() + 200, 1000, packageName = "app.long")
        val at = eight.toEpochMilli() + 201
        val tied = List(6) { heartRate("t$it", at, 1, packageName = "app.t$it") }
        val records = listOf(long) + tied
        val inner = fakeHeartRateStore(records, counting = Counting.ANDROID_15)
        val client = tiedTokenStore(records, inner, requests, ::readByStartTime)
        val replies = PageReplies(client, sdkInt = 34)
            .read(HealthConstants.HEART_RATE, eight.minusSeconds(3600), eight.plusSeconds(7200), pageSize = 100)

        assertNull(replies.last().error)
        val counts = replies.flatMap { it.points }.groupingBy { it.source }.eachCount()
        assertEquals(mapOf("app.long" to 1000) + (0..5).associate { "app.t$it" to 1 }, counts)
        assertEquals(listOf(1), requests.filter { it.pageToken == token(at) }.map { it.pageSize })
        assertEquals(1, tieReads(requests).size)
        val tokens = replies.mapNotNull { it.token }
        assertEquals(tokens.distinct(), tokens)
    }

    @Test
    fun aPageOfRecordsThatStartTogetherIsNotReadAgainWithFewer() {
        // Two records of 300 samples that start together, at 100 samples a page: a read again with one record would
        // get none, and both in one more request, so the page is kept as read, with or without a token.
        val at = eight.toEpochMilli()
        val tied = List(2) { heartRate("t$it", at, 300, packageName = "app.t$it") }
        val source = HealthConnectHeartRateSource(tiedTokenStore(tied, requests = requests, reads = ::readByStartTime))
        for (token in listOf(null, token(at))) {
            requests.clear()
            val read = runBlocking { HeartRateChain.read(source, at - 1000, at + 1000, 4, token, 100, 34) }

            assertEquals(listOf("t0", "t1"), read.page.records.map { it.metadata.id })
            assertNull(read.page.pageToken)
            assertEquals(4, read.records)
            assertEquals(listOf(4), requests.map { it.pageSize })
        }
    }

    private fun steps(at: Instant, id: String) =
        StepsRecord(at, null, at.plusSeconds(60), null, 1, writtenBy("app", id))

    // A speed record of [samples] samples, one every 100 ms from [start].
    private fun speed(start: Instant, samples: Int, packageName: String): Record = SpeedRecord(
        start, null, start.plusMillis(100L * samples), null,
        List(samples) { SpeedRecord.Sample(start.plusMillis(100L * it), Velocity.metersPerSecond(2.0)) },
        writtenBy(packageName, packageName),
    )
}
