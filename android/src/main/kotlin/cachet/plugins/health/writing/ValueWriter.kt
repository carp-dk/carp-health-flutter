package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.response.InsertRecordsResponse
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Writes one value of a data type ([valueRecord]), for writeData and writeDataUUID; writeBloodOxygen
 * and writeMenstruationFlow are writeData calls too.
 */
internal class ValueWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeData(call: MethodCall, result: Result) {
        write(call, result, failureReply = false) { result.success(true) }
    }

    fun writeDataUUID(call: MethodCall, result: Result) {
        write(call, result, failureReply = "") { response ->
            val insertedUUID = firstInsertedId(response)
            if (insertedUUID.isNotEmpty()) {
                Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Workout $insertedUUID was successfully added!")
            }
            result.success(insertedUUID)
        }
    }

    /**
     * Inserts the record of the value in [call] and hands the response to [onInserted]. Replies
     * [failureReply] instead if writeData does not write the data type or the insert fails.
     */
    private fun write(
        call: MethodCall,
        result: Result,
        failureReply: Any,
        onInserted: (InsertRecordsResponse) -> Unit,
    ) {
        val type = call.argument<String>("dataTypeKey")!!
        val startTime = call.argument<Long>("startTime")!!
        val endTime = call.argument<Long>("endTime")!!
        val value = call.argument<Double>("value")!!
        val clientRecordId: String? = call.argument("clientRecordId")
        val clientRecordVersion: Double? = call.argument<Double>("clientRecordVersion")
        val recordingMethod = call.argument<Int>("recordingMethod")!!
        val deviceType: Int? = call.argument<Int>("deviceType")

        Log.i(
            "FLUTTER_HEALTH",
            "Writing data for $type between $startTime and $endTime, value: $value, recording method: $recordingMethod"
        )

        val metadata = buildMetadata(recordingMethod, clientRecordId, clientRecordVersion?.toLong(), deviceType)
        val record = valueRecord(type, startTime, endTime, value, metadata)
        if (record == null) {
            result.success(failureReply)
            return
        }

        scope.launch {
            try {
                onInserted(healthConnectClient.insertRecords(listOf(record)))
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error writing $type: ${e.message}")
                result.success(failureReply)
            }
        }
    }
}
