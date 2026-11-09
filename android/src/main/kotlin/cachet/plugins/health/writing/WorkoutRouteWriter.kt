package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.units.Length
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant
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
        val locations = call.argument<List<Map<String, Any?>>>("locations") ?: emptyList()

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
            builder.addAll(parseWorkoutLocations(locations))
            result.success(true)
        } catch (e: IllegalArgumentException) {
            result.error("ARGUMENT_ERROR", e.message, null)
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
                val updatedRecord =
                    ExerciseSessionRecord(
                        startTime = session.startTime,
                        startZoneOffset = session.startZoneOffset,
                        endTime = session.endTime,
                        endZoneOffset = session.endZoneOffset,
                        metadata = session.metadata,
                        exerciseType = session.exerciseType,
                        title = session.title,
                        notes = session.notes,
                        segments = session.segments,
                        laps = session.laps,
                        exerciseRoute = route,
                        plannedExerciseSessionId = session.plannedExerciseSessionId
                    )

                healthConnectClient.updateRecords(listOf(updatedRecord))
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

    /**
     * The locations in [rawLocations], maps with 'latitude', 'longitude', 'timestamp' (epoch
     * milliseconds) and optionally 'altitude', 'horizontalAccuracy' and 'verticalAccuracy' (meters).
     * Throws IllegalArgumentException if a location lacks a required value.
     */
    private fun parseWorkoutLocations(rawLocations: List<Map<String, Any?>>): List<ExerciseRoute.Location> {
        return rawLocations.map { entry ->
            val latitude = entry["latitude"].toDoubleOrNull()
                ?: throw IllegalArgumentException("Missing latitude in route location")
            val longitude = entry["longitude"].toDoubleOrNull()
                ?: throw IllegalArgumentException("Missing longitude in route location")
            val timestamp = entry["timestamp"]?.toLongOrNull()
                ?: throw IllegalArgumentException("Missing timestamp in route location")

            val altitude = entry["altitude"].toDoubleOrNull()
            val horizontalAccuracy = entry["horizontalAccuracy"].toDoubleOrNull()
            val verticalAccuracy = entry["verticalAccuracy"].toDoubleOrNull()

            ExerciseRoute.Location(
                time = Instant.ofEpochMilli(timestamp),
                latitude = latitude,
                longitude = longitude,
                horizontalAccuracy = horizontalAccuracy?.let { Length.meters(it) },
                verticalAccuracy = verticalAccuracy?.let { Length.meters(it) },
                altitude = altitude?.let { Length.meters(it) }
            )
        }
    }

    private fun Any?.toLongOrNull(): Long? =
        when (this) {
            is Number -> this.toLong()
            is String -> this.toLongOrNull()
            else -> null
        }

    private fun Any?.toDoubleOrNull(): Double? =
        when (this) {
            is Number -> this.toDouble()
            is String -> this.toDoubleOrNull()
            else -> null
        }
}
