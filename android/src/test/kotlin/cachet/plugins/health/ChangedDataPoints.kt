package cachet.plugins.health

import android.content.ContextWrapper
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.response.ChangesResponse
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals

/** The data points that getChanges replies for a page of changes that upserts [records]. */
internal fun changedDataPoints(records: List<Record>): List<Map<*, *>> {
    val client = fakeOf<HealthConnectClient> { method ->
        check(method == "getChanges") { "Unexpected call of $method" }
        ChangesResponse(records.map { UpsertionChange(it) }, "next", hasMore = false, changesTokenExpired = false)
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
    assertEquals("replies", 1, reply.replies)
    return ((reply.value as Map<*, *>)["changes"] as List<*>).map { (it as Map<*, *>)["dataPoint"] as Map<*, *> }
}
