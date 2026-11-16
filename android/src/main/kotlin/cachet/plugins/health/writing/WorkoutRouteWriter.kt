package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import cachet.plugins.health.HealthErrors
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Builds workout routes: collects the locations of a route under a builder id, then attaches them
 * to an exercise session that is already written, for startWorkoutRoute, insertWorkoutRouteData,
 * finishWorkoutRoute and discardWorkoutRoute.
 */
internal class WorkoutRouteWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    // The locations collected for each route that is neither finished nor discarded, by builder id.
    private val workoutRouteBuilders = mutableMapOf<String, MutableList<ExerciseRoute.Location>>()

    fun startWorkoutRoute(result: Result) {
        val builderId = UUID.randomUUID().toString()
        workoutRouteBuilders[builderId] = mutableListOf()
        result.success(builderId)
    }

    fun insertWorkoutRouteData(call: MethodCall, result: Result) {
        val builderId = call.argument<String>("builderId")

        if (builderId == null) {
            result.error("ARGUMENT_ERROR", "Missing builderId for workout route insertion", null)
            return
        }

        val builder = workoutRouteBuilders[builderId]
        if (builder == null) {
            result.error("ROUTE_ERROR", "Invalid workout route builder: $builderId", null)
            return
        }

        try {
            builder.addAll(parseRouteLocations(call.argument<List<*>>("locations") ?: emptyList<Any>()))
            result.success(true)
        } catch (e: Exception) {
            // INVALID_ARGUMENT for a location that lacks a value or has one that is not a number.
            HealthErrors.report(result, e, "insertWorkoutRouteData")
        }
    }

    fun finishWorkoutRoute(call: MethodCall, result: Result) {
        val builderId = call.argument<String>("builderId")
        val workoutUUID = call.argument<String>("workoutUUID")

        if (builderId.isNullOrBlank() || workoutUUID.isNullOrBlank()) {
            result.error("ARGUMENT_ERROR", "Missing builderId or workoutUUID", null)
            return
        }

        val locations = workoutRouteBuilders[builderId]
        if (locations == null) {
            result.error("ROUTE_ERROR", "Invalid workout route builder: $builderId", null)
            return
        }

        scope.launch {
            try {
                // Throws if there is no such workout.
                val session = healthConnectClient.readRecord(ExerciseSessionRecord::class, workoutUUID).record

                if (locations.isEmpty()) {
                    workoutRouteBuilders.remove(builderId)
                    result.success(mapOf("uuid" to workoutUUID))
                    return@launch
                }

                val route = ExerciseRoute(locations.sortedBy { it.time })
                healthConnectClient.updateRecords(listOf(session.withRoute(route)))
                workoutRouteBuilders.remove(builderId)
                result.success(mapOf("uuid" to workoutUUID))
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", "Error finishing workout route: ${e.message}")
                result.error("ROUTE_ERROR", e.message, null)
            }
        }
    }

    fun discardWorkoutRoute(call: MethodCall, result: Result) {
        val builderId = call.argument<String>("builderId")
        if (builderId.isNullOrBlank()) {
            result.error("ARGUMENT_ERROR", "Missing builderId for discard", null)
            return
        }
        workoutRouteBuilders.remove(builderId)
        result.success(true)
    }
}

/**
 * This session with [route] as its route. Health Connect updates a record by replacing it, so the
 * copy keeps every other field of the session.
 */
internal fun ExerciseSessionRecord.withRoute(route: ExerciseRoute) = ExerciseSessionRecord(
    startTime = startTime,
    startZoneOffset = startZoneOffset,
    endTime = endTime,
    endZoneOffset = endZoneOffset,
    metadata = metadata,
    exerciseType = exerciseType,
    title = title,
    notes = notes,
    segments = segments,
    laps = laps,
    exerciseRoute = route,
    plannedExerciseSessionId = plannedExerciseSessionId,
    rateOfPerceivedExertion = rateOfPerceivedExertion,
)
