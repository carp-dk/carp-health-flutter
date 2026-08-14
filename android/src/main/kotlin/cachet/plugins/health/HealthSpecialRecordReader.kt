package cachet.plugins.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter

/**
 * Readers for Health Connect record types that require composed Flutter payloads.
 */
class HealthSpecialRecordReader(
    private val healthConnectClient: HealthConnectClient,
    private val dataConverter: HealthDataConverter,
    private val recordingFilter: HealthRecordingFilter,
) {
    /** Workout maps enriched with distance, energy, and step totals. */
    suspend fun handleWorkoutData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        healthConnectData: MutableList<Map<String, Any?>>,
    ) {
        val filteredRecords = if (recordingMethodsToFilter.isEmpty()) {
            records
        } else {
            recordingFilter.filterRecordsByRecordingMethods(recordingMethodsToFilter, records)
        }
        for (rec in filteredRecords) {
            val record = rec as ExerciseSessionRecord
            val distance = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = DistanceRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(record.startTime, record.endTime),
                )
            ).records.sumOf { it.distance.inMeters }
            val energy = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = TotalCaloriesBurnedRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(record.startTime, record.endTime),
                )
            ).records.sumOf { it.energy.inKilocalories }
            val steps = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(record.startTime, record.endTime),
                )
            ).records.sumOf { it.count.toDouble() }
            healthConnectData.add(
                mapOf(
                    "uuid" to record.metadata.id,
                    "workoutActivityType" to (
                        HealthConstants.workoutTypeReverseMap[record.exerciseType] ?: "OTHER"
                    ),
                    "totalDistance" to distance.zeroAsNull(),
                    "totalDistanceUnit" to "METER",
                    "totalEnergyBurned" to energy.zeroAsNull(),
                    "totalEnergyBurnedUnit" to "KILOCALORIE",
                    "totalSteps" to steps.zeroAsNull(),
                    "totalStepsUnit" to "COUNT",
                    "unit" to "MINUTES",
                    "date_from" to record.startTime.toEpochMilli(),
                    "date_to" to record.endTime.toEpochMilli(),
                    "source_id" to "",
                    "source_name" to record.metadata.dataOrigin.packageName,
                )
            )
        }
    }

    /** Sleep session or sleep stage maps for the requested Flutter sleep data type. */
    fun handleSleepData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        dataType: String,
        healthConnectData: MutableList<Map<String, Any?>>,
    ) {
        val filteredRecords = if (recordingMethodsToFilter.isEmpty()) {
            records
        } else {
            recordingFilter.filterRecordsByRecordingMethods(recordingMethodsToFilter, records)
        }
        for (rec in filteredRecords.filterIsInstance<SleepSessionRecord>()) {
            if (dataType == HealthConstants.SLEEP_SESSION) {
                healthConnectData.addAll(dataConverter.convertRecord(rec, dataType))
                continue
            }
            for (stage in rec.stages) {
                if (dataType == HealthConstants.mapSleepStageToType[stage.stage]) {
                    healthConnectData.addAll(
                        dataConverter.convertRecordStage(stage, dataType, rec.metadata)
                    )
                }
            }
        }
    }

    private fun Double.zeroAsNull(): Double? = if (this == 0.0) null else this
}
