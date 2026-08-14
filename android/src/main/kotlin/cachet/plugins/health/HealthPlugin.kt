package cachet.plugins.health

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.core.net.toUri
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * Flutter plugin entry point for Android Health Connect operations.
 */
class HealthPlugin(private var channel: MethodChannel? = null) :
    MethodCallHandler, ActivityResultListener, Result, ActivityAware, FlutterPlugin {
    private var mResult: Result? = null
    private var handler: Handler? = null
    private var activity: Activity? = null
    private var context: Context? = null
    private var permissionsLauncher: ActivityResultLauncher<Set<String>>? = null
    private lateinit var healthConnectClient: HealthConnectClient
    private lateinit var scope: CoroutineScope
    private var isReplySubmitted = false
    private lateinit var dataReader: HealthDataReader
    private lateinit var dataWriter: HealthDataWriter
    private lateinit var dataOperations: HealthDataOperations
    private lateinit var dataConverter: HealthDataConverter
    private lateinit var dataChanges: HealthDataChanges
    private var healthConnectAvailable = false
    private var healthConnectStatus = HealthConnectClient.SDK_UNAVAILABLE

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
        context = binding.applicationContext
        handler = Handler(context!!.mainLooper)
        checkAvailability()
        if (healthConnectAvailable) {
            healthConnectClient = HealthConnectClient.getOrCreate(binding.applicationContext)
            initializeHelpers()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = null
        activity = null
        scope.cancel()
    }

    override fun success(p0: Any?) {
        handler?.post { mResult?.success(p0) }
    }

    override fun notImplemented() {
        handler?.post { mResult?.notImplemented() }
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        handler?.post { mResult?.error(errorCode, errorMessage, errorDetails) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) = false

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "installHealthConnect" -> installHealthConnect(result)
            "getHealthConnectSdkStatus" -> getHealthConnectSdkStatus(result)
            "hasPermissions" -> dataOperations.hasPermissions(call, result)
            "requestAuthorization" -> requestAuthorization(call, result)
            "revokePermissions" -> dataOperations.revokePermissions(call, result)
            "isHealthDataHistoryAvailable" -> dataOperations.isHealthDataHistoryAvailable(call, result)
            "isHealthDataHistoryAuthorized" -> dataOperations.isHealthDataHistoryAuthorized(call, result)
            "requestHealthDataHistoryAuthorization" -> requestSpecialPermission(
                HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY,
                result,
            )
            "isHealthDataInBackgroundAvailable" ->
                dataOperations.isHealthDataInBackgroundAvailable(call, result)
            "isHealthDataInBackgroundAuthorized" ->
                dataOperations.isHealthDataInBackgroundAuthorized(call, result)
            "requestHealthDataInBackgroundAuthorization" -> requestSpecialPermission(
                HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND,
                result,
            )
            "isSkinTemperatureAvailable" -> dataOperations.isSkinTemperatureAvailable(call, result)
            "getData" -> dataReader.getData(call, result)
            "getDataByUUID" -> dataReader.getDataByUUID(call, result)
            "getIntervalData" -> dataReader.getIntervalData(call, result)
            "getAggregateData" -> dataReader.getAggregateData(call, result)
            "getTotalStepsInInterval" -> dataReader.getTotalStepsInInterval(call, result)
            "getChangesToken" -> dataChanges.getChangesToken(call, result)
            "getChanges" -> dataChanges.getChanges(call, result)
            "writeData" -> dataWriter.writeData(call, result)
            "writeWorkoutData" -> dataWriter.writeWorkoutData(call, result)
            "writeBloodPressure" -> dataWriter.writeBloodPressure(call, result)
            "writeBloodOxygen" -> dataWriter.writeBloodOxygen(call, result)
            "writeMenstruationFlow" -> dataWriter.writeMenstruationFlow(call, result)
            "writeMeal" -> dataWriter.writeMeal(call, result)
            "writeActivityIntensity" -> dataWriter.writeActivityIntensity(call, result)
            "startWorkoutRoute" -> dataWriter.startWorkoutRoute(result)
            "insertWorkoutRouteData" -> dataWriter.insertWorkoutRouteData(call, result)
            "finishWorkoutRoute" -> dataWriter.finishWorkoutRoute(call, result)
            "discardWorkoutRoute" -> dataWriter.discardWorkoutRoute(call, result)
            "delete" -> dataOperations.deleteData(call, result)
            "deleteByUUID" -> dataOperations.deleteByUUID(call, result)
            "deleteByClientRecordId" -> dataOperations.deleteByClientRecordId(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        if (channel == null) return
        binding.addActivityResultListener(this)
        activity = binding.activity
        val requestPermissionContract = PermissionController.createRequestPermissionResultContract()
        permissionsLauncher = (activity as ComponentActivity)
            .registerForActivityResult(requestPermissionContract) { onPermissionCallback(it) }
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        if (channel == null) return
        activity = null
        permissionsLauncher = null
    }

    private fun getHealthConnectSdkStatus(result: Result) {
        checkAvailability()
        if (healthConnectAvailable && !(this::dataOperations.isInitialized)) {
            healthConnectClient = HealthConnectClient.getOrCreate(context!!)
            initializeHelpers()
        }
        result.success(healthConnectStatus)
    }

    private fun checkAvailability() {
        healthConnectStatus = HealthConnectClient.getSdkStatus(context!!)
        healthConnectAvailable = healthConnectStatus == HealthConnectClient.SDK_AVAILABLE
    }

    private fun initializeHelpers() {
        dataConverter = HealthDataConverter()
        dataReader = HealthDataReader(healthConnectClient, scope, context!!, dataConverter)
        dataWriter = HealthDataWriter(healthConnectClient, scope)
        dataOperations = HealthDataOperations(
            healthConnectClient,
            scope,
            healthConnectStatus,
            healthConnectAvailable,
        )
        dataChanges = HealthDataChanges(healthConnectClient, scope, context!!, dataConverter)
    }

    private fun installHealthConnect(result: Result) {
        val uriString =
            "market://details?id=com.google.android.apps.healthdata&url=healthconnect%3A%2F%2Fonboarding"
        context!!.startActivity(
            Intent(Intent.ACTION_VIEW).apply {
                setPackage("com.android.vending")
                data = uriString.toUri()
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra("overlay", true)
                putExtra("callerId", context!!.packageName)
            }
        )
        result.success(null)
    }

    private fun onPermissionCallback(permissionGranted: Set<String>) {
        if (isReplySubmitted) return
        if (permissionGranted.isEmpty()) {
            mResult?.success(false)
            Log.i("FLUTTER_HEALTH", "Health Connect permissions were not granted.")
        } else {
            mResult?.success(true)
            Log.i("FLUTTER_HEALTH", "Permissions granted: $permissionGranted")
        }
        isReplySubmitted = true
    }

    private fun requestAuthorization(call: MethodCall, result: Result) {
        val launcher = permissionsLauncher
        if (context == null || launcher == null) {
            result.success(false)
            return
        }
        mResult = result
        isReplySubmitted = false
        val permList = dataOperations.preparePermissionsList(call)
        if (permList == null) {
            result.success(false)
            return
        }
        launcher.launch(permList.toSet())
    }

    private fun requestSpecialPermission(permission: String, result: Result) {
        val launcher = permissionsLauncher
        if (context == null || launcher == null) {
            result.success(false)
            return
        }
        mResult = result
        isReplySubmitted = false
        launcher.launch(setOf(permission))
    }

    companion object {
        const val CHANNEL_NAME = "flutter_health"
    }
}
