package cachet.plugins.health.write

import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.requests.WorkoutWriteRequest
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant

/**
 * Writes workout sessions and workout summary records to Health Connect.
 */
class WorkoutWriter(
    private val executor: HealthConnectWriteExecutor,
    private val metadataFactory: HealthMetadataFactory,
) {
    /** Inserts a workout session with optional distance and energy records. */
    fun write(request: WorkoutWriteRequest, result: Result) {
        val workoutType = HealthConstants.workoutTypeMap[request.activityType]
        if (workoutType == null) {
            result.error("WRITE_WORKOUT_ERROR", "[Health Connect] Workout type not supported", null)
            return
        }

        val metadata = metadataFactory.create(
            recordingMethod = request.metadata.recordingMethod,
            deviceType = request.metadata.deviceType,
        )
        val startTime = Instant.ofEpochMilli(request.startTime)
        val endTime = Instant.ofEpochMilli(request.endTime)
        val records = mutableListOf<Record>(
            ExerciseSessionRecord(
                startTime = startTime,
                startZoneOffset = null,
                endTime = endTime,
                endZoneOffset = null,
                exerciseType = workoutType,
                title = request.title ?: request.activityType,
                metadata = metadata,
            )
        )

        request.totalDistance?.let {
            records.add(
                DistanceRecord(
                    startTime = startTime,
                    startZoneOffset = null,
                    endTime = endTime,
                    endZoneOffset = null,
                    distance = Length.meters(it.toDouble()),
                    metadata = metadata,
                )
            )
        }
        request.totalEnergyBurned?.let {
            records.add(
                TotalCaloriesBurnedRecord(
                    startTime = startTime,
                    startZoneOffset = null,
                    endTime = endTime,
                    endZoneOffset = null,
                    energy = Energy.kilocalories(it.toDouble()),
                    metadata = metadata,
                )
            )
        }

        executor.insert(
            records = records,
            result = result,
            failureCode = "WRITE_WORKOUT_ERROR",
            failureMessage = "[Health Connect] There was an error adding the workout",
        )
    }
}
