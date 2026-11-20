package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SexualActivityRecord
import androidx.health.connect.client.records.metadata.Metadata
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Builds a [SexualActivityRecord] at [startTime] (epoch milliseconds) with Health Connect's
 * protection constant matching [protectionUsed] (`true` -> protected, `false` -> unprotected,
 * `null` -> unknown).
 */
internal fun sexualActivityRecord(
    protectionUsed: Boolean?,
    startTime: Long,
    metadata: Metadata,
): SexualActivityRecord {
    val protection = when (protectionUsed) {
        true -> SexualActivityRecord.PROTECTION_USED_PROTECTED
        false -> SexualActivityRecord.PROTECTION_USED_UNPROTECTED
        null -> SexualActivityRecord.PROTECTION_USED_UNKNOWN
    }
    return SexualActivityRecord(
        time = Instant.ofEpochMilli(startTime),
        zoneOffset = null,
        protectionUsed = protection,
        metadata = metadata,
    )
}

/** Writes a sexual activity record, for writeSexualActivity. */
internal class SexualActivityWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeSexualActivity(call: MethodCall, result: Result) {
        val protectionUsed = call.argument<Boolean>("protectionUsed")
        val startTime = call.argument<Long>("startTime")!!
        val recordingMethod = call.argument<Int>("recordingMethod")!!
        val metadata = call.recordMetadata(recordingMethod)

        scope.launch {
            try {
                val record = sexualActivityRecord(protectionUsed, startTime, metadata)
                healthConnectClient.insertRecords(listOf(record))
                result.success(true)
                Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Sexual activity was successfully added!")
            } catch (e: Exception) {
                Log.e(
                    "FLUTTER_HEALTH::ERROR",
                    "[Health Connect] There was an error adding the sexual activity record"
                )
                Log.e("FLUTTER_HEALTH::ERROR", e.message ?: "unknown error")
                Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                result.success(false)
            }
        }
    }
}
