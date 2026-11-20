package cachet.plugins.health.writing

import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.units.Length
import io.flutter.plugin.common.MethodCall
import java.time.Instant

/** The longest pool a swim is written with, in meters (Health Connect allows laps of up to 1000 km). */
private const val MAX_POOL_LENGTH_METERS = 1000.0

/** The stroke style of a lap whose style is not known, which is written without a segment. */
internal const val UNKNOWN_STROKE_STYLE = "unknown"

/**
 * The swimming segment type that a lap of each other stroke style (a SwimmingStrokeStyle name, as Dart
 * sends it) is written with. Health Connect has no kickboard style: kickboard laps are SWIMMING_OTHER,
 * so they read back as 'other'.
 */
internal val strokeStyleSegmentTypes: Map<String, Int> = mapOf(
    "mixed" to ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_MIXED,
    "freestyle" to ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_FREESTYLE,
    "backstroke" to ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BACKSTROKE,
    "breaststroke" to ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BREASTSTROKE,
    "butterfly" to ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BUTTERFLY,
    "kickboard" to ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_OTHER,
    "other" to ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_OTHER,
)

/** The laps of the exercise session of a swim, and the segments that hold their stroke styles. */
internal class SwimmingLaps(val laps: List<ExerciseLap>, val segments: List<ExerciseSegment>)

/**
 * The laps and stroke segments of the exercise session of a writeWorkoutData or writeWorkoutDataUUID
 * [call] of [exerciseType] from [startTime] to [endTime], from its optional 'swimming' argument (none
 * without it): a map with the pool length 'poolLength' (meters, optional) and the 'laps', maps with
 * 'startTime' and 'endTime' (epoch milliseconds) and a SwimmingStrokeStyle name 'strokeStyle'. Each lap
 * is an ExerciseLap whose length is the pool length: Health Connect has no pool length of a session, so a
 * pool swim without laps keeps none. A lap of a known stroke style is also an ExerciseSegment of that
 * style over the same time ([strokeStyleSegmentTypes]), as Health Connect's laps have no style.
 *
 * Throws IllegalArgumentException, as the Dart side does before it sends them, for swimming details
 * that are not of this shape or that Health Connect would reject: details of a workout that is not a
 * pool or open water swim, a pool length of an open water swim or one that is not more than 0 and at
 * most 1000 m, an unknown stroke style, a lap that does not end after it starts or lies outside the
 * workout, or laps that are not sorted by start time or overlap (laps may touch).
 */
internal fun swimmingLaps(call: MethodCall, exerciseType: Int, startTime: Instant, endTime: Instant): SwimmingLaps {
    val swimming = when (val raw = call.argument<Any>("swimming")) {
        null -> return SwimmingLaps(emptyList(), emptyList())
        is Map<*, *> -> raw
        else -> throw IllegalArgumentException("Argument 'swimming' must be a map")
    }
    val pool = exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL
    require(pool || exerciseType == ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER) {
        "Only pool and open water swims have swimming details"
    }
    val poolLength = poolLength(swimming["poolLength"], pool)
    val laps = when (val rawLaps = swimming["laps"]) {
        null -> emptyList()
        is List<*> -> rawLaps.map(::lap)
        else -> throw IllegalArgumentException("Swimming 'laps' must be a list")
    }
    for (lap in laps) {
        require(!lap.startTime.isBefore(startTime) && !lap.endTime.isAfter(endTime)) {
            "Swimming laps must be within the workout"
        }
    }
    for ((previous, next) in laps.zipWithNext()) {
        require(!next.startTime.isBefore(previous.startTime)) { "Swimming laps must be sorted by start time" }
        require(!previous.endTime.isAfter(next.startTime)) { "Swimming laps must not overlap" }
    }
    val length = poolLength?.let { Length.meters(it) }
    return SwimmingLaps(
        laps = laps.map { ExerciseLap(it.startTime, it.endTime, length) },
        segments = laps.mapNotNull { lap ->
            lap.segmentType?.let { ExerciseSegment(lap.startTime, lap.endTime, it) }
        },
    )
}

/** A lap as Dart sends it, with the segment type of its stroke style (null for an unknown style). */
private class Lap(val startTime: Instant, val endTime: Instant, val segmentType: Int?)

/** The lap in [raw], a map with 'startTime' and 'endTime' (epoch milliseconds) and 'strokeStyle'. */
private fun lap(raw: Any?): Lap {
    val lap = raw as? Map<*, *> ?: throw IllegalArgumentException("A swimming lap must be a map")
    val style = lap["strokeStyle"] as? String
    val segmentType = when (style) {
        UNKNOWN_STROKE_STYLE -> null
        else -> strokeStyleSegmentTypes[style] ?: throw IllegalArgumentException("$style is not a stroke style")
    }
    val startTime = Instant.ofEpochMilli(lap.requireTime("startTime"))
    val endTime = Instant.ofEpochMilli(lap.requireTime("endTime"))
    requireStartBeforeEnd(startTime, endTime)
    return Lap(startTime, endTime, segmentType)
}

/** The pool length in meters in [raw] (null if not given), which only a [pool] swim may have. */
private fun poolLength(raw: Any?, pool: Boolean): Double? {
    if (raw == null) return null
    val meters = (raw as? Number)?.toDouble() ?: throw IllegalArgumentException("'poolLength' must be a number")
    require(pool) { "Only pool swims have a pool length" }
    // Not NaN either.
    require(meters > 0 && meters <= MAX_POOL_LENGTH_METERS) { "The pool length must be more than 0 and at most 1000 m" }
    return meters
}

private fun Map<*, *>.requireTime(key: String): Long =
    (this[key] as? Number)?.toLong() ?: throw IllegalArgumentException("Swimming lap $key must be a number")
