package cachet.plugins.health

import android.content.ContextWrapper
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.Change
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.response.ChangesResponse
import io.flutter.plugin.common.MethodCall
import java.lang.reflect.Proxy
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** getChanges reads a page of changes that holds too many data points again with fewer changes. */
class ChangesRetryTest {
    private val start = Instant.parse("2026-11-08T10:00:00Z")

    // A changed heart rate record of [samples] samples, one per second.
    private fun heartRate(samples: Int): Change = UpsertionChange(
        HeartRateRecord(
            startTime = start,
            startZoneOffset = null,
            endTime = start.plusSeconds(samples.toLong()),
            endZoneOffset = null,
            samples = List(samples) { HeartRateRecord.Sample(start.plusSeconds(it.toLong()), 60) },
            metadata = Metadata.unknownRecordingMethod(),
        )
    )

    /**
     * Calls getChanges while Health Connect answers [page] for the page size asked for (null if
     * none), and checks that it replied exactly once. Returns the reply and the page sizes asked for.
     */
    private fun getChanges(page: (pageSize: Int?) -> List<Change>): Pair<RecordingResult, List<Int?>> {
        val pageSizes = mutableListOf<Int?>()
        // getChanges(token, continuation) or getChanges(token, pageSize, continuation), answered at once.
        val client = Proxy.newProxyInstance(
            HealthConnectClient::class.java.classLoader,
            arrayOf(HealthConnectClient::class.java),
        ) { _, method, args ->
            check(method.name == "getChanges") { "Unexpected call of ${method.name}" }
            val pageSize = if (args.size == 3) args[1] as Int else null
            pageSizes.add(pageSize)
            ChangesResponse(page(pageSize), "next", hasMore = false, changesTokenExpired = false)
        } as HealthConnectClient
        val job = Job()
        val changes = HealthDataChanges(
            client, CoroutineScope(Dispatchers.Unconfined + job), ContextWrapper(null), HealthDataConverter(),
        )
        val reply = RecordingResult()
        changes.getChanges(MethodCall("getChanges", hashMapOf("changesToken" to "token")), reply)
        // getChanges replies on another thread, from a coroutine of its own: wait until that has ended, so
        // that a second reply is counted too (and the reply can be read).
        job.complete()
        runBlocking { withTimeout(30_000) { job.join() } }
        assertEquals("replies", 1, reply.replies)
        return reply to pageSizes
    }

    // The data points of a reply that is not an error.
    private fun RecordingResult.points(): Int {
        assertNull(code)
        return ((value as Map<*, *>)["changes"] as List<*>).size
    }

    @Test
    fun aTooLargePageIsReadAgainWithFewerChanges() {
        val small = heartRate(10)
        val big = heartRate(150_000)
        val (reply, pageSizes) = getChanges { pageSize -> if (pageSize == null) listOf(small, big) else listOf(small) }
        assertEquals(listOf(null, 1), pageSizes)
        assertEquals(10, reply.points())
    }

    @Test
    fun aPageIsReadAgainUntilItFits() {
        // The first 100 of 1000 changes hold 2000 points each and the other 900 hold 10, 209,000 in all:
        // four re-reads still hold too many points before the fifth fits.
        val changes = List(100) { heartRate(2000) } + List(900) { heartRate(10) }
        val (reply, pageSizes) = getChanges { pageSize -> changes.take(pageSize ?: changes.size) }
        assertEquals(listOf(null, 478, 234, 116, 57, 28), pageSizes)
        assertEquals(28 * 2000, reply.points())
    }

    @Test
    fun aPageIsReadAgainWhileItGetsSmaller() {
        // The page size is a soft limit: here each page holds more changes than asked for, but one fewer
        // than the page before.
        val changes = List(8) { heartRate(25_000) }
        val counts = ArrayDeque(listOf(8, 7, 6, 5, 4))
        val (reply, pageSizes) = getChanges { changes.take(counts.removeFirst()) }
        assertEquals(listOf(null, 4, 3, 3, 2), pageSizes)
        assertEquals(4 * 25_000, reply.points())
    }

    @Test
    fun aSingleChangeOverTheLimitIsDataTooLargeAtOnce() {
        val (reply, pageSizes) = getChanges { listOf(heartRate(MAX_CHANGE_POINTS.toInt() + 1)) }
        assertEquals(listOf<Int?>(null), pageSizes)
        assertEquals(HealthErrors.DATA_TOO_LARGE, reply.code)
        assertNull(reply.value)
    }

    @Test
    fun aPageSizeThatIsNotAppliedIsNotAskedForAgain() {
        // When Health Connect ignores the page size, it returns the same page.
        val changes = listOf(heartRate(10), heartRate(150_000))
        val (reply, pageSizes) = getChanges { changes }
        assertEquals(listOf(null, 1), pageSizes)
        assertEquals(HealthErrors.DATA_TOO_LARGE, reply.code)
        assertNull(reply.value)
    }
}
