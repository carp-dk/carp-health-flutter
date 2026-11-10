package cachet.plugins.health

import android.content.ContextWrapper
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.response.ChangesResponse
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Test

/** Health Connect's mindfulness sessions are MINDFULNESS data points, valued in minutes as on iOS. */
class MindfulnessSessionsTest {
    private val start = Instant.parse("2026-11-08T10:00:00Z")
    private val end = start.plusSeconds(630)

    // A meditation of ten and a half minutes.
    private val session = MindfulnessSessionRecord(
        startTime = start,
        startZoneOffset = null,
        endTime = end,
        endZoneOffset = null,
        metadata = Metadata.manualEntry(),
        mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_MEDITATION,
    )

    @Test
    fun aSessionIsReadAsTheWholeMinutesItLasts() {
        val point = HealthDataConverter().convertRecord(session, HealthConstants.MINDFULNESS).single()
        assertEquals(10L, point["value"])
        assertEquals(start.toEpochMilli() to end.toEpochMilli(), point["date_from"] to point["date_to"])
        assertEquals(Metadata.RECORDING_METHOD_MANUAL_ENTRY, point["recording_method"])
    }

    @Test
    fun aChangedSessionIsAMindfulnessChange() {
        val client = fakeOf<HealthConnectClient> { method ->
            check(method == "getChanges") { "Unexpected call of $method" }
            ChangesResponse(listOf(UpsertionChange(session)), "next", hasMore = false, changesTokenExpired = false)
        }
        val job = Job()
        val changes = HealthDataChanges(
            client, CoroutineScope(Dispatchers.Unconfined + job), ContextWrapper(null), HealthDataConverter(),
        )
        val reply = RecordingResult()
        changes.getChanges(MethodCall("getChanges", hashMapOf("changesToken" to "token")), reply)
        // getChanges replies from a coroutine on another thread: wait until that has ended.
        job.complete()
        runBlocking { withTimeout(30_000) { job.join() } }

        val change = ((reply.value as Map<*, *>)["changes"] as List<*>).single() as Map<*, *>
        assertEquals(listOf("upsert", HealthConstants.MINDFULNESS), listOf(change["type"], change["dataTypeKey"]))
        assertEquals(10L, (change["dataPoint"] as Map<*, *>)["value"])
    }
}
