package cachet.plugins.health.reading

import android.os.Build
import android.os.RemoteException
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseRouteResult.ConsentRequired
import androidx.health.connect.client.records.ExerciseRouteResult.Data
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.requireString
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Reads one record by its UUID and converts it as a read of its data type would. */
internal class RecordByIdReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val dataConverter: HealthDataConverter,
    private val workouts: WorkoutConverter,
    private val sleep: SleepConverter,
    private val routes: WorkoutRoutes,
) {
    fun getDataByUUID(call: MethodCall, result: Result) {
        scope.launch(Dispatchers.Default) {
            try {
                val dataType = call.requireString("dataTypeKey")
                val uuid = call.requireString("uuid")
                val classType = recordTypeFor(dataType)

                Log.i("FLUTTER_HEALTH", "Getting $uuid with $classType")

                val record: Record? =
                    try {
                        healthConnectClient.readRecord(classType, uuid).record
                    } catch (e: RemoteException) {
                        if (!isRecordNotFound(e, Build.VERSION.SDK_INT)) throw e
                        null
                    }
                if (record == null) {
                    Log.i("FLUTTER_HEALTH", "Record not found for UUID: $uuid")
                    result.success(null)
                    return@launch
                }

                val healthPoint = convertRecordFoundByUUID(record, dataType)
                Log.i("FLUTTER_HEALTH", "Success: $healthPoint")
                result.success(healthPoint)
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getDataByUUID")
            }
        }
    }

    /** The data point of [record], or an empty map (null in Dart) when it has none for [dataType]. */
    private suspend fun convertRecordFoundByUUID(record: Record, dataType: String): Map<String, Any?> {
        val points = mutableListOf<Map<String, Any?>>()
        // Handle special cases using shared logic
        when (dataType) {
            HealthConstants.WORKOUT_ROUTE -> {
                val session = record as ExerciseSessionRecord
                when (val routeResult = session.exerciseRouteResult) {
                    is Data -> routes.buildWorkoutRouteMap(session, routeResult.exerciseRoute)?.let { points.add(it) }
                    is ConsentRequired -> points.add(routes.buildConsentRequiredRouteMap(session))
                    else -> {}
                }
            }
            WORKOUT -> workouts.handleWorkoutData(
                listOf(record),
                emptyList(),
                points,
                healthConnectClient.permissionController.getGrantedPermissions()
            )
            in sleepTypes -> sleep.handleSleepData(listOf(record), emptyList(), dataType, points)
            else -> points.addAll(dataConverter.convertRecord(record, dataType))
        }
        return points.firstOrNull() ?: emptyMap()
    }

    companion object {
        /**
         * Whether [error] from readRecord means that no record has the id. Android 14 and later
         * report that as RemoteException("No records"); the Health Connect APK as a RemoteException.
         */
        internal fun isRecordNotFound(error: Throwable, sdkInt: Int): Boolean =
            error is RemoteException &&
                (sdkInt < Build.VERSION_CODES.UPSIDE_DOWN_CAKE || error.message == "No records")
    }
}
