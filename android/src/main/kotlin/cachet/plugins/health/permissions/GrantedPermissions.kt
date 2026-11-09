package cachet.plugins.health.permissions

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission.Companion.PERMISSION_READ_HEALTH_DATA_HISTORY
import androidx.health.connect.client.permission.HealthPermission.Companion.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Checks and revokes the permissions granted to the app, for hasPermissions,
 * isHealthDataHistoryAuthorized, isHealthDataInBackgroundAuthorized and revokePermissions.
 */
internal class GrantedPermissions(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun hasPermissions(call: MethodCall, result: Result) {
        val permissions = permissionsFor(call)
        if (permissions == null) {
            result.success(false)
            return
        }
        replyGranted(permissions, result)
    }

    fun isHealthDataHistoryAuthorized(result: Result) {
        replyGranted(listOf(PERMISSION_READ_HEALTH_DATA_HISTORY), result)
    }

    fun isHealthDataInBackgroundAuthorized(result: Result) {
        replyGranted(listOf(PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND), result)
    }

    fun revokePermissions(result: Result) {
        scope.launch {
            Log.i("FLUTTER_HEALTH", "Revoking all Health Connect permissions")
            healthConnectClient.permissionController.revokeAllPermissions()
        }
        // The reply does not wait for the revocation.
        result.success(true)
    }

    /** Replies whether all of [permissions] are granted. */
    private fun replyGranted(permissions: List<String>, result: Result) {
        scope.launch {
            result.success(
                healthConnectClient.permissionController.getGrantedPermissions().containsAll(permissions),
            )
        }
    }
}
