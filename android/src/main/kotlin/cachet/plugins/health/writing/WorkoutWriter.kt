package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.response.InsertRecordsResponse
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthConstants
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Writes a workout as an exercise session, with its distance and energy burned as records of their
 * own, for writeWorkoutData and writeWorkoutDataUUID. The 'metadata' argument (WorkoutMetadata) is
 * HealthKit workout metadata, which Health Connect has no equivalent for, so it is ignored here.
 */
internal class WorkoutWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeWorkoutData(call: MethodCall, result: Result) {
        write(call, result, failureReply = false) {
            result.success(true)
            Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Workout was successfully added!")
        }
    }

    fun writeWorkoutDataUUID(call: MethodCall, result: Result) {
        write(call, result, failureReply = "") { response ->
            // The exercise session is inserted first.
            val insertedUUID = firstInsertedId(response)
            Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Workout $insertedUUID was successfully added!")
            result.success(insertedUUID)
        }
    }

    /**
     * Inserts the records of the workout in [call] and hands the response to [onInserted]. Replies
     * [failureReply] instead if the activity type is not supported, the workout does not end after it
     * starts ([requireStartBeforeEnd]) or Health Connect rejects the records or the insert.
     */
    private fun write(
        call: MethodCall,
        result: Result,
        failureReply: Any,
        onInserted: (InsertRecordsResponse) -> Unit,
    ) {
        val type = call.argument<String>("activityType")!!
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val totalEnergyBurned = call.argument<Int>("totalEnergyBurned")
        val totalDistance = call.argument<Int>("totalDistance")
        val recordingMethod = call.argument<Int>("recordingMethod")!!
        val deviceType: Int? = call.argument<Int>("deviceType")
        val metadata = buildMetadata(recordingMethod = recordingMethod, deviceType = deviceType)

        val exerciseType = HealthConstants.workoutTypeMap[type]
        if (exerciseType == null) {
            result.success(failureReply)
            Log.w("FLUTTER_HEALTH::ERROR", "[Health Connect] Workout type not supported")
            return
        }
        val title = call.argument<String>("title") ?: type

        scope.launch {
            try {
                requireStartBeforeEnd(startTime, endTime)
                val records = workoutRecords(
                    exerciseType, title, startTime, endTime, totalDistance, totalEnergyBurned, metadata,
                )
                onInserted(healthConnectClient.insertRecords(records))
            } catch (e: Exception) {
                logAddFailed("the workout", e)
                result.success(failureReply)
            }
        }
    }

    /** The exercise session, then the distance (meters) and the energy burned (kcal) if given. */
    private fun workoutRecords(
        exerciseType: Int,
        title: String,
        startTime: Instant,
        endTime: Instant,
        totalDistance: Int?,
        totalEnergyBurned: Int?,
        metadata: Metadata,
    ): List<Record> {
        val records = mutableListOf<Record>(
            ExerciseSessionRecord(
                startTime = startTime,
                startZoneOffset = null,
                endTime = endTime,
                endZoneOffset = null,
                exerciseType = exerciseType,
                title = title,
                metadata = metadata,
            ),
        )
        if (totalDistance != null) {
            records.add(
                DistanceRecord(
                    startTime = startTime,
                    startZoneOffset = null,
                    endTime = endTime,
                    endZoneOffset = null,
                    distance = Length.meters(totalDistance.toDouble()),
                    metadata = metadata,
                ),
            )
        }
        if (totalEnergyBurned != null) {
            records.add(
                TotalCaloriesBurnedRecord(
                    startTime = startTime,
                    startZoneOffset = null,
                    endTime = endTime,
                    endZoneOffset = null,
                    energy = Energy.kilocalories(totalEnergyBurned.toDouble()),
                    metadata = metadata,
                ),
            )
        }
        return records
    }
}
