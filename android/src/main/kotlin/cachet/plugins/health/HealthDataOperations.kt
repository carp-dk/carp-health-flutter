package cachet.plugins.health

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.permission.HealthPermission.Companion.PERMISSION_READ_HEALTH_DATA_HISTORY
import androidx.health.connect.client.permission.HealthPermission.Companion.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Health Connect permission, feature, and deletion operations exposed to Flutter.
 */
class HealthDataOperations(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val healthConnectStatus: Int,
    @Suppress("unused") private val healthConnectAvailable: Boolean,
) {
    /** Cached Health Connect SDK status for the Flutter channel. */
    fun getHealthConnectSdkStatus(call: MethodCall, result: Result) {
        result.success(healthConnectStatus)
    }

    /** Whether all Health Connect permissions requested by Flutter are granted. */
    fun hasPermissions(call: MethodCall, result: Result) {
        val permList = preparePermissionsList(call)
        if (permList == null) {
            result.success(false)
            return
        }
        scope.launch {
            result.success(
                healthConnectClient.permissionController.getGrantedPermissions().containsAll(permList)
            )
        }
    }

    /** Health Connect permission strings requested by the Flutter method call. */
    fun preparePermissionsList(call: MethodCall): List<String>? {
        val args = call.arguments as HashMap<*, *>
        val types = (args["types"] as? ArrayList<*>)?.filterIsInstance<String>() ?: return null
        val permissions = (args["permissions"] as? ArrayList<*>)?.filterIsInstance<Int>() ?: return null
        return HealthPermissionMapper.prepare(types, permissions)
    }

    /** Revokes all Health Connect permissions granted to the app. */
    fun revokePermissions(call: MethodCall, result: Result) {
        scope.launch { healthConnectClient.permissionController.revokeAllPermissions() }
        result.success(true)
    }

    /** Whether extended Health Connect history access is available on this device. */
    fun isHealthDataHistoryAvailable(call: MethodCall, result: Result) =
        featureAvailable(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY, result)

    /** Whether extended Health Connect history access is currently granted. */
    fun isHealthDataHistoryAuthorized(call: MethodCall, result: Result) =
        permissionAuthorized(PERMISSION_READ_HEALTH_DATA_HISTORY, result)

    /** Unsupported direct history authorization request result. */
    fun requestHealthDataHistoryAuthorization(call: MethodCall, result: Result) {
        result.success(false)
    }

    /** Whether Health Connect background read access is available on this device. */
    fun isHealthDataInBackgroundAvailable(call: MethodCall, result: Result) =
        featureAvailable(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND, result)

    /** Whether Health Connect background read access is currently granted. */
    fun isHealthDataInBackgroundAuthorized(call: MethodCall, result: Result) =
        permissionAuthorized(PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND, result)

    /** Unsupported direct background authorization request result. */
    fun requestHealthDataInBackgroundAuthorization(call: MethodCall, result: Result) {
        result.success(false)
    }

    /** Whether skin temperature records are available through Health Connect. */
    fun isSkinTemperatureAvailable(call: MethodCall, result: Result) =
        featureAvailable(HealthConnectFeatures.FEATURE_SKIN_TEMPERATURE, result)

    /** Deletes records of a Flutter data type within the requested time range. */
    fun deleteData(call: MethodCall, result: Result) {
        val type = call.argument<String>("dataTypeKey")!!
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val classType = recordTypeOrNull(type, result) ?: return
        scope.launch {
            try {
                healthConnectClient.deleteRecords(
                    recordType = classType,
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                )
                result.success(true)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error deleting $type records: ${e.message}")
                result.success(false)
            }
        }
    }

    /** Deletes one Health Connect record by UUID. */
    fun deleteByUUID(call: MethodCall, result: Result) {
        val arguments = call.arguments as? HashMap<*, *>
        val dataTypeKey = (arguments?.get("dataTypeKey") as? String)!!
        val uuid = (arguments["uuid"] as? String)!!
        val classType = recordTypeOrNull(dataTypeKey, result) ?: return
        scope.launch {
            try {
                healthConnectClient.deleteRecords(
                    recordType = classType,
                    recordIdsList = listOf(uuid),
                    clientRecordIdsList = emptyList(),
                )
                result.success(true)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error deleting record with UUID: $uuid")
                result.success(false)
            }
        }
    }

    /** Deletes Health Connect records by record ID or client record ID. */
    fun deleteByClientRecordId(call: MethodCall, result: Result) {
        val arguments = call.arguments as? HashMap<*, *>
        val dataTypeKey = (arguments?.get("dataTypeKey") as? String)!!
        val recordId = listOfNotNull(arguments["recordId"] as? String)
        val clientRecordId = listOfNotNull(arguments["clientRecordId"] as? String)
        val classType = recordTypeOrNull(dataTypeKey, result) ?: return
        scope.launch {
            try {
                healthConnectClient.deleteRecords(classType, recordId, clientRecordId)
                result.success(true)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error deleting record with ClientRecordId: $clientRecordId")
                result.success(false)
            }
        }
    }

    private fun featureAvailable(feature: Int, result: Result) {
        scope.launch {
            result.success(
                healthConnectClient.features.getFeatureStatus(feature) ==
                    HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
            )
        }
    }

    private fun permissionAuthorized(permission: String, result: Result) {
        scope.launch {
            result.success(
                healthConnectClient.permissionController.getGrantedPermissions()
                    .containsAll(listOf(permission))
            )
        }
    }

    private fun recordTypeOrNull(type: String, result: Result) =
        HealthConstants.mapToType[type].also {
            if (it == null) {
                Log.w("FLUTTER_HEALTH::ERROR", "Datatype $type not found in HC")
                result.success(false)
            }
        }
}
