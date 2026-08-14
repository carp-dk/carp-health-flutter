package cachet.plugins.health

import androidx.health.connect.client.HealthConnectClient
import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.ActivityIntensityWriter
import cachet.plugins.health.write.BloodPressureWriter
import cachet.plugins.health.write.GenericRecordWriter
import cachet.plugins.health.write.HealthConnectWriteExecutor
import cachet.plugins.health.write.NutritionWriter
import cachet.plugins.health.write.SpeedWriter
import cachet.plugins.health.write.WorkoutRouteSessionManager
import cachet.plugins.health.write.WorkoutRouteWriter
import cachet.plugins.health.write.WorkoutWriter
import cachet.plugins.health.write.requests.WriteRequestDecoder
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope

/**
 * Health Connect write operations exposed to Flutter.
 */
class HealthDataWriter(
    healthConnectClient: HealthConnectClient,
    scope: CoroutineScope,
) {
    private val decoder = WriteRequestDecoder()
    private val metadataFactory = HealthMetadataFactory()
    private val executor = HealthConnectWriteExecutor(healthConnectClient, scope)
    private val genericWriter = GenericRecordWriter(executor, metadataFactory)
    private val activityIntensityWriter = ActivityIntensityWriter(executor, metadataFactory)
    private val workoutWriter = WorkoutWriter(executor, metadataFactory)
    private val bloodPressureWriter = BloodPressureWriter(executor, metadataFactory)
    private val nutritionWriter = NutritionWriter(executor, metadataFactory)
    private val speedWriter = SpeedWriter(executor, metadataFactory)
    private val routeWriter = WorkoutRouteWriter(
        healthConnectClient = healthConnectClient,
        scope = scope,
        sessions = WorkoutRouteSessionManager(),
    )

    /** Writes a generic scalar Health Connect record. */
    fun writeData(call: MethodCall, result: Result) =
        decode(result) { genericWriter.write(decoder.generic(call), result) }

    /** Writes an activity intensity Health Connect record. */
    fun writeActivityIntensity(call: MethodCall, result: Result) =
        decode(result) { activityIntensityWriter.write(decoder.activityIntensity(call), result) }

    /** Writes a workout session and optional workout summary records. */
    fun writeWorkoutData(call: MethodCall, result: Result) =
        decode(result) { workoutWriter.write(decoder.workout(call), result) }

    /** Writes a blood pressure Health Connect record. */
    fun writeBloodPressure(call: MethodCall, result: Result) =
        decode(result) { bloodPressureWriter.write(decoder.bloodPressure(call), result) }

    /** Writes a blood oxygen record through the generic writer. */
    fun writeBloodOxygen(call: MethodCall, result: Result) = writeData(call, result)

    /** Writes a menstruation flow record through the generic writer. */
    fun writeMenstruationFlow(call: MethodCall, result: Result) = writeData(call, result)

    /** Writes a nutrition Health Connect record. */
    fun writeMeal(call: MethodCall, result: Result) =
        decode(result) { nutritionWriter.write(decoder.nutrition(call), result) }

    /** Writes a speed record with multiple samples. */
    fun writeMultipleSpeedData(call: MethodCall, result: Result) =
        decode(result) { speedWriter.write(decoder.speed(call), result) }

    /** Starts a pending workout route builder and returns its builder ID. */
    fun startWorkoutRoute(result: Result) = routeWriter.start(result)

    /** Appends route points to a pending workout route builder. */
    fun insertWorkoutRouteData(call: MethodCall, result: Result) =
        decode(result) { routeWriter.insert(decoder.routeInsert(call), result) }

    /** Attaches a pending route to an existing Health Connect workout. */
    fun finishWorkoutRoute(call: MethodCall, result: Result) =
        decode(result) { routeWriter.finish(decoder.routeFinish(call), result) }

    /** Discards a pending workout route builder. */
    fun discardWorkoutRoute(call: MethodCall, result: Result) =
        decode(result) { routeWriter.discard(decoder.routeDiscard(call), result) }

    private inline fun decode(result: Result, block: () -> Unit) {
        try {
            block()
        } catch (e: IllegalArgumentException) {
            result.error("ARGUMENT_ERROR", e.message, null)
        }
    }
}
