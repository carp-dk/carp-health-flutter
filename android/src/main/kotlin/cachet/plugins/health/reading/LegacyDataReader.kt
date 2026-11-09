package cachet.plugins.health.reading

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthErrors
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import kotlin.reflect.KClass

/** Reads a whole range into one reply, for the deprecated getData. */
internal class LegacyDataReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val converter: RecordConverter,
    private val routes: WorkoutRoutes,
    private val lookback: SeriesLookback,
) {
    fun getData(call: MethodCall, result: Result) {
        val dataType = call.argument<String>("dataTypeKey")!!
        val dataUnit: String? = call.argument<String>("dataUnitKey")
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val healthConnectData = mutableListOf<Map<String, Any?>>()
        val recordingMethodsToFilter = call.argument<List<Int>>("recordingMethodsToFilter")!!

        Log.i(
            "FLUTTER_HEALTH",
            "Getting data for $dataType with unit $dataUnit between $startTime and $endTime, filtering by $recordingMethodsToFilter"
        )

        // Off the main thread: converting a large catch-up (e.g. 100k points) would stall the UI.
        scope.launch(Dispatchers.Default) {
            try {
                val grantedPermissions =
                    healthConnectClient.permissionController.getGrantedPermissions()

                if (dataType == HealthConstants.WORKOUT_ROUTE) {
                    handleWorkoutRouteData(
                        startTime,
                        endTime,
                        recordingMethodsToFilter,
                        healthConnectData,
                        grantedPermissions
                    )
                    result.success(healthConnectData)
                    return@launch
                }

                val classType = HealthConstants.mapToType[dataType]
                if (classType != null &&
                    grantedPermissions.contains(HealthPermission.getReadPermission(classType))
                ) {
                    val records = readAllRecords(classType, startTime, endTime)
                    val earlier =
                        if (classType in HealthDataConverter.seriesTypes) {
                            lookback.readLookbackRecords(
                                classType,
                                startTime,
                                LEGACY_PROBE_RECORDS,
                                records.mapTo(HashSet()) { it.metadata.id }
                            )
                        } else {
                            emptyList()
                        }
                    converter.convertRecords(
                        earlier + records,
                        dataType,
                        dataUnit,
                        startTime,
                        endTime,
                        recordingMethodsToFilter,
                        grantedPermissions,
                        healthConnectData
                    )
                }
                result.success(healthConnectData)
            } catch (e: SecurityException) {
                // A missing permission means no data, as for the permission check above.
                Log.w("FLUTTER_HEALTH", "No permission to read $dataType: ${e.message}")
                result.success(emptyList<Map<String, Any?>>())
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getData($dataType)")
            }
        }
    }

    private suspend fun readAllRecords(
        classType: KClass<out Record>,
        startTime: Instant,
        endTime: Instant,
    ): List<Record> {
        val records = mutableListOf<Record>()
        var pageToken: String? = null
        do {
            val response = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = classType,
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                    pageSize = HC_MAX_RECORDS,
                    pageToken = pageToken,
                )
            )
            records.addAll(response.records)
            pageToken = response.pageToken?.takeIf { it.isNotEmpty() }
        } while (pageToken != null)
        return records
    }

    private suspend fun handleWorkoutRouteData(
        startTime: Instant,
        endTime: Instant,
        recordingMethodsToFilter: List<Int>,
        healthConnectData: MutableList<Map<String, Any?>>,
        grantedPermissions: Set<String>,
    ) {
        val workoutPermission = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        if (!grantedPermissions.contains(workoutPermission)) {
            Log.w(
                "FLUTTER_HEALTH",
                "Workout route access requires ExerciseSession read permission"
            )
            return
        }

        val sessions = readAllRecords(ExerciseSessionRecord::class, startTime, endTime)
            .filterIsInstance<ExerciseSessionRecord>()
        routes.appendWorkoutRoutes(sessions, recordingMethodsToFilter, healthConnectData)
    }
}

// The legacy read holds the whole range anyway; it checks the newest 100 records that began earlier.
private const val LEGACY_PROBE_RECORDS = 100
