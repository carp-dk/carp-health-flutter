package cachet.plugins.health.write

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.units.Length
import cachet.plugins.health.write.requests.WorkoutRouteDiscardRequest
import cachet.plugins.health.write.requests.WorkoutRouteFinishRequest
import cachet.plugins.health.write.requests.WorkoutRouteInsertRequest
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Writes workout route data to existing Health Connect exercise sessions.
 */
class WorkoutRouteWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val sessions: WorkoutRouteSessionManager,
) {
    /** Starts a workout route builder and returns its builder ID. */
    fun start(result: Result) {
        result.success(sessions.start())
    }

    /** Adds route locations to a pending workout route builder. */
    fun insert(request: WorkoutRouteInsertRequest, result: Result) {
        if (request.builderId.isBlank()) {
            result.error("ARGUMENT_ERROR", "Missing builderId for workout route insertion", null)
            return
        }
        val locations = request.locations.map {
            ExerciseRoute.Location(
                time = Instant.ofEpochMilli(it.timestamp),
                latitude = it.latitude,
                longitude = it.longitude,
                horizontalAccuracy = it.horizontalAccuracy?.let(Length::meters),
                verticalAccuracy = it.verticalAccuracy?.let(Length::meters),
                altitude = it.altitude?.let(Length::meters),
            )
        }
        if (!sessions.append(request.builderId, locations)) {
            result.error("ROUTE_ERROR", "Invalid workout route builder: ${request.builderId}", null)
            return
        }
        result.success(true)
    }

    /** Persists a pending route onto an existing workout session. */
    fun finish(request: WorkoutRouteFinishRequest, result: Result) {
        if (request.builderId.isBlank() || request.workoutUUID.isBlank()) {
            result.error("ARGUMENT_ERROR", "Missing builderId or workoutUUID", null)
            return
        }
        val locations = sessions.locations(request.builderId)
        if (locations == null) {
            result.error("ROUTE_ERROR", "Invalid workout route builder: ${request.builderId}", null)
            return
        }

        scope.launch {
            try {
                val session = healthConnectClient
                    .readRecord(ExerciseSessionRecord::class, request.workoutUUID)
                    .record
                if (locations.isNotEmpty()) {
                    healthConnectClient.updateRecords(listOf(session.withRoute(locations)))
                }
                sessions.discard(request.builderId)
                result.success(mapOf("uuid" to request.workoutUUID))
            } catch (e: Exception) {
                result.error("ROUTE_ERROR", e.message, null)
            }
        }
    }

    /** Discards a pending workout route builder without updating Health Connect. */
    fun discard(request: WorkoutRouteDiscardRequest, result: Result) {
        if (request.builderId.isBlank()) {
            result.error("ARGUMENT_ERROR", "Missing builderId for discard", null)
            return
        }
        sessions.discard(request.builderId)
        result.success(true)
    }

    private fun ExerciseSessionRecord.withRoute(
        locations: List<ExerciseRoute.Location>
    ) = ExerciseSessionRecord(
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
        exerciseRoute = ExerciseRoute(locations.sortedBy { it.time }),
        plannedExerciseSessionId = plannedExerciseSessionId,
    )
}
