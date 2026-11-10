package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.workoutTypeName
import kotlin.reflect.KClass

internal const val WORKOUT = "WORKOUT"

/** Converts exercise sessions to workout data points, with totals read from Health Connect. */
internal class WorkoutConverter(
    private val healthConnectClient: HealthConnectClient,
    private val recordingFilter: HealthRecordingFilter,
) {
    /**
     * Handles special processing for workout/exercise session data.
     * Enriches workout records with associated distance, energy, and step data
     * by querying the related records that the workout's app wrote within the
     * workout time period. Pool and open water swims also get their laps
     * ([swimmingDetails]).
     *
     * @param records List of ExerciseSessionRecord objects
     * @param recordingMethodsToFilter Recording methods to exclude (empty list means no filtering)
     * @param healthConnectData Mutable list to append processed workout data
     * @param grantedPermissions Granted permissions; a total whose type may not be read stays null
     */
    suspend fun handleWorkoutData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        healthConnectData: MutableList<Map<String, Any?>>,
        grantedPermissions: Set<String>,
    ) {
        // Reading a type without permission throws, which used to drop every workout.
        val canRead = { type: KClass<out Record> ->
            grantedPermissions.contains(HealthPermission.getReadPermission(type))
        }
        val readDistance = canRead(DistanceRecord::class)
        val readEnergy = canRead(TotalCaloriesBurnedRecord::class)
        val readSteps = canRead(StepsRecord::class)

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
            // Only the records of the app that wrote the workout: other apps' records of the same activity,
            // such as the phone's own step and distance tracking, would count it twice.
            val workoutOrigin = setOf(record.metadata.dataOrigin)

            // Get distance data
            var totalDistance = 0.0
            if (readDistance) {
                val distanceRequest = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        recordType = DistanceRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            record.startTime,
                            record.endTime,
                        ),
                        dataOriginFilter = workoutOrigin,
                        pageSize = HC_MAX_RECORDS,
                    ),
                )
                for (distanceRec in distanceRequest.records) {
                    totalDistance += distanceRec.distance.inMeters
                }
            }

            // Get energy burned data
            var totalEnergyBurned = 0.0
            if (readEnergy) {
                val energyBurnedRequest = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        recordType = TotalCaloriesBurnedRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            record.startTime,
                            record.endTime,
                        ),
                        dataOriginFilter = workoutOrigin,
                        pageSize = HC_MAX_RECORDS,
                    ),
                )
                for (energyBurnedRec in energyBurnedRequest.records) {
                    totalEnergyBurned += energyBurnedRec.energy.inKilocalories
                }
            }

            // Get steps data
            var totalSteps = 0.0
            if (readSteps) {
                val stepRequest = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        recordType = StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            record.startTime,
                            record.endTime
                        ),
                        dataOriginFilter = workoutOrigin,
                        pageSize = HC_MAX_RECORDS,
                    ),
                )
                for (stepRec in stepRequest.records) {
                    totalSteps += stepRec.count
                }
            }

            // Add final datapoint
            healthConnectData.add(
                mapOf<String, Any?>(
                    "uuid" to record.metadata.id,
                    "workoutActivityType" to workoutTypeName(record.exerciseType),
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
                    "device_model" to record.metadata.device?.model,
                    "swimming" to swimmingDetails(record),
                ),
            )
        }
    }
}
