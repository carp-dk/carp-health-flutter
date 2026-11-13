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
    /** The request that waits for the open permission dialog, or null if none is open. */
    var mResult: Result? = null
        private set

    // Internal for tests, which use a fake launcher.
    internal var healthConnectRequestPermissionsLauncher: ActivityResultLauncher<Set<String>>? = null

    private val context: Context?
        get() = contextProvider()
    private val dataOperations: HealthDataOperations
        get() = dataOperationsProvider()

    /**
     * Registers the launcher of the permission dialog with [activity]. The launcher needs a
     * ComponentActivity, such as FlutterFragmentActivity, that has not started yet. Any other
     * activity, such as the default FlutterActivity, gets no launcher and an error naming the fix,
     * and so does one the plugin is attached to once it has started (for example when a
     * FlutterFragment with a cached engine is added to a running activity). Permission requests
     * then return false.
     */
    fun registerLauncher(activity: Activity?) {
        val componentActivity = activity as? ComponentActivity
        if (componentActivity == null) {
            healthConnectRequestPermissionsLauncher = null
            Log.e(
                    "FLUTTER_HEALTH",
                    "Host Activity is ${activity?.javaClass?.name}, which does not extend " +
                            "androidx.activity.ComponentActivity, so Health Connect permissions " +
                            "cannot be requested. Make MainActivity extend " +
                            "io.flutter.embedding.android.FlutterFragmentActivity instead of " +
                            "FlutterActivity (see 'Google Health Connect (Android)' in the README)."
            )
            return
        }

        val requestPermissionActivityContract =
                PermissionController.createRequestPermissionResultContract()

        // An activity that has started throws IllegalStateException, which would escape
        // onAttachedToActivity and crash the app.
        healthConnectRequestPermissionsLauncher =
                try {
                    componentActivity.registerForActivityResult(
                            requestPermissionActivityContract
                    ) { granted -> onHealthConnectPermissionCallback(granted) }
                } catch (e: IllegalStateException) {
                    Log.e(
                            "FLUTTER_HEALTH",
                            "Cannot register the Health Connect permission launcher with " +
                                    "${componentActivity.javaClass.name}, so Health Connect " +
                                    "permissions cannot be requested: ${e.message} Attach the " +
                                    "Flutter engine to the activity before it starts, for " +
                                    "example by adding the FlutterFragment in onCreate."
                    )
                    null
                }
    }

    /** Drops the launcher of the detached activity. */
    fun unregisterLauncher() {
        healthConnectRequestPermissionsLauncher = null
    }

    /**
     * Handles permission request results from Health Connect permission dialog. Called when user
     * responds to permission request, updates Flutter with result. The request is cleared before
     * the reply, so a second result finds none to answer, and a reply that throws leaves none
     * waiting.
     *
     * @param permissionGranted Set of permission strings that were granted
     */
    internal fun onHealthConnectPermissionCallback(permissionGranted: Set<String>) {
        val result = mResult ?: return
        mResult = null
        if (permissionGranted.isEmpty()) {
            result.success(false)
            Log.i(
                    "FLUTTER_HEALTH",
                    "Health Connect permissions were not granted! Make sure to declare the required permissions in the AndroidManifest.xml file."
            )
        } else {
            result.success(true)
            Log.i(
                    "FLUTTER_HEALTH",
                    "${permissionGranted.size} Health Connect permissions were granted!"
            )
            Log.i("FLUTTER_HEALTH", "Permissions granted: $permissionGranted")
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

        val launcher = healthConnectRequestPermissionsLauncher
        if (launcher == null) {
            result.success(false)
            Log.e("FLUTTER_HEALTH", "Permission launcher not found")
            return
        }

        // Prepared before the request is kept as pending: a type that Health Connect does not have
        // replies false here, and malformed arguments throw.
        val permList = dataOperations.preparePermissionsList(call)
        if (permList == null) {
            result.success(false)
            return
        }

        launch(launcher, permList.toSet(), call, result)
    }

    /**
     * Requests specific permission for accessing health data history. Launches permission dialog
     * for historical data access capability.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback for permission request outcome
     */
    fun requestHealthDataHistoryAuthorization(call: MethodCall, result: Result) {
        val launcher = healthConnectRequestPermissionsLauncher
        if (context == null || launcher == null) {
            result.success(false)
            Log.e("FLUTTER_HEALTH", "Permission launcher not found")
            return
        }

        launch(launcher, setOf(HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY), call, result)
    }

    /**
     * Requests specific permission for background health data access. Launches permission dialog
     * for background data reading capability.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback for permission request outcome
     */
    fun requestHealthDataInBackgroundAuthorization(call: MethodCall, result: Result) {
        val launcher = healthConnectRequestPermissionsLauncher
        if (context == null || launcher == null) {
            result.success(false)
            Log.e("FLUTTER_HEALTH", "Permission launcher not found")
            return
        }

        launch(launcher, setOf(HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND), call, result)
    }

    /**
     * Launches the permission dialog for [permissions] and keeps [result] for the user's answer.
     * The dialog answers one request at a time, so a request made while it is open replies false
     * instead of taking the place of the first one, which would never be answered. If the dialog
     * cannot be launched, [result] gets the error.
     */
    private fun launch(
            launcher: ActivityResultLauncher<Set<String>>,
            permissions: Set<String>,
            call: MethodCall,
            result: Result,
    ) {
        if (mResult != null) {
            Log.w("FLUTTER_HEALTH", "${call.method} returns false: the permission dialog is already open")
            result.success(false)
            return
        }

        mResult = result
        try {
            launcher.launch(permissions)
        } catch (e: Exception) {
            mResult = null
            HealthErrors.report(result, e, call.method)
        }
    }
}
