package cachet.plugins.health

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult.ConsentRequired
import androidx.health.connect.client.records.ExerciseRouteResult.Data
import androidx.health.connect.client.records.ExerciseRouteResult.NoData
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant

/**
 * Workout route read helpers for Health Connect exercise sessions.
 */
class HealthWorkoutRouteReader(
    private val healthConnectClient: HealthConnectClient,
    private val recordingFilter: HealthRecordingFilter,
) {
    /** Workout route maps for sessions in the requested time range. */
    suspend fun handleWorkoutRouteData(
        startTime: Instant,
        endTime: Instant,
        recordingMethodsToFilter: List<Int>,
        healthConnectData: MutableList<Map<String, Any?>>,
        grantedPermissions: Set<String>,
    ) {
        val workoutPermission = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        if (!grantedPermissions.contains(workoutPermission)) {
            Log.w("FLUTTER_HEALTH", "Workout route access requires ExerciseSession read permission")
            return
        }
        val sessions = mutableListOf<ExerciseSessionRecord>()
        var request = ReadRecordsRequest(
            recordType = ExerciseSessionRecord::class,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
        )
        var response = healthConnectClient.readRecords(request)
        var pageToken = response.pageToken
        sessions.addAll(response.records)
        while (!pageToken.isNullOrEmpty()) {
            request = ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                pageToken = pageToken,
            )
            response = healthConnectClient.readRecords(request)
            pageToken = response.pageToken
            sessions.addAll(response.records)
        }
        val filteredSessions = if (recordingMethodsToFilter.isEmpty()) {
            sessions
        } else {
            recordingFilter.filterRecordsByRecordingMethods(
                recordingMethodsToFilter,
                sessions.map { it as Record },
            ).map { it as ExerciseSessionRecord }
        }
        for (session in filteredSessions) {
            when (val routeResult = session.exerciseRouteResult) {
                is Data -> buildWorkoutRouteMap(session, routeResult.exerciseRoute)
                    ?.let(healthConnectData::add)
                is ConsentRequired -> healthConnectData.add(buildConsentRequiredRouteMap(session))
                is NoData -> Unit
            }
        }
    }

    /** Flutter workout route map for a session and authorized route payload. */
    fun buildWorkoutRouteMap(
        session: ExerciseSessionRecord,
        route: ExerciseRoute?,
    ): Map<String, Any?>? {
        if (route == null || route.route.isEmpty()) return null
        val routePoints = route.route.map { location ->
            mutableMapOf<String, Any?>(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "timestamp" to location.time.toEpochMilli(),
            ).apply {
                location.altitude?.let { put("altitude", it.inMeters) }
                location.horizontalAccuracy?.let { put("horizontalAccuracy", it.inMeters) }
                location.verticalAccuracy?.let { put("verticalAccuracy", it.inMeters) }
            }
        }
        val startTimestamp = routePoints.firstOrNull()?.get("timestamp") as? Long
            ?: session.startTime.toEpochMilli()
        val endTimestamp = routePoints.lastOrNull()?.get("timestamp") as? Long
            ?: session.endTime.toEpochMilli()
        val metadata = mutableMapOf<String, Any?>(
            "workout_uuid" to session.metadata.id,
            "workout_activity_type" to (
                HealthConstants.workoutTypeReverseMap[session.exerciseType] ?: "OTHER"
            ),
            "workout_start_time" to session.startTime.toEpochMilli(),
            "workout_end_time" to session.endTime.toEpochMilli(),
            "route_point_count" to routePoints.size,
        )
        return mutableMapOf(
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

    /** Flutter workout route map that signals route consent is still required. */
    fun buildConsentRequiredRouteMap(session: ExerciseSessionRecord): Map<String, Any?> {
        val metadata = mapOf(
            "workout_uuid" to session.metadata.id,
            "route_requires_consent" to true,
            "workout_activity_type" to (
                HealthConstants.workoutTypeReverseMap[session.exerciseType] ?: "OTHER"
            ),
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
