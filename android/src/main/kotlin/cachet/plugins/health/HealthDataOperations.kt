package cachet.plugins.health

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import cachet.plugins.health.deleting.RecordDeleter
import cachet.plugins.health.permissions.FeatureAvailability
import cachet.plugins.health.permissions.GrantedPermissions
import cachet.plugins.health.permissions.permissionsFor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope

/**
 * Handles Health Connect operational tasks: permission checks, feature availability and data
 * deletion. Manages the administrative aspects of Health Connect integration; the permission
 * dialog is [HealthPermissionRequests].
 *
 * Calls run on the plugin's scope, on the main thread.
 */
class HealthDataOperations(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    private val grantedPermissions = GrantedPermissions(healthConnectClient, scope)
    private val features = FeatureAvailability(healthConnectClient, scope)
    private val deleter = RecordDeleter(healthConnectClient, scope)

    /**
     * Checks if the application has been granted the requested health data permissions. Verifies
     * permission status without triggering permission request dialogs.
     *
     * @param call Method call containing 'types' (data types) and 'permissions' (access levels)
     * @param result Flutter result callback returning boolean permission status
     */
    fun hasPermissions(call: MethodCall, result: Result) {
        grantedPermissions.hasPermissions(call, result)
    }

    /**
     * Prepares a list of Health Connect permission strings for authorization requests. Converts
     * Flutter data types and permission levels (0 read, 1 write, 2 read and write) into Health
     * Connect permission format.
     *
     * @param call Method call containing 'types' and 'permissions' arrays
     * @return List<String>? List of permission strings, or null if invalid types provided
     */
    fun preparePermissionsList(call: MethodCall): List<String>? {
        Log.i("FLUTTER_HEALTH", "preparePermissionsList")
        Log.i("FLUTTER_HEALTH", "call: $call")
        return permissionsFor(call)
    }

    /**
     * Revokes all previously granted Health Connect permissions for this application. Completely
     * removes app access to Health Connect data.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback returning success status
     */
    fun revokePermissions(call: MethodCall, result: Result) {
        grantedPermissions.revokePermissions(result)
    }

    /**
     * Checks if the health data history feature is available on the current device. History feature
     * allows access to data from before the app was installed.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback returning boolean availability status
     */
    fun isHealthDataHistoryAvailable(call: MethodCall, result: Result) {
        features.isHealthDataHistoryAvailable(result)
    }

    /**
     * Checks if the health data history permission has been granted. Verifies if app can access
     * historical health data.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback returning boolean authorization status
     */
    fun isHealthDataHistoryAuthorized(call: MethodCall, result: Result) {
        grantedPermissions.isHealthDataHistoryAuthorized(result)
    }

    /**
     * Checks if background health data reading feature is available on device. Background feature
     * allows data access when app is not in foreground.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback returning boolean availability status
     */
    fun isHealthDataInBackgroundAvailable(call: MethodCall, result: Result) {
        features.isHealthDataInBackgroundAvailable(result)
    }

    /**
     * Checks if background health data reading permission has been granted. Verifies if app can
     * access health data in background mode.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback returning boolean authorization status
     */
    fun isHealthDataInBackgroundAuthorized(call: MethodCall, result: Result) {
        grantedPermissions.isHealthDataInBackgroundAuthorized(result)
    }

    /**
     * Checks if Skin Temperature data is available on the current device.
     * Availability is device-specific and exposed via Health Connect features.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback returning boolean availability status
     */
    fun isSkinTemperatureAvailable(call: MethodCall, result: Result) {
        features.isSkinTemperatureAvailable(result)
    }

    /**
     * Deletes all health records of a specified type within a given time range. Performs bulk
     * deletion based on data type and time window.
     *
     * @param call Method call containing 'dataTypeKey', 'startTime', and 'endTime'
     * @param result Flutter result callback returning boolean success status
     */
    fun deleteData(call: MethodCall, result: Result) {
        deleter.deleteData(call, result)
    }

    /**
     * Deletes a specific health record by its unique identifier and data type. Allows precise
     * deletion of individual health records.
     *
     * @param call Method call containing 'dataTypeKey' and 'uuid'
     * @param result Flutter result callback returning boolean success status
     */
    fun deleteByUUID(call: MethodCall, result: Result) {
        deleter.deleteByUUID(call, result)
    }

    /**
     * Deletes a specific health record by its client record ID and data type. Allows precise
     * deletion of individual health records using client-side IDs.
     *
     * @param call Method call containing 'dataTypeKey', 'recordId', and 'clientRecordId'
     * @param result Flutter result callback returning boolean success status
     */
    fun deleteByClientRecordId(call: MethodCall, result: Result) {
        deleter.deleteByClientRecordId(call, result)
    }
}
