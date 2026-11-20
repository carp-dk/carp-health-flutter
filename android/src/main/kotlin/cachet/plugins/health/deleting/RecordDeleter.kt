package cachet.plugins.health.deleting

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthConstants
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Deletes the records of a data type, in a time range or by their ids, for delete, deleteByUUID and
 * deleteByClientRecordId. A data type that Health Connect does not have replies false.
 */
internal class RecordDeleter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun deleteData(call: MethodCall, result: Result) {
        val type = call.argument<String>("dataTypeKey")!!
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val classType = HealthConstants.mapToType[type] ?: return replyUnknownType(type, result)

        scope.launch {
            try {
                healthConnectClient.deleteRecords(
                    recordType = classType,
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                )
                result.success(true)
                Log.i(
                    "FLUTTER_HEALTH::SUCCESS",
                    "Successfully deleted $type records between $startTime and $endTime"
                )
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error deleting $type records: ${e.message}")
                result.success(false)
            }
        }
    }

    fun deleteByUUID(call: MethodCall, result: Result) {
        val arguments = call.arguments as? HashMap<*, *>
        val dataTypeKey = (arguments?.get("dataTypeKey") as? String)!!
        val uuid = (arguments["uuid"] as? String)!!
        val classType = HealthConstants.mapToType[dataTypeKey] ?: return replyUnknownType(dataTypeKey, result)

        scope.launch {
            try {
                healthConnectClient.deleteRecords(
                    recordType = classType,
                    recordIdsList = listOf(uuid),
                    clientRecordIdsList = emptyList()
                )
                result.success(true)
                Log.i(
                    "FLUTTER_HEALTH::SUCCESS",
                    "[Health Connect] Record with UUID $uuid was successfully deleted!"
                )
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error deleting record with UUID: $uuid")
                Log.e("FLUTTER_HEALTH::ERROR", e.message ?: "unknown error")
                Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                result.success(false)
            }
        }
    }

    fun deleteByClientRecordId(call: MethodCall, result: Result) {
        val arguments = call.arguments as? HashMap<*, *>
        val dataTypeKey = (arguments?.get("dataTypeKey") as? String)!!
        val recordId = listOfNotNull(arguments["recordId"] as? String)
        val clientRecordId = listOfNotNull(arguments["clientRecordId"] as? String)
        val classType = HealthConstants.mapToType[dataTypeKey] ?: return replyUnknownType(dataTypeKey, result)

        scope.launch {
            try {
                healthConnectClient.deleteRecords(classType, recordId, clientRecordId)
                result.success(true)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error deleting record with ClientRecordId: $clientRecordId")
                Log.e("FLUTTER_HEALTH::ERROR", e.message ?: "unknown error")
                Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                result.success(false)
            }
        }
    }

    /** Replies false for a data type that Health Connect does not have. */
    private fun replyUnknownType(type: String, result: Result) {
        Log.w("FLUTTER_HEALTH::ERROR", "Datatype $type not found in HC")
        result.success(false)
    }
}
