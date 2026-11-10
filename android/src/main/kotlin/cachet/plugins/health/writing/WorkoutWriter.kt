package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.response.InsertRecordsResponse
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthConstants
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneOffset

/**
 * Writes a workout as an exercise session, with its distance and energy burned as records of their
 * own, for writeWorkoutData and writeWorkoutDataUUID. The 'metadata' argument (WorkoutMetadata) is
 * HealthKit workout metadata, which Health Connect has no equivalent for, so it is ignored here, and so
 * is 'totalSwimmingStrokeCount': Health Connect has no record of swimming strokes. The laps of a swim
 * ('swimming') are laps of its session, with their stroke styles as segments ([swimmingLaps]).
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
     * Inserts the records of the workout in [call] ([workoutRecords]) and hands the response to
     * [onInserted]. Replies [failureReply] instead if the activity type is not supported, the records
     * cannot be built or Health Connect rejects the records or the insert.
     */
    private fun write(
        call: MethodCall,
        result: Result,
        failureReply: Any,
        onInserted: (InsertRecordsResponse) -> Unit,
    ) {
        val exerciseType = HealthConstants.workoutTypeMap[call.argument<String>("activityType")!!]
        if (exerciseType == null) {
            result.success(failureReply)
            Log.w("FLUTTER_HEALTH::ERROR", "[Health Connect] Workout type not supported")
            return
        }

        scope.launch {
            try {
                onInserted(healthConnectClient.insertRecords(workoutRecords(call, exerciseType)))
            } catch (e: Exception) {
                logAddFailed("the workout", e)
                result.success(failureReply)
            }
        }
    }
}

/**
 * The records of the workout in a writeWorkoutData or writeWorkoutDataUUID [call], an exercise session
 * of [exerciseType], then its distance (meters) and energy burned (kcal) if given. With a
 * 'clientRecordId' and its 'clientRecordVersion', the session has that client record id and the
 * distance and energy records `<id>:distance` and `<id>:calories`, all with that version, so that
 * Health Connect replaces them when the workout is written again with a greater version. The
 * 'startZoneOffsetSeconds' and 'endZoneOffsetSeconds' are the zone offsets of all of them. The session
 * of a pool or open water swim has the laps and stroke segments of its 'swimming' argument
 * ([swimmingLaps]). Throws IllegalArgumentException if the workout does not end after it starts
 * ([requireStartBeforeEnd]) or its swimming details are not valid ([swimmingLaps]).
 */
internal fun workoutRecords(call: MethodCall, exerciseType: Int): List<Record> {
    val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
    val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
    requireStartBeforeEnd(startTime, endTime)
    val startZoneOffset = call.argument<Int>("startZoneOffsetSeconds")?.let { ZoneOffset.ofTotalSeconds(it) }
    val endZoneOffset = call.argument<Int>("endZoneOffsetSeconds")?.let { ZoneOffset.ofTotalSeconds(it) }
    val recordingMethod = call.argument<Int>("recordingMethod")!!
    val clientRecordId = call.argument<String>("clientRecordId")
    val clientRecordVersion = call.argument<Double>("clientRecordVersion")?.toLong()
    val deviceType = call.argument<Int>("deviceType")
    // The session's client record id, followed by [suffix] for its other records.
    fun metadata(suffix: String = "") =
        buildMetadata(recordingMethod, clientRecordId?.let { it + suffix }, clientRecordVersion, deviceType)

    val swimming = swimmingLaps(call, exerciseType, startTime, endTime)

    val records = mutableListOf<Record>(
        ExerciseSessionRecord(
            startTime = startTime,
            startZoneOffset = startZoneOffset,
            endTime = endTime,
            endZoneOffset = endZoneOffset,
            exerciseType = exerciseType,
            title = call.argument<String>("title") ?: call.argument<String>("activityType"),
            segments = swimming.segments,
            laps = swimming.laps,
            metadata = metadata(),
        ),
    )
    call.argument<Int>("totalDistance")?.let { totalDistance ->
        records.add(
            DistanceRecord(
                startTime = startTime,
                startZoneOffset = startZoneOffset,
                endTime = endTime,
                endZoneOffset = endZoneOffset,
                distance = Length.meters(totalDistance.toDouble()),
                metadata = metadata(":distance"),
            ),
        )
    }
    call.argument<Int>("totalEnergyBurned")?.let { totalEnergyBurned ->
        records.add(
            TotalCaloriesBurnedRecord(
                startTime = startTime,
                startZoneOffset = startZoneOffset,
                endTime = endTime,
                endZoneOffset = endZoneOffset,
                energy = Energy.kilocalories(totalEnergyBurned.toDouble()),
                metadata = metadata(":calories"),
            ),
        )
    }
    return records
}
