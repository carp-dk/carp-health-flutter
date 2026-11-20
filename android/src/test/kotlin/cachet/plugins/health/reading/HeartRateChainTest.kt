package cachet.plugins.health.reading

import androidx.health.connect.client.request.ReadRecordsRequest
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class HeartRateChainTest {
    private val t0 = 1_456_790_400_000L

    @Test
    fun nextRecordsGrowsFourfoldAsFarAsTheLargestRecordAllows() {
        assertEquals(4, HeartRateChain.nextRecords(1, 1, 20000, 34))
        assertEquals(20000 / 6000, HeartRateChain.nextRecords(100, 6000, 20000, 37))
        assertEquals(HC_MAX_RECORDS, HeartRateChain.nextRecords(4000, 1, 20000, 37))
        // A record larger than the budget: one at a time.
        assertEquals(1, HeartRateChain.nextRecords(16, 86_400, 20000, 37))
    }

    @Test
    fun nextRecordsIsFixedForAChainBeforeAndroid14() {
        assertEquals(5, HeartRateChain.nextRecords(5, 1, 20000, 33))
        assertEquals(5, HeartRateChain.nextRecords(5, 86_400, 20000, 33))
    }

    @Test
    fun readsAnOversizedPageAgainWithTheRecordsThatFit() {
        val records = List(10) { heartRate("r$it", t0 + it * 1000L, 600) }
        val source = FakeHeartRateSource(records)
        val read = runBlocking { HeartRateChain.read(source, t0, t0 + 60_000, HC_MAX_RECORDS, null, 1000, 37) }
        assertEquals(1, read.records)
        assertEquals(listOf("r0"), read.page.records.map { it.metadata.id })
        assertEquals(listOf(HC_MAX_RECORDS, 1), source.reads.map { it.records })
    }

    @Test
    fun aPageThatEndsInsideRecordsThatStartTogetherIsNotReadAgainWithFewer() {
        // Five records of 100 samples that start together, two a request at 100 samples a page: the page ends inside
        // them, so all five come in one more request ([readPastTies]), and fewer records would bring all five again.
        val tied = List(5) { heartRate("t$it", t0, 100, end = t0 + 100_000L + it, packageName = "app.t$it") }
        val requests = mutableListOf<ReadRecordsRequest<*>>()
        val source = HealthConnectHeartRateSource(tiedTokenStore(tied, requests = requests))
        val read = runBlocking { HeartRateChain.read(source, t0, t0 + 60_000, 2, null, 100, 37) }
        assertEquals(tied.map { it.metadata.id }, read.page.records.map { it.metadata.id })
        assertEquals(5, read.page.tied)
        assertEquals(listOf(2, HC_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun aPageThatEndsWithRecordsThatStartTogetherIsNotReadAgainIntoThem() {
        // Six records of 10,000 samples that start together, all of the slice: the page holds them with no token,
        // and fewer records would bring all six again.
        val requests = mutableListOf<ReadRecordsRequest<*>>()
        fun tied(at: Long, samples: Int) =
            List(6) { heartRate("t$it", at, samples, end = at + samples * 1000L + it, packageName = "app.t$it") }
        val six = tied(t0, 10_000)
        val alone = HealthConnectHeartRateSource(tiedTokenStore(six, requests = requests))
        val read = runBlocking { HeartRateChain.read(alone, t0, t0 + 60_000, HC_MAX_RECORDS, null, 1000, 37) }
        assertEquals(six.map { it.metadata.id }, read.page.records.map { it.metadata.id })
        assertEquals(HC_MAX_RECORDS, read.records)
        assertEquals(listOf(HC_MAX_RECORDS), requests.map { it.pageSize })

        // A record of 100 samples before six of 400: the three records that fit reach into the six, so neither.
        requests.clear()
        val records = listOf(heartRate("lead", t0, 100, packageName = "app.lead")) + tied(t0 + 1000, 400)
        val after = HealthConnectHeartRateSource(tiedTokenStore(records, requests = requests))
        val page = runBlocking { HeartRateChain.read(after, t0, t0 + 60_000, HC_MAX_RECORDS, null, 1000, 37) }
        assertEquals(7, page.page.records.size)
        assertEquals(listOf(HC_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun aReadAgainThatHoldsNoFewerRecordsKeepsThePage() {
        // Records written between the two reads: the read again with one record holds three as well.
        val source = object : HeartRateSource by FakeHeartRateSource(emptyList()) {
            val reads = mutableListOf<Int>()
            override suspend fun read(from: Long, to: Long, records: Int, pageToken: String?): HeartRateRecords {
                reads += records
                return HeartRateRecords(List(3) { heartRate("w$it", t0 + it * 1000L, 800) }, null)
            }
        }
        val read = runBlocking { HeartRateChain.read(source, t0, t0 + 60_000, 3, null, 1000, 37) }
        assertEquals(3, read.records)
        assertEquals(listOf(3, 1), source.reads)
    }

    @Test
    fun keepsTheRecordsOfAChainBeforeAndroid14() {
        val records = List(10) { heartRate("r$it", t0 + it * 1000L, 600) }
        val source = FakeHeartRateSource(records)
        val read = runBlocking { HeartRateChain.read(source, t0, t0 + 60_000, 5, "5", 1000, 33) }
        assertEquals(5, read.records)
        assertEquals(1, source.reads.size)
    }
}
