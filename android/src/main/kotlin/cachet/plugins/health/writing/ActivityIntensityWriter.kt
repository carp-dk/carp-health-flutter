package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ActivityIntensityRecord
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/** Writes a period of moderate or vigorous activity, for writeActivityIntensity. */
internal class ActivityIntensityWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeActivityIntensity(call: MethodCall, result: Result) {
        val intensityType = call.argument<Int>("intensityType")!!
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val recordingMethod = call.argument<Int>("recordingMethod")!!
        val metadata = call.recordMetadata(recordingMethod)

        scope.launch {
            try {
                val record = ActivityIntensityRecord(
                    startTime = startTime,
                    startZoneOffset = null,
                    endTime = endTime,
                    endZoneOffset = null,
                    activityIntensityType = intensityType,
                    metadata = metadata,
                )
                healthConnectClient.insertRecords(listOf(record))
                result.success(true)
                Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Activity intensity was successfully added!")
            } catch (e: Exception) {
                Log.e(
                    "FLUTTER_HEALTH::ERROR",
                    "[Health Connect] There was an error adding the activity intensity record"
                )
                Log.e("FLUTTER_HEALTH::ERROR", e.message ?: "unknown error")
                Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                result.success(false)
            }
        }
    }
}
