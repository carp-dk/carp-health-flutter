package cachet.plugins.health.reading

import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult.ConsentRequired
import androidx.health.connect.client.records.ExerciseRouteResult.Data
import androidx.health.connect.client.records.ExerciseRouteResult.NoData
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.workoutTypeName

/** Converts the routes of exercise sessions to workout route data points. */
internal class WorkoutRoutes(private val recordingFilter: HealthRecordingFilter) {
    fun appendWorkoutRoutes(
        sessions: List<ExerciseSessionRecord>,
        recordingMethodsToFilter: List<Int>,
        healthConnectData: MutableList<Map<String, Any?>>,
    ) {
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

    fun buildWorkoutRouteMap(
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
            "workout_activity_type" to workoutTypeName(session.exerciseType),
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

    fun buildConsentRequiredRouteMap(session: ExerciseSessionRecord): Map<String, Any?> {
        val metadata = mapOf(
            "workout_uuid" to session.metadata.id,
            "route_requires_consent" to true,
            "workout_activity_type" to workoutTypeName(session.exerciseType),
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
}
