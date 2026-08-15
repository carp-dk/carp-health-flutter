package cachet.plugins.health

import android.content.Context
import android.os.Handler
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.records.ExerciseRouteResult.ConsentRequired
import androidx.health.connect.client.records.ExerciseRouteResult.Data
import androidx.health.connect.client.records.ExerciseRouteResult.NoData
import androidx.health.connect.client.request.AggregateGroupByDurationRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Handles reading and querying health data from Health Connect.
 * Manages data retrieval, filtering, aggregation, and format conversion for Flutter consumption.
 */
class HealthDataReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val context: Context,
    private val dataConverter: HealthDataConverter
) {
    private val recordingFilter = HealthRecordingFilter()

    /**
     * Retrieves all health data points of a specified type within a given time range.
     * Handles pagination for large datasets and applies recording method filtering.
     * Supports special processing for workout and sleep data.
     * 
     * @param call Method call containing 'dataTypeKey', 'startTime', 'endTime', 'recordingMethodsToFilter'
     * @param result Flutter result callback returning list of health data maps
     */
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

        scope.launch {
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
                    Handler(context.mainLooper).run { result.success(healthConnectData) }
                    return@launch
                }

                val authorizedTypeMap =
                    HealthConstants.mapToType.filter { (_, classType) ->
                        val requiredPermission = HealthPermission.getReadPermission(classType)
                        grantedPermissions.contains(requiredPermission)
                    }

                authorizedTypeMap[dataType]?.let { classType ->
                    val records = mutableListOf<Record>()

                    // Set up the initial request to read health records
                    var request = ReadRecordsRequest(
                        recordType = classType,
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                    )

                    var response = healthConnectClient.readRecords(request)
                    var pageToken = response.pageToken

                    // Add the records from the initial response
                    records.addAll(response.records)

                    // Continue making requests while there is a page token
                    while (!pageToken.isNullOrEmpty()) {
                        request = ReadRecordsRequest(
                            recordType = classType,
                            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                            pageToken = pageToken
                        )
                        response = healthConnectClient.readRecords(request)
                        pageToken = response.pageToken
                        records.addAll(response.records)
                    }

                    // Handle special cases
                    when (dataType) {
                        WORKOUT -> handleWorkoutData(records, recordingMethodsToFilter, healthConnectData)
                        SLEEP_SESSION, SLEEP_ASLEEP, SLEEP_AWAKE, SLEEP_AWAKE_IN_BED, 
                        SLEEP_LIGHT, SLEEP_DEEP, SLEEP_REM, SLEEP_OUT_OF_BED, SLEEP_UNKNOWN -> 
                            handleSleepData(records, recordingMethodsToFilter, dataType, healthConnectData)
                        else -> {
                            val filteredRecords = recordingFilter.filterRecordsByRecordingMethods(
                                recordingMethodsToFilter,
                                records
                            )
                            for (rec in filteredRecords) {
                                healthConnectData.addAll(
                                    dataConverter.convertRecord(rec, dataType, dataUnit)
                                )
                            }
                        }
                    }
                }
                Handler(context.mainLooper).run { result.success(healthConnectData) }
            } catch (e: Exception) {
                Log.i(
                    "FLUTTER_HEALTH::ERROR",
                    "Unable to return $dataType due to the following exception:"
                )
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(emptyList<Map<String, Any?>>()) // Return empty list instead of null
            }
        }
    }

    /**
     * Retrieves single health data point by given UUID and type.
     * 
     * @param call Method call containing 'UUID' and 'dataTypeKey'
     * @param result Flutter result callback returning list of health data maps
     */
    fun getDataByUUID(call: MethodCall, result: Result) {
        val dataType = call.argument<String>("dataTypeKey")!!
        val uuid = call.argument<String>("uuid")!!
        var healthPoint = mapOf<String, Any?>()

        if (dataType == HealthConstants.WORKOUT_ROUTE) {
            scope.launch {
                try {
                    val response =
                        healthConnectClient.readRecord(ExerciseSessionRecord::class, uuid)
                    val session = response.record

                    val point =
                        if (session == null) {
                            emptyMap()
                        } else {
                            when (val routeResult = session.exerciseRouteResult) {
                                is Data ->
                                    buildWorkoutRouteMap(session, routeResult.exerciseRoute)
                                        ?: emptyMap()
                                is ConsentRequired -> buildConsentRequiredRouteMap(session)
                                else -> emptyMap()
                            }
                        }

                    Handler(context.mainLooper).run { result.success(point) }
                } catch (e: Exception) {
                    Log.e(
                        "FLUTTER_HEALTH::ERROR",
                        "Error fetching workout route with UUID: $uuid"
                    )
                    Log.e("FLUTTER_HEALTH::ERROR", e.message ?: "unknown error")
                    Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                    result.success(null)
                }
            }
            return
        }

        if (!HealthConstants.mapToType.containsKey(dataType)) {
            Log.w("FLUTTER_HEALTH::ERROR", "Datatype $dataType not found in HC")
            result.success(null)
            return
        }

        val classType = HealthConstants.mapToType[dataType]!!

        scope.launch {
            try {

                Log.i("FLUTTER_HEALTH", "Getting $uuid with $classType")

                // Execute the request
                val response = healthConnectClient.readRecord(classType, uuid)

                // Find the record with the matching UUID
                val matchingRecord = response.record

                if (matchingRecord != null) {
                    // Handle special cases using shared logic
                    when (dataType) {
                        HealthConstants.WORKOUT -> {
                            val tempData = mutableListOf<Map<String, Any?>>()
                            handleWorkoutData(listOf(matchingRecord), emptyList(), tempData)
                            healthPoint = if (tempData.isNotEmpty()) tempData[0] else mapOf()
                        }
                        HealthConstants.SLEEP_SESSION,
                        HealthConstants.SLEEP_ASLEEP,
                        HealthConstants.SLEEP_AWAKE,
                        HealthConstants.SLEEP_AWAKE_IN_BED,
                        HealthConstants.SLEEP_LIGHT,
                        HealthConstants.SLEEP_DEEP,
                        HealthConstants.SLEEP_REM,
                        HealthConstants.SLEEP_OUT_OF_BED,
                        HealthConstants.SLEEP_UNKNOWN -> {
                            if (matchingRecord is SleepSessionRecord) {
                                val tempData = mutableListOf<Map<String, Any?>>()
                                handleSleepData(listOf(matchingRecord), emptyList(), dataType, tempData)
                                healthPoint = if (tempData.isNotEmpty()) tempData[0] else mapOf()
                            }
                        }
                        HealthConstants.WORKOUT_ROUTE -> {
                            if (matchingRecord is ExerciseSessionRecord) {
                                val routeMap = buildWorkoutRouteMap(
                                    matchingRecord,
                                    (matchingRecord.exerciseRouteResult as? Data)?.exerciseRoute
                                )
                                healthPoint = routeMap ?: mapOf()
                            }
                        }
                        else -> {
                            healthPoint = dataConverter.convertRecord(matchingRecord, dataType)[0]
                        }
                    }

                    Log.i(
                        "FLUTTER_HEALTH",
                        "Success: $healthPoint"
                    )

                    Handler(context.mainLooper).run { result.success(healthPoint) }
                } else {
                    Log.e("FLUTTER_HEALTH::ERROR", "Record not found for UUID: $uuid")
                    result.success(null)
                }
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error fetching record with UUID: $uuid")
                Log.e("FLUTTER_HEALTH::ERROR", e.message ?: "unknown error")
                Log.e("FLUTTER_HEALTH::ERROR", e.stackTraceToString())
                result.success(null)
            }
        }
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

        val sessions = mutableListOf<ExerciseSessionRecord>()
        var request = ReadRecordsRequest(
            recordType = ExerciseSessionRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
        )

        var response = healthConnectClient.readRecords(request)
        var pageToken = response.pageToken
        sessions.addAll(response.records)

        while (!pageToken.isNullOrEmpty()) {
            request = ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                pageToken = pageToken,
            )
            response = healthConnectClient.readRecords(request)
            pageToken = response.pageToken
            sessions.addAll(response.records)
        }

        val filteredSessions =
            if (recordingMethodsToFilter.isEmpty()) {
                sessions
            } else {
                recordingFilter.filterRecordsByRecordingMethods(
                    recordingMethodsToFilter,
                    sessions.map { it as Record }
                ).map { it as ExerciseSessionRecord }
            }

        for (session in filteredSessions) {
            when (val routeResult = session.exerciseRouteResult) {
                is Data -> {
                    val routeMap = buildWorkoutRouteMap(session, routeResult.exerciseRoute)
                    if (routeMap != null) {
                        healthConnectData.add(routeMap)
                    }
                }
                is ConsentRequired -> {
                    healthConnectData.add(
                        buildConsentRequiredRouteMap(session)
                    )
                }
                is NoData -> {
                    // no-op
                }
            }
        }
    }

    private fun buildWorkoutRouteMap(
        session: ExerciseSessionRecord,
        route: ExerciseRoute?
    ): Map<String, Any?>? {
        if (route == null || route.route.isEmpty()) return null

        val routePoints = route.route.map { location ->
            mutableMapOf<String, Any?>(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "timestamp" to location.time.toEpochMilli(),
            ).apply {
                location.altitude?.let { put("altitude", it.inMeters) }
                location.horizontalAccuracy?.let {
                    put("horizontalAccuracy", it.inMeters)
                }
                location.verticalAccuracy?.let {
                    put("verticalAccuracy", it.inMeters)
                }
            }
        }

        val startTimestamp = routePoints.firstOrNull()?.get("timestamp") as? Long
            ?: session.startTime.toEpochMilli()
        val endTimestamp = routePoints.lastOrNull()?.get("timestamp") as? Long
            ?: session.endTime.toEpochMilli()

        val metadata = mutableMapOf<String, Any?>(
            "workout_uuid" to session.metadata.id,
            "workout_activity_type" to (
                HealthConstants.workoutTypeReverseMap[session.exerciseType] ?: "OTHER"
            ),
            "workout_start_time" to session.startTime.toEpochMilli(),
            "workout_end_time" to session.endTime.toEpochMilli(),
            "route_point_count" to routePoints.size,
        )

        return mutableMapOf<String, Any?>(
            "uuid" to session.metadata.id,
            "route" to routePoints,
            "date_from" to startTimestamp,
            "date_to" to endTimestamp,
            "source_id" to session.metadata.dataOrigin.packageName,
            "source_name" to session.metadata.dataOrigin.packageName,
            "recording_method" to session.metadata.recordingMethod,
            "metadata" to metadata,
        )
    }

    private fun buildConsentRequiredRouteMap(session: ExerciseSessionRecord): Map<String, Any?> {
        val metadata = mapOf(
            "workout_uuid" to session.metadata.id,
            "route_requires_consent" to true,
            "workout_activity_type" to (
                HealthConstants.workoutTypeReverseMap[session.exerciseType] ?: "OTHER"
            ),
            "workout_start_time" to session.startTime.toEpochMilli(),
            "workout_end_time" to session.endTime.toEpochMilli(),
        )
        return mapOf(
            "uuid" to session.metadata.id,
            "route" to emptyList<Map<String, Any?>>(),
            "date_from" to session.startTime.toEpochMilli(),
            "date_to" to session.endTime.toEpochMilli(),
            "source_id" to session.metadata.dataOrigin.packageName,
            "source_name" to session.metadata.dataOrigin.packageName,
            "recording_method" to session.metadata.recordingMethod,
            "metadata" to metadata,
        )
    }

    /**
     * Retrieves aggregated health data grouped by time intervals.
     * Calculates totals, averages, or counts over specified time periods.
     * 
     * @param call Method call containing 'dataTypeKey', 'interval', 'startTime', 'endTime'
     * @param result Flutter result callback returning list of aggregated data maps
     */
    fun getAggregateData(call: MethodCall, result: Result) {
        val dataType = call.argument<String>("dataTypeKey")!!
        val interval = call.argument<Long>("interval")!!
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val healthConnectData = mutableListOf<Map<String, Any?>>()
        
        scope.launch {
            try {
                HealthConstants.mapToAggregateMetric[dataType]?.let { metricClassType ->
                    val request = AggregateGroupByDurationRequest(
                        metrics = setOf(metricClassType),
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                        timeRangeSlicer = Duration.ofSeconds(interval)
                    )
                    val response = healthConnectClient.aggregateGroupByDuration(request)

                    for (durationResult in response) {
                        var totalValue = durationResult.result[metricClassType]
                        if (totalValue is Length) {
                            totalValue = totalValue.inMeters
                        } else if (totalValue is Energy) {
                            totalValue = totalValue.inKilocalories
                        } else if (totalValue is TemperatureDelta) {
                            totalValue = totalValue.inCelsius
                        }

                        val packageNames = durationResult.result.dataOrigins
                            .joinToString { origin -> origin.packageName }

                        val data = mapOf<String, Any>(
                            "value" to (totalValue ?: 0),
                            "date_from" to durationResult.startTime.toEpochMilli(),
                            "date_to" to durationResult.endTime.toEpochMilli(),
                            "source_name" to packageNames,
                            "source_id" to "",
                            "is_manual_entry" to packageNames.contains("user_input")
                        )
                        healthConnectData.add(data)
                    }
                }
                Handler(context.mainLooper).run { result.success(healthConnectData) }
            } catch (e: Exception) {
                Log.i(
                    "FLUTTER_HEALTH::ERROR",
                    "Unable to return $dataType due to the following exception:"
                )
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(null)
            }
        }
    }

    /**
     * Retrieves interval-based health data. Currently delegates to getAggregateData.
     * Maintained for API compatibility and potential future differentiation.
     * 
     * @param call Method call with interval data parameters
     * @param result Flutter result callback returning interval data
     */
    fun getIntervalData(call: MethodCall, result: Result) {
        getAggregateData(call, result)
    }

    /**
     * Gets total step count within a specified time interval with optional filtering.
     * Optimizes between aggregated queries and filtered individual record queries
     * based on whether recording method filtering is required.
     * 
     * @param call Method call containing 'startTime', 'endTime', 'recordingMethodsToFilter'
     * @param result Flutter result callback returning total step count as integer
     */
    fun getTotalStepsInInterval(call: MethodCall, result: Result) {
        val start = call.argument<Long>("startTime")!!
        val end = call.argument<Long>("endTime")!!
        val recordingMethodsToFilter = call.argument<List<Int>>("recordingMethodsToFilter")!!

        if (recordingMethodsToFilter.isEmpty()) {
            getAggregatedStepCount(start, end, result)
        } else {
            getStepCountFiltered(start, end, recordingMethodsToFilter, result)
        }
    }

    // --------- Private Methods ---------

    /**
     * Retrieves aggregated step count using Health Connect's built-in aggregation.
     * Provides optimized step counting when no filtering is required.
     * 
     * @param start Start time in milliseconds
     * @param end End time in milliseconds
     * @param result Flutter result callback returning step count
     */
    private fun getAggregatedStepCount(start: Long, end: Long, result: Result) {
        val startInstant = Instant.ofEpochMilli(start)
        val endInstant = Instant.ofEpochMilli(end)
        
        scope.launch {
            try {
                val response = healthConnectClient.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(startInstant, endInstant),
                    ),
                )
                val stepsInInterval = response[StepsRecord.COUNT_TOTAL] ?: 0L

                Log.i("FLUTTER_HEALTH::SUCCESS", "returning $stepsInInterval steps")
                result.success(stepsInInterval)
            } catch (e: Exception) {
                Log.e(
                    "FLUTTER_HEALTH::ERROR",
                    "Unable to return steps due to the following exception:"
                )
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(null)
            }
        }
    }

    /**
     * Retrieves step count with recording method filtering applied.
     * Manually sums individual step records after applying specified filters.
     * 
     * @param start Start time in milliseconds
     * @param end End time in milliseconds
     * @param recordingMethodsToFilter List of recording methods to exclude
     * @param result Flutter result callback returning filtered step count
     */
    private fun getStepCountFiltered(
        start: Long, 
        end: Long, 
        recordingMethodsToFilter: List<Int>, 
        result: Result
    ) {
        scope.launch {
            try {
                val request = ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(start),
                        Instant.ofEpochMilli(end)
                    ),
                )
                val response = healthConnectClient.readRecords(request)
                val filteredRecords = recordingFilter.filterRecordsByRecordingMethods(
                    recordingMethodsToFilter,
                    response.records
                )
                val totalSteps = filteredRecords.sumOf { (it as StepsRecord).count.toInt() }
                
                Log.i(
                    "FLUTTER_HEALTH::SUCCESS",
                    "returning $totalSteps steps (excluding manual entries)"
                )
                result.success(totalSteps)
            } catch (e: Exception) {
                Log.e(
                    "FLUTTER_HEALTH::ERROR",
                    "Unable to return steps due to the following exception:"
                )
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(null)
            }
        }
    }

    /**
     * Handles special processing for workout/exercise session data.
     * Enriches workout records with associated distance, energy, and step data
     * by querying related records within the workout time period.
     * 
     * @param records List of ExerciseSessionRecord objects
     * @param recordingMethodsToFilter Recording methods to exclude (empty list means no filtering)
     * @param healthConnectData Mutable list to append processed workout data
     */
    private suspend fun handleWorkoutData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        healthConnectData: MutableList<Map<String, Any?>>
    ) {
        val filteredRecords = if (recordingMethodsToFilter.isEmpty()) {
            records
        } else {
            recordingFilter.filterRecordsByRecordingMethods(
                recordingMethodsToFilter,
                records
            )
        }

        for (rec in filteredRecords) {
            val record = rec as ExerciseSessionRecord
            
            // Get distance data
            val distanceRequest = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = DistanceRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        record.startTime,
                        record.endTime,
                    ),
                ),
            )

            val fitbitPackageName = "com.fitbit.FitbitMobile"

			// Deduplicate distance records based on startTime and endTime, keeping the one with highest distance
			val uniqueDistanceRecords = distanceRequest.records
				.groupBy { Pair(it.startTime.toEpochMilli(), it.endTime.toEpochMilli()) }
				.map { entry -> entry.value.maxByOrNull { it.distance.inMeters } ?: entry.value.first() }

			// Group distance records by packageName and sum for each package
			val distanceByPackage = distanceRequest.records
				.groupBy { it.metadata.dataOrigin.packageName }
				.mapValues { entry ->
					entry.value.sumOf { it.distance.inMeters }
				}

			// Check if Fitbit data exists, otherwise use the package with highest sum
			val totalDistance = if (distanceByPackage.containsKey(fitbitPackageName)) {
				distanceByPackage[fitbitPackageName] ?: 0.0
			} else {
				distanceByPackage.values.maxOrNull() ?: 0.0
			}
			
            // Get energy burned data
            val energyBurnedRequest = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = TotalCaloriesBurnedRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        record.startTime,
                        record.endTime,
                    ),
                ),
            )

            // Deduplicate energy burned records based on startTime and endTime, keeping the one with highest calories
			val uniqueEnergyBurnedRecords = energyBurnedRequest.records
				.groupBy { Pair(it.startTime.toEpochMilli(), it.endTime.toEpochMilli()) }
				.map { entry -> entry.value.maxByOrNull { it.energy.inKilocalories } ?: entry.value.first() }

			val totalEnergyBurned = energyBurnedRequest.records.sumOf { it.energy.inKilocalories }

            // Get steps data
            val stepRequest = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        record.startTime,
                        record.endTime
                    ),
                ),
            )
            
			// Deduplicate steps records based on startTime and endTime, keeping the one with highest step count
			val uniqueStepRecords = stepRequest.records
				.groupBy { Pair(it.startTime.toEpochMilli(), it.endTime.toEpochMilli()) }
				.map { entry -> entry.value.maxByOrNull { it.count } ?: entry.value.first() }

			// Group distance records by packageName and sum for each package
			val stepsByPackage = stepRequest.records
				.groupBy { it.metadata.dataOrigin.packageName }
				.mapValues { entry ->
					entry.value.sumOf { it.count }
				}

			// Check if Fitbit data exists, otherwise use the package with highest sum
			val totalSteps = if (stepsByPackage.containsKey(fitbitPackageName)) {
				stepsByPackage[fitbitPackageName] ?: 0
			} else {
				stepsByPackage.values.maxOrNull() ?: 0
			}.toDouble()

            // Add final datapoint
            healthConnectData.add(
                mapOf<String, Any?>(
                    "uuid" to record.metadata.id,
                    "workoutActivityType" to
                            (HealthConstants.workoutTypeMap
                                .filterValues { it == record.exerciseType }
                                .keys
                                .firstOrNull() ?: "OTHER"),
                    "totalDistance" to if (totalDistance == 0.0) null else totalDistance,
                    "totalDistanceUnit" to "METER",
                    "totalEnergyBurned" to if (totalEnergyBurned == 0.0) null else totalEnergyBurned,
                    "totalEnergyBurnedUnit" to "KILOCALORIE",
                    "totalSteps" to if (totalSteps == 0.0) null else totalSteps,
                    "totalStepsUnit" to "COUNT",
                    "unit" to "MINUTES",
                    "date_from" to record.startTime.toEpochMilli(),
                    "date_to" to record.endTime.toEpochMilli(),
                    "source_id" to "",
                    "source_name" to record.metadata.dataOrigin.packageName,
                ),
            )
        }
    }

    /**
     * Handles special processing for sleep session and stage data.
     * Processes sleep sessions and individual sleep stages based on requested data type.
     * Converts sleep stage enumerations to meaningful duration and type information.
     * 
     * @param records List of SleepSessionRecord objects
     * @param recordingMethodsToFilter Recording methods to exclude (empty list means no filtering)
     * @param dataType Specific sleep data type being requested
     * @param healthConnectData Mutable list to append processed sleep data
     */
    private fun handleSleepData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        dataType: String,
        healthConnectData: MutableList<Map<String, Any?>>
    ) {
        val filteredRecords = if (recordingMethodsToFilter.isEmpty()) {
            records
        } else {
            recordingFilter.filterRecordsByRecordingMethods(
                recordingMethodsToFilter,
                records
            )
        }

        for (rec in filteredRecords) {
            if (rec is SleepSessionRecord) {
                if (dataType == SLEEP_SESSION) {
                    healthConnectData.addAll(
                        dataConverter.convertRecord(rec, dataType)
                    )
                } else {
                    for (recStage in rec.stages) {
                        if (dataType == HealthConstants.mapSleepStageToType[recStage.stage]) {
                            healthConnectData.addAll(
                                dataConverter.convertRecordStage(
                                    recStage,
                                    dataType,
                                    rec.metadata
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    companion object {
        // Sleep-related constants
        private const val SLEEP_SESSION = "SLEEP_SESSION"
        private const val SLEEP_ASLEEP = "SLEEP_ASLEEP"
        private const val SLEEP_AWAKE = "SLEEP_AWAKE"
        private const val SLEEP_AWAKE_IN_BED = "SLEEP_AWAKE_IN_BED"
        private const val SLEEP_LIGHT = "SLEEP_LIGHT"
        private const val SLEEP_DEEP = "SLEEP_DEEP"
        private const val SLEEP_REM = "SLEEP_REM"
        private const val SLEEP_OUT_OF_BED = "SLEEP_OUT_OF_BED"
        private const val SLEEP_UNKNOWN = "SLEEP_UNKNOWN"
        private const val WORKOUT = "WORKOUT"
    }
}
