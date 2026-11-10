package cachet.plugins.health

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import androidx.annotation.NonNull
import androidx.health.connect.client.HealthConnectClient
import cachet.plugins.health.reading.HealthDataReader
import cachet.plugins.health.writing.HealthDataWriter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import kotlinx.coroutines.*

/**
 * Main Flutter plugin class for Health Connect integration. Manages plugin lifecycle, method
 * channel communication, permission handling, and coordinates between Flutter and Android Health
 * Connect APIs.
 */
class HealthPlugin(private var channel: MethodChannel? = null) :
        MethodCallHandler, ActivityResultListener, Result, ActivityAware, FlutterPlugin {

    private var handler: Handler? = null
    private var activity: Activity? = null
    private var context: Context? = null
    private lateinit var healthConnectClient: HealthConnectClient
    private lateinit var scope: CoroutineScope

    // Helper classes
    private lateinit var dataReader: HealthDataReader
    private lateinit var dataWriter: HealthDataWriter
    private lateinit var dataOperations: HealthDataOperations
    private lateinit var dataConverter: HealthDataConverter
    private lateinit var dataChanges: HealthDataChanges
    private val permissionRequests = HealthPermissionRequests({ context }, { dataOperations })

    // Health Connect availability
    private var healthConnectAvailable = false
    private var healthConnectStatus = HealthConnectClient.SDK_UNAVAILABLE

    companion object {
        const val CHANNEL_NAME = "flutter_health"
    }

    /**
     * Initializes the plugin when attached to the Flutter engine. Sets up method channel, checks
     * Health Connect availability, and initializes helper classes.
     *
     * @param flutterPluginBinding Plugin binding providing access to Flutter engine resources
     */
    override fun onAttachedToEngine(
            @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        handler = Handler(context!!.mainLooper)

        checkAvailability()
        if (healthConnectAvailable) {
            healthConnectClient =
                    HealthConnectClient.getOrCreate(flutterPluginBinding.applicationContext)
            initializeHelpers()
        }
    }

    /**
     * Cleans up resources when plugin is detached from Flutter engine. Cancels coroutines and
     * nullifies references to prevent memory leaks.
     *
     * @param binding Plugin binding (unused in cleanup)
     */
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = null
        activity = null
        scope.cancel()
    }

    override fun success(p0: Any?) {
        handler?.post { permissionRequests.mResult?.success(p0) }
    }

    override fun notImplemented() {
        handler?.post { permissionRequests.mResult?.notImplemented() }
    }

    override fun error(
            errorCode: String,
            errorMessage: String?,
            errorDetails: Any?,
    ) {
        handler?.post { permissionRequests.mResult?.error(errorCode, errorMessage, errorDetails) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return false
    }

    /**
     * Handles method calls from Flutter and routes them to appropriate handler classes. Central
     * dispatcher for all Health Connect operations including permissions, data reading, writing,
     * and deletion.
     *
     * @param call Method call from Flutter containing method name and arguments
     * @param result Result callback to return data or status to Flutter
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // SDK and Installation
            "installHealthConnect" -> installHealthConnect(call, result)
            "getHealthConnectSdkStatus" -> {
                checkAvailability()
                if (healthConnectAvailable && !(this::dataOperations.isInitialized)) {
                    healthConnectClient = HealthConnectClient.getOrCreate(context!!)
                    initializeHelpers()
                }
                result.success(healthConnectStatus)
            }

            // Permissions
            "hasPermissions" -> runCheck(call, result) { hasPermissions(call, result) }
            "requestAuthorization" -> permissionRequests.requestAuthorization(call, result)
            "revokePermissions" -> runCheck(call, result) { revokePermissions(call, result) }

            // History permissions
            "isHealthDataHistoryAvailable" ->
                    runCheck(call, result) { isHealthDataHistoryAvailable(call, result) }
            "isHealthDataHistoryAuthorized" ->
                    runCheck(call, result) { isHealthDataHistoryAuthorized(call, result) }
            "requestHealthDataHistoryAuthorization" ->
                    permissionRequests.requestHealthDataHistoryAuthorization(call, result)

            // Background permissions
            "isHealthDataInBackgroundAvailable" ->
                    runCheck(call, result) { isHealthDataInBackgroundAvailable(call, result) }
            "isHealthDataInBackgroundAuthorized" ->
                    runCheck(call, result) { isHealthDataInBackgroundAuthorized(call, result) }
            "requestHealthDataInBackgroundAuthorization" ->
                    permissionRequests.requestHealthDataInBackgroundAuthorization(call, result)
            "isSkinTemperatureAvailable" ->
                    runCheck(call, result) { isSkinTemperatureAvailable(call, result) }
            "isMindfulnessSessionAvailable" ->
                    runCheck(call, result) { isMindfulnessSessionAvailable(call, result) }

            // Reading data
            "getData" -> dataReader.getData(call, result)
            "getDataPage" -> dataReader.getDataPage(call, result)
            "getDataByUUID" -> dataReader.getDataByUUID(call, result)
            "getIntervalData" -> dataReader.getIntervalData(call, result)
            "getTotalStepsInInterval" -> dataReader.getTotalStepsInInterval(call, result)
            "getChangesToken" -> dataChanges.getChangesToken(call, result)
            "getChanges" -> dataChanges.getChanges(call, result)

            // Writing data
            "writeData" -> dataWriter.writeData(call, result)
            "writeDataUUID" -> dataWriter.writeDataUUID(call, result)
            "writeWorkoutData" -> dataWriter.writeWorkoutData(call, result)
            "writeWorkoutDataUUID" -> dataWriter.writeWorkoutDataUUID(call, result)
            "writeBloodPressure" -> dataWriter.writeBloodPressure(call, result)
            "writeBloodOxygen" -> dataWriter.writeBloodOxygen(call, result)
            "writeMenstruationFlow" -> dataWriter.writeMenstruationFlow(call, result)
            "writeMeal" -> dataWriter.writeMeal(call, result)
            "writeActivityIntensity" -> dataWriter.writeActivityIntensity(call, result)
            "writeSleepSession" -> dataWriter.writeSleepSession(call, result)
            "startWorkoutRoute" -> dataWriter.startWorkoutRoute(result)
            "insertWorkoutRouteData" -> dataWriter.insertWorkoutRouteData(call, result)
            "finishWorkoutRoute" -> dataWriter.finishWorkoutRoute(call, result)
            "discardWorkoutRoute" -> dataWriter.discardWorkoutRoute(call, result)

            // Deleting data
            "delete" -> dataOperations.deleteData(call, result)
            "deleteByUUID" -> dataOperations.deleteByUUID(call, result)
            "deleteByClientRecordId" -> dataOperations.deleteByClientRecordId(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Runs a permission or feature check of [dataOperations], which replies once Health Connect has
     * answered (or failed). What throws before that, such as malformed arguments or a Health Connect
     * that was unavailable when the plugin was attached (no [dataOperations]), is reported here.
     */
    private fun runCheck(call: MethodCall, result: Result, check: HealthDataOperations.() -> Unit) {
        try {
            dataOperations.check()
        } catch (e: Exception) {
            HealthErrors.report(result, e, call.method)
        }
    }

    /**
     * Called when activity is attached to the plugin. Sets up permission request launcher and
     * activity result handling.
     *
     * @param binding Activity plugin binding providing activity context
     */
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        if (channel == null) {
            return
        }
        binding.addActivityResultListener(this)
        activity = binding.activity

        permissionRequests.registerLauncher(activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    /**
     * Called when activity is detached from plugin. Cleans up activity-specific resources and
     * permission launchers.
     */
    override fun onDetachedFromActivity() {
        if (channel == null) {
            return
        }
        activity = null
        permissionRequests.unregisterLauncher()
    }

    /**
     * Checks Health Connect availability and SDK status on the current device. Determines if Health
     * Connect is installed and accessible.
     */
    private fun checkAvailability() {
        healthConnectStatus = HealthConnectClient.getSdkStatus(context!!)
        healthConnectAvailable = healthConnectStatus == HealthConnectClient.SDK_AVAILABLE
    }

    /**
     * Initializes helper classes for data operations after Health Connect client is ready. Creates
     * instances of reader, writer, operations, and converter classes.
     */
    private fun initializeHelpers() {
        dataConverter = HealthDataConverter()
        dataReader = HealthDataReader(healthConnectClient, scope, context!!, dataConverter)
        dataWriter = HealthDataWriter(healthConnectClient, scope)
        dataOperations = HealthDataOperations(healthConnectClient, scope)
        dataChanges = HealthDataChanges(healthConnectClient, scope, context!!, dataConverter)
    }

    /**
     * Launches Health Connect installation flow via Google Play Store. Directs users to install
     * Health Connect when it's not available.
     *
     * @param call Method call from Flutter (unused)
     * @param result Flutter result callback
     */
    private fun installHealthConnect(call: MethodCall, result: Result) {
        val uriString =
                "market://details?id=com.google.android.apps.healthdata&url=healthconnect%3A%2F%2Fonboarding"
        context!!.startActivity(
                Intent(Intent.ACTION_VIEW).apply {
                    setPackage("com.android.vending")
                    data = android.net.Uri.parse(uriString)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra("overlay", true)
                    putExtra("callerId", context!!.packageName)
                }
        )
        result.success(null)
    }
}
