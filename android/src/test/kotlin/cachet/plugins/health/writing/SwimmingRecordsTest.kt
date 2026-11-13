package cachet.plugins.health.writing

import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.response.InsertRecordsResponse
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.RecordingResult
import cachet.plugins.health.reading.fakeHealthConnect
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** The laps and stroke segments that the exercise session of a swim is written with. */
class SwimmingRecordsTest {
    private val start = 1_700_000_000_000L
    private val end = start + 1_800_000

    // The records of each insert.
    private val inserts = mutableListOf<List<*>>()

    // Health Connect inserts every record it is given; the writes run at once, as it answers without suspending.
    private val writer = WorkoutWriter(
        fakeHealthConnect { method, args ->
            if (method != "insertRecords") throw UnsupportedOperationException(method)
            inserts.add(args.single() as List<*>)
            InsertRecordsResponse(listOf("swim", "distance"))
        },
        CoroutineScope(Dispatchers.Unconfined),
    )

    // [seconds] into the workout.
    private fun at(seconds: Int): Instant = Instant.ofEpochMilli(start + seconds * 1000L)

    // A lap as Dart sends it, from [from] to [to] seconds into the workout.
    private fun lap(from: Int, to: Int, strokeStyle: String? = "freestyle"): Map<String, Any?> =
        mapOf("startTime" to at(from).toEpochMilli(), "endTime" to at(to).toEpochMilli(), "strokeStyle" to strokeStyle)

    // Swimming details as Dart sends them.
    private fun details(poolLength: Any?, vararg laps: Any?): Map<String, Any?> =
        mapOf("poolLength" to poolLength, "laps" to laps.toList())

    // A workout of [activityType] as Dart sends it, with the 'swimming' argument [swimming].
    private fun swim(swimming: Any?, activityType: String = "SWIMMING_POOL") = MethodCall(
        "writeWorkoutData",
        hashMapOf(
            "activityType" to activityType, "startTime" to start, "endTime" to end, "totalDistance" to 200,
            "recordingMethod" to RECORDING_METHOD_ACTIVELY_RECORDED, "swimming" to swimming,
            "totalSwimmingStrokeCount" to 160,
        ),
    )

    // The records that the workout [call] is written as.
    private fun records(call: MethodCall): List<*> =
        workoutRecords(call, HealthConstants.workoutTypeMap.getValue(call.argument<String>("activityType")!!))

    private fun session(call: MethodCall) = records(call).first() as ExerciseSessionRecord

    // The replies of writeWorkoutData and writeWorkoutDataUUID to [call], which each reply once.
    private fun replies(call: MethodCall): List<Any?> {
        val replies = listOf(RecordingResult(), RecordingResult())
        writer.writeWorkoutData(call, replies[0])
        writer.writeWorkoutDataUUID(call, replies[1])
        return replies.map {
            assertEquals(1, it.replies)
            it.value
        }
    }

    @Test
    fun aPoolSwimHasLapsOfThePoolLengthAndASegmentForEachKnownStrokeStyle() {
        val styles = listOf(
            "freestyle", "backstroke", "breaststroke", "butterfly", "mixed", "kickboard", "other", "unknown",
        )
        // A lap of each style every 40 seconds: 30 seconds of swimming and a rest of 10.
        val laps = styles.indices.map { lap(it * 40, it * 40 + 30, styles[it]) }
        assertEquals(listOf(true, "swim"), replies(swim(details(25.0, *laps.toTypedArray()))))

        val records = inserts.first()
        assertEquals(listOf(ExerciseSessionRecord::class, DistanceRecord::class), records.map { it!!::class })
        val session = records.first() as ExerciseSessionRecord
        assertEquals(
            styles.indices.map { ExerciseLap(at(it * 40), at(it * 40 + 30), Length.meters(25.0)) },
            session.laps,
        )
        // Health Connect has no kickboard style, and the lap of the unknown style has no segment.
        val segmentTypes = listOf(
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_FREESTYLE,
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BACKSTROKE,
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BREASTSTROKE,
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BUTTERFLY,
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_MIXED,
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_OTHER,
            ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_OTHER,
        )
        assertEquals(
            segmentTypes.indices.map { ExerciseSegment(at(it * 40), at(it * 40 + 30), segmentTypes[it]) },
            session.segments,
        )
    }

