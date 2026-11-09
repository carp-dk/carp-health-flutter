package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.units.Velocity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Writes a series of speed samples as one speed record, for writeMultipleSpeedData. The method
 * channel does not dispatch to it yet (see HealthPlugin).
 */
internal class SpeedWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeMultipleSpeedData(call: MethodCall, result: Result) {
        val startTime = call.argument<Long>("startTime")!!
        val endTime = call.argument<Long>("endTime")!!
        val samples = call.argument<List<Map<String, Any>>>("samples")!!
        val recordingMethod = call.argument<Int>("recordingMethod")!!
        val deviceType: Int? = call.argument<Int>("deviceType")

        scope.launch {
            try {
                val speedSamples =
                    samples.map { sample ->
                        SpeedRecord.Sample(
                            time = Instant.ofEpochMilli(sample["time"] as Long),
                            speed = Velocity.metersPerSecond(sample["speed"] as Double)
                        )
                    }

                val speedRecord =
                    SpeedRecord(
                        startTime = Instant.ofEpochMilli(startTime),
                        endTime = Instant.ofEpochMilli(endTime),
                        samples = speedSamples,
                        startZoneOffset = null,
                        endZoneOffset = null,
                        metadata = buildMetadata(recordingMethod, deviceType = deviceType),
                    )

                healthConnectClient.insertRecords(listOf(speedRecord))
                result.success(true)
                Log.i("FLUTTER_HEALTH::SUCCESS", "Successfully wrote ${speedSamples.size} speed samples")
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error writing speed data: ${e.message}")
                result.success(false)
            }
        }
    }
}
