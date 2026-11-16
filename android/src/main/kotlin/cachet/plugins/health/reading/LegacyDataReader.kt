package cachet.plugins.health.reading

import android.os.Build
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.metadata.DataOrigin
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

/**
 * Reads a whole range into one reply, for the deprecated getData. Without read permission but with
 * write permission, only the records this app ([packageName]) wrote are read, as getDataPage reads
 * them ([ReadAccess.OWN]); with neither, the reply is empty. Exercise sessions that Android 14 or 15
 * ([sdkInt]) fails to read for a route outside the page are read again ([readRecordsPage]).
 */
internal class LegacyDataReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val converter: RecordConverter,
    private val routes: WorkoutRoutes,
    private val lookback: SeriesLookback,
    private val sleepLookback: SleepLookback,
    private val packageName: String,
    private val sdkInt: Int = Build.VERSION.SDK_INT,
) {
    fun getData(call: MethodCall, result: Result) {
        val dataType = call.argument<String>("dataTypeKey")!!
        val dataUnit: String? = call.argument<String>("dataUnitKey")
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val healthConnectData = mutableListOf<Map<String, Any?>>()
        val recordingMethodsToFilter = call.argument<List<Int>>("recordingMethodsToFilter")!!
        // With a 'limit', only the records that start last, as getDataPage reads them.
        val limit = call.recordLimit()

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
                        grantedPermissions,
                        limit
                    )
                    result.success(healthConnectData)
                    return@launch
                }

                val classType = HealthConstants.mapToType[dataType]
                val access = classType?.let { ReadAccess.of(grantedPermissions, it) } ?: ReadAccess.NONE
                if (classType != null && access != ReadAccess.NONE) {
                    val origins = ReadAccess.origins(access == ReadAccess.OWN, packageName)
                    val records = readRecords(classType, startTime, endTime, limit, origins)
                    val recordIds = records.mapTo(HashSet()) { it.metadata.id }
                    // The records that began before the range and reach into it, as getDataPage reads them.
                    val earlier =
                        when {
                            limit != null -> emptyList()
                            classType in HealthDataConverter.seriesTypes -> lookback.readLookbackRecords(
                                classType, startTime, LEGACY_PROBE_RECORDS, recordIds, origins
                            )
                            isSleepStageType(dataType) ->
                                sleepLookback.readLookbackSessions(startTime, recordIds, origins)
                            else -> emptyList()
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
                // A missing permission means no data, as for the permission check above. That includes
                // the Health Connect APK (Android 13 and lower) refusing a read of the app's own records.
                Log.w("FLUTTER_HEALTH", "No permission to read $dataType: ${e.message}")
                result.success(emptyList<Map<String, Any?>>())
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getData($dataType)")
            }
        }
    }

    /**
     * The records of [origins] (every app if empty) in the range, or with a [limit] the [limit] that
     * start last ([readNewestRecords]).
     */
    private suspend fun readRecords(
        classType: KClass<out Record>,
        startTime: Instant,
        endTime: Instant,
        limit: Int?,
        origins: Set<DataOrigin>,
    ): List<Record> {
        if (limit != null) {
            return healthConnectClient.readNewestRecords(classType, startTime, endTime, limit, origins, sdkInt)
        }
        val records = mutableListOf<Record>()
        var pageToken: String? = null
        do {
            val response = healthConnectClient.readRecordsPage(
                ReadRecordsRequest(
                    recordType = classType,
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                    dataOriginFilter = origins,
                    pageSize = HC_MAX_RECORDS,
                    pageToken = pageToken,
                ),
                sdkInt,
            )
            records.addAll(response.records)
            pageToken = response.pageToken
        } while (pageToken != null)
        return records
    }

    private suspend fun handleWorkoutRouteData(
        startTime: Instant,
        endTime: Instant,
        recordingMethodsToFilter: List<Int>,
        healthConnectData: MutableList<Map<String, Any?>>,
        grantedPermissions: Set<String>,
        limit: Int?,
    ) {
        val access = ReadAccess.of(grantedPermissions, ExerciseSessionRecord::class)
        if (access == ReadAccess.NONE) {
            Log.w(
                "FLUTTER_HEALTH",
                "Workout route access requires ExerciseSession read or write permission"
            )
            return
        }

        val origins = ReadAccess.origins(access == ReadAccess.OWN, packageName)
        val sessions = readRecords(ExerciseSessionRecord::class, startTime, endTime, limit, origins)
            .filterIsInstance<ExerciseSessionRecord>()
        routes.appendWorkoutRoutes(sessions, recordingMethodsToFilter, healthConnectData)
    }
}

// The legacy read holds the whole range anyway; it checks the newest 100 records that began earlier.
private const val LEGACY_PROBE_RECORDS = 100