    @Test
    fun anOpenWaterSwimHasLapsWithoutALength() {
        // Laps that touch, from the start of the workout to its end.
        val laps = details(null, lap(0, 600), lap(600, 1200, "breaststroke"), lap(1200, 1800, "unknown"))
        val session = session(swim(laps, "SWIMMING_OPEN_WATER"))
        assertEquals(ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER, session.exerciseType)
        assertEquals(
            listOf(ExerciseLap(at(0), at(600)), ExerciseLap(at(600), at(1200)), ExerciseLap(at(1200), at(1800))),
            session.laps,
        )
        assertEquals(
            listOf(
                ExerciseSegment(at(0), at(600), ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_FREESTYLE),
                ExerciseSegment(at(600), at(1200), ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BREASTSTROKE),
            ),
            session.segments,
        )
    }

    @Test
    fun aSwimWithoutLapsHasNoLapsOrSegments() {
        // Health Connect keeps a pool length only on the laps, so a pool swim without laps keeps none.
        for (swimming in listOf(null, details(25.0), mapOf<String, Any?>())) {
            val records = records(swim(swimming))
            val session = records.first() as ExerciseSessionRecord
            assertEquals(emptyList<ExerciseLap>(), session.laps)
            assertEquals(emptyList<ExerciseSegment>(), session.segments)
            // Health Connect has no record of swimming strokes: totalSwimmingStrokeCount is not written.
            assertEquals(listOf(ExerciseSessionRecord::class, DistanceRecord::class), records.map { it!!::class })
        }
    }

    @Test
    fun poolLengthsOfUpTo1000MetersAreWritten() {
        // 22.86 m is 25 yards; Dart sends doubles, but any number will do.
        for ((poolLength, meters) in listOf(1000.0 to 1000.0, 0.5 to 0.5, 22.86 to 22.86, 50 to 50.0)) {
            assertEquals(Length.meters(meters), session(swim(details(poolLength, lap(0, 30)))).laps.single().length)
        }
    }

    @Test
    fun swimmingDetailsThatAreNotValidReplyFalseAndInsertNothing() {
        val rejected = listOf(
            swim(details(25.0, lap(60, 90), lap(0, 30))) to "Swimming laps must be sorted by start time",
            swim(details(25.0, lap(0, 31), lap(30, 60))) to "Swimming laps must not overlap",
            swim(details(25.0, lap(-1, 30))) to "Swimming laps must be within the workout",
            swim(details(25.0, lap(1770, 1801))) to "Swimming laps must be within the workout",
            swim(details(25.0, lap(30, 30))) to "startTime must be before endTime.",
            swim(details(25.0, lap(30, 20))) to "startTime must be before endTime.",
            swim(details(0.0, lap(0, 30))) to "The pool length must be more than 0 and at most 1000 m",
            swim(details(-25.0, lap(0, 30))) to "The pool length must be more than 0 and at most 1000 m",
            swim(details(1000.5, lap(0, 30))) to "The pool length must be more than 0 and at most 1000 m",
            swim(details(Double.NaN, lap(0, 30))) to "The pool length must be more than 0 and at most 1000 m",
            swim(details(25.0, lap(0, 30)), "SWIMMING_OPEN_WATER") to "Only pool swims have a pool length",
            swim(details(null, lap(0, 30)), "RUNNING") to "Only pool and open water swims have swimming details",
            // Stroke styles that are not SwimmingStrokeStyle names.
            swim(details(25.0, lap(0, 30, "crawl"))) to "crawl is not a stroke style",
            swim(details(25.0, lap(0, 30, "FREESTYLE"))) to "FREESTYLE is not a stroke style",
            swim(details(25.0, lap(0, 30, null))) to "null is not a stroke style",
            // Details that do not have the shape Dart sends.
            swim(listOf(lap(0, 30))) to "Argument 'swimming' must be a map",
            swim(mapOf("laps" to lap(0, 30))) to "Swimming 'laps' must be a list",
            swim(details(25.0, "lap")) to "A swimming lap must be a map",
            swim(details("25", lap(0, 30))) to "'poolLength' must be a number",
            swim(details(25.0, lap(0, 30) + ("endTime" to "30"))) to "Swimming lap endTime must be a number",
        )
        for ((call, message) in rejected) {
            assertEquals(message, assertThrows(IllegalArgumentException::class.java) { records(call) }.message)
            assertEquals(message, listOf(false, ""), replies(call))
        }
        assertEquals(emptyList<List<*>>(), inserts)
    }

    @Test
    fun everyStrokeStyleSegmentFitsBothKindsOfSwim() {
        // Health Connect rejects a session with a segment of a type that does not fit its exercise type.
        val swims = listOf(
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL,
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER,
        )
        for (segmentType in strokeStyleSegmentTypes.values) {
            for (exerciseType in swims) {
                assertTrue(ExerciseSegment.isSegmentTypeCompatibleWithSessionType(segmentType, exerciseType))
            }
        }
    }
}
