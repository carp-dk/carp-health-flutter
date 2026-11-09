package cachet.plugins.health

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The Health Connect permission request flow: launches the system permission dialog and replies
 * to the pending request when the user closes it.
 *
 * @param contextProvider The plugin's application context, read when a request is made
 * @param dataOperationsProvider The plugin's data operations, read when a request is made
 */
internal class HealthPermissionRequests(
    private val contextProvider: () -> Context?,
    private val dataOperationsProvider: () -> HealthDataOperations,
) {
    var mResult: Result? = null
        private set
    private var healthConnectRequestPermissionsLauncher: ActivityResultLauncher<Set<String>>? = null
    private var isReplySubmitted = false

    private val context: Context?
        get() = contextProvider()
    private val dataOperations: HealthDataOperations
        get() = dataOperationsProvider()

    /** Registers the launcher of the permission dialog with [activity], a ComponentActivity. */
    fun registerLauncher(activity: Activity?) {
        val requestPermissionActivityContract =
                PermissionController.createRequestPermissionResultContract()

        healthConnectRequestPermissionsLauncher =
                (activity as ComponentActivity).registerForActivityResult(
                        requestPermissionActivityContract
                ) { granted -> onHealthConnectPermissionCallback(granted) }
    }

    /** Drops the launcher of the detached activity. */
    fun unregisterLauncher() {
        healthConnectRequestPermissionsLauncher = null
    }

    /**
     * Handles permission request results from Health Connect permission dialog. Called when user
     * responds to permission request, updates Flutter with result.
     *
     * @param permissionGranted Set of permission strings that were granted
     */
    private fun onHealthConnectPermissionCallback(permissionGranted: Set<String>) {
        if (!isReplySubmitted) {
            if (permissionGranted.isEmpty()) {
                mResult?.success(false)
                Log.i(
                        "FLUTTER_HEALTH",
                        "Health Connect permissions were not granted! Make sure to declare the required permissions in the AndroidManifest.xml file."
                )
            } else {
                mResult?.success(true)
                Log.i(
                        "FLUTTER_HEALTH",
                        "${permissionGranted.size} Health Connect permissions were granted!"
                )
                Log.i("FLUTTER_HEALTH", "Permissions granted: $permissionGranted")
            }
            isReplySubmitted = true
        }
    }

    /**
     * Initiates Health Connect permission request flow. Prepares permission list and launches
     * system permission dialog.
     *
     * @param call Method call containing permission types and access levels
     * @param result Flutter result callback for permission request outcome
     */
    fun requestAuthorization(call: MethodCall, result: Result) {
        if (context == null) {
            result.success(false)
            return
        }

        if (healthConnectRequestPermissionsLauncher == null) {
            result.success(false)
            Log.i("FLUTTER_HEALTH", "Permission launcher not found")
            return
        }

        // Store the result to be called in onHealthConnectPermissionCallback
        mResult = result
        isReplySubmitted = false

        val permList = dataOperations.preparePermissionsList(call)
        if (permList == null) {
            result.success(false)
            return
        }

        healthConnectRequestPermissionsLauncher!!.launch(permList.toSet())
    }

    /**
     * Requests specific permission for accessing health data history. Launches permission dialog
     * for historical data access capability.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback for permission request outcome
     */
    fun requestHealthDataHistoryAuthorization(call: MethodCall, result: Result) {
        if (context == null || healthConnectRequestPermissionsLauncher == null) {
            result.success(false)
            Log.i("FLUTTER_HEALTH", "Permission launcher not found")
            return
        }

        mResult = result
        isReplySubmitted = false
        healthConnectRequestPermissionsLauncher!!.launch(
                setOf(HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY)
        )
    }

    /**
     * Requests specific permission for background health data access. Launches permission dialog
     * for background data reading capability.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback for permission request outcome
     */
    fun requestHealthDataInBackgroundAuthorization(call: MethodCall, result: Result) {
        if (context == null || healthConnectRequestPermissionsLauncher == null) {
            result.success(false)
            Log.i("FLUTTER_HEALTH", "Permission launcher not found")
            return
        }

        mResult = result
        isReplySubmitted = false
        healthConnectRequestPermissionsLauncher!!.launch(
                setOf(HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND)
        )
    }
}
