package cachet.plugins.health.reading

import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord

/**
 * The SwimmingStrokeStyle name of each swimming segment type that says a stroke style. Health Connect
 * has no kickboard style, so SWIMMING_OTHER is 'other'. SWIMMING_POOL and SWIMMING_OPEN_WATER segments
 * say no style.
 */
private val segmentStrokeStyles: Map<Int, String> = mapOf(
    ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_MIXED to "mixed",
    ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_FREESTYLE to "freestyle",
    ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BACKSTROKE to "backstroke",
    ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BREASTSTROKE to "breaststroke",
    ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BUTTERFLY to "butterfly",
    ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_OTHER to "other",
)

/**
 * The swimming details of [session] for the 'swimming' key of a workout, in the shape that
 * writeWorkoutData takes them. The 'laps' are sorted by start time (Health Connect does not sort them
 * on every Android version), each with its 'startTime' and 'endTime' (epoch milliseconds) and the
 * 'strokeStyle' of the swimming segment it starts in ([segmentStrokeStyles]), 'unknown' if it starts in
 * none, as Health Connect's laps have no style and other apps' segments need not match the laps. The
 * 'poolLength' of a pool swim is the length in meters that all its laps have, null if their lengths
 * differ or one has none, and that of an open water swim is null. Null for a workout that is not a pool
 * or open water swim, and for a swim without laps: Health Connect keeps a pool length only on the laps.
 */
internal fun swimmingDetails(session: ExerciseSessionRecord): Map<String, Any?>? {
    val pool = session.exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL
    val swim = pool || session.exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER
    if (!swim || session.laps.isEmpty()) return null
    val laps = session.laps.sortedBy { it.startTime }
    val styleSegments = session.segments.filter { it.segmentType in segmentStrokeStyles }
    return mapOf(
        "poolLength" to if (pool) sharedLength(laps) else null,
        "laps" to laps.map { lap ->
            mapOf(
                "startTime" to lap.startTime.toEpochMilli(),
                "endTime" to lap.endTime.toEpochMilli(),
                "strokeStyle" to strokeStyle(lap, styleSegments),
            )
        },
    )
}

/** The stroke style of [lap]: that of the segment of [segments] it starts in, 'unknown' if none. */
private fun strokeStyle(lap: ExerciseLap, segments: List<ExerciseSegment>): String {
    // Segments do not overlap, and a lap that starts where one segment ends starts in the next.
    val segment = segments.firstOrNull { !lap.startTime.isBefore(it.startTime) && lap.startTime.isBefore(it.endTime) }
    return segment?.let { segmentStrokeStyles[it.segmentType] } ?: "unknown"
}

/**
 * The length in meters that all [laps] have, null if their lengths differ or one has none. Health
 * Connect allows laps of 0 m, which is no pool length either.
 */
private fun sharedLength(laps: List<ExerciseLap>): Double? =
    laps.map { it.length?.inMeters }.distinct().singleOrNull()?.takeIf { it > 0 }
