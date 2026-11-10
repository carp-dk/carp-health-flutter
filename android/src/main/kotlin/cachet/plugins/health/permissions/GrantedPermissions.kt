package cachet.plugins.health.permissions

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission.Companion.PERMISSION_READ_HEALTH_DATA_HISTORY
import androidx.health.connect.client.permission.HealthPermission.Companion.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope

/**
 * Checks and revokes the permissions granted to the app, for hasPermissions,
 * isHealthDataHistoryAuthorized, isHealthDataInBackgroundAuthorized and revokePermissions. A check
 * that fails replies the error ([launchCheck]).
 */
internal class GrantedPermissions(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    /** Throws for malformed 'types' or 'permissions' arguments ([permissionsFor]). */
    fun hasPermissions(call: MethodCall, result: Result) {
        val permissions = permissionsFor(call)
        if (permissions == null) {
            result.success(false)
            return
        }
        replyGranted(permissions, "hasPermissions", result)
    }

    fun isHealthDataHistoryAuthorized(result: Result) {
        replyGranted(listOf(PERMISSION_READ_HEALTH_DATA_HISTORY), "isHealthDataHistoryAuthorized", result)
    }

    fun isHealthDataInBackgroundAuthorized(result: Result) {
        replyGranted(listOf(PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND), "isHealthDataInBackgroundAuthorized", result)
    }

    /** Replies true once Health Connect has taken the revocation, which applies when the app restarts. */
    fun revokePermissions(result: Result) {
        scope.launchCheck(result, "revokePermissions") {
            Log.i("FLUTTER_HEALTH", "Revoking all Health Connect permissions")
            healthConnectClient.permissionController.revokeAllPermissions()
            true
        }
    }

    /** Replies whether all of [permissions] are granted. */
    private fun replyGranted(permissions: List<String>, operation: String, result: Result) {
        scope.launchCheck(result, operation) {
            healthConnectClient.permissionController.getGrantedPermissions().containsAll(permissions)
        }
    }
}
