package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.units.Pressure
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/** Writes a systolic and a diastolic pressure (mmHg) as one blood pressure record, for writeBloodPressure. */
internal class BloodPressureWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeBloodPressure(call: MethodCall, result: Result) {
        val systolic = call.argument<Double>("systolic")!!
        val diastolic = call.argument<Double>("diastolic")!!
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val recordingMethod = call.argument<Int>("recordingMethod")!!
        val metadata = call.recordMetadata(recordingMethod)

        scope.launch {
            try {
                healthConnectClient.insertRecords(
                    listOf(
                        BloodPressureRecord(
                            time = startTime,
                            systolic = Pressure.millimetersOfMercury(systolic),
                            diastolic = Pressure.millimetersOfMercury(diastolic),
                            zoneOffset = null,
                            metadata = metadata,
                        ),
                    ),
                )
                result.success(true)
                Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Blood pressure was successfully added!")
            } catch (e: Exception) {
                logAddFailed("the blood pressure", e)
                result.success(false)
            }
        }
    }
}
