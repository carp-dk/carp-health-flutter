package cachet.plugins.health

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseRouteResult.ConsentRequired
import androidx.health.connect.client.records.ExerciseRouteResult.Data
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Health Connect read operations exposed to Flutter.
 */
class HealthDataReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    @Suppress("unused") private val context: Context,
    private val dataConverter: HealthDataConverter,
) {
    private val recordingFilter = HealthRecordingFilter()
    private val routeReader = HealthWorkoutRouteReader(healthConnectClient, recordingFilter)
    private val specialReader =
        HealthSpecialRecordReader(healthConnectClient, dataConverter, recordingFilter)
    private val aggregateReader =
        HealthAggregateReader(healthConnectClient, scope, recordingFilter)

    /** Records for the requested Flutter data type and time range. */
    fun getData(call: MethodCall, result: Result) {
        val dataType = call.argument<String>("dataTypeKey")!!
        val dataUnit: String? = call.argument<String>("dataUnitKey")
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val filters = call.argument<List<Int>>("recordingMethodsToFilter")!!
        val healthConnectData = mutableListOf<Map<String, Any?>>()

        scope.launch {
            try {
                val grantedPermissions =
                    healthConnectClient.permissionController.getGrantedPermissions()
                if (dataType == HealthConstants.WORKOUT_ROUTE) {
                    routeReader.handleWorkoutRouteData(
                        startTime,
                        endTime,
                        filters,
                        healthConnectData,
                        grantedPermissions,
                    )
                    result.success(healthConnectData)
                    return@launch
                }
                val classType = authorizedTypeMap(grantedPermissions)[dataType]
                if (classType != null) {
                    val records = readRecords(classType, startTime, endTime)
                    when (dataType) {
                        HealthConstants.WORKOUT ->
                            specialReader.handleWorkoutData(records, filters, healthConnectData)
                        in sleepTypes ->
                            specialReader.handleSleepData(records, filters, dataType, healthConnectData)
                        else -> addConvertedRecords(records, filters, dataType, dataUnit, healthConnectData)
                    }
                }
                result.success(healthConnectData)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(emptyList<Map<String, Any?>>())
            }
        }
    }

    /** Single record or workout route for a Flutter data type and UUID. */
    fun getDataByUUID(call: MethodCall, result: Result) {
        val dataType = call.argument<String>("dataTypeKey")!!
        val uuid = call.argument<String>("uuid")!!
        if (dataType == HealthConstants.WORKOUT_ROUTE) {
            readWorkoutRouteByUuid(uuid, result)
            return
        }
        val classType = HealthConstants.mapToType[dataType]
        if (classType == null) {
            Log.w("FLUTTER_HEALTH::ERROR", "Datatype $dataType not found in HC")
            result.success(null)
            return
        }
        scope.launch {
            try {
                val record = healthConnectClient.readRecord(classType, uuid).record
                result.success(convertSingleRecord(record, dataType))
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error fetching record with UUID: $uuid")
                Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                result.success(null)
            }
        }
    }

    /** Aggregated records for the requested Flutter data type. */
    fun getAggregateData(call: MethodCall, result: Result) =
        aggregateReader.getAggregateData(call, result)

    /** Interval aggregate records for the requested Flutter data type. */
    fun getIntervalData(call: MethodCall, result: Result) =
        aggregateReader.getIntervalData(call, result)

    /** Total step count in the requested interval. */
    fun getTotalStepsInInterval(call: MethodCall, result: Result) =
        aggregateReader.getTotalStepsInInterval(call, result)

    private fun readWorkoutRouteByUuid(uuid: String, result: Result) {
        scope.launch {
            try {
                val session = healthConnectClient.readRecord(ExerciseSessionRecord::class, uuid).record
                val point = when (val routeResult = session.exerciseRouteResult) {
                    is Data -> routeReader.buildWorkoutRouteMap(session, routeResult.exerciseRoute)
                    is ConsentRequired -> routeReader.buildConsentRequiredRouteMap(session)
                    else -> emptyMap()
                } ?: emptyMap<String, Any?>()
                result.success(point)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error fetching workout route with UUID: $uuid")
                Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                result.success(null)
            }
        }
    }

    private suspend fun readRecords(
        classType: kotlin.reflect.KClass<out Record>,
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
                    pageToken = pageToken,
                )
            )
            records.addAll(response.records)
            pageToken = response.pageToken
        } while (!pageToken.isNullOrEmpty())
        return records
    }

    private fun authorizedTypeMap(grantedPermissions: Set<String>) =
        HealthConstants.mapToType.filter { (_, classType) ->
            grantedPermissions.contains(HealthPermission.getReadPermission(classType))
        }

    private fun addConvertedRecords(
        records: List<Record>,
        filters: List<Int>,
        dataType: String,
        dataUnit: String?,
        output: MutableList<Map<String, Any?>>,
    ) {
        val filteredRecords = recordingFilter.filterRecordsByRecordingMethods(filters, records)
        for (record in filteredRecords) {
            output.addAll(dataConverter.convertRecord(record, dataType, dataUnit))
        }
    }

    private suspend fun convertSingleRecord(record: Record, dataType: String): Map<String, Any?> =
        when (dataType) {
            HealthConstants.WORKOUT -> mutableListOf<Map<String, Any?>>()
                .also { specialReader.handleWorkoutData(listOf(record), emptyList(), it) }
                .firstOrNull() ?: emptyMap()
            in sleepTypes -> mutableListOf<Map<String, Any?>>()
                .also {
                    if (record is SleepSessionRecord) {
                        specialReader.handleSleepData(listOf(record), emptyList(), dataType, it)
                    }
                }
                .firstOrNull() ?: emptyMap()
            else -> dataConverter.convertRecord(record, dataType).firstOrNull() ?: emptyMap()
        }

    companion object {
        private val sleepTypes = setOf(
            HealthConstants.SLEEP_SESSION,
            HealthConstants.SLEEP_ASLEEP,
            HealthConstants.SLEEP_AWAKE,
            HealthConstants.SLEEP_AWAKE_IN_BED,
            HealthConstants.SLEEP_LIGHT,
            HealthConstants.SLEEP_DEEP,
            HealthConstants.SLEEP_REM,
            HealthConstants.SLEEP_OUT_OF_BED,
            HealthConstants.SLEEP_UNKNOWN,
        )
    }
}
