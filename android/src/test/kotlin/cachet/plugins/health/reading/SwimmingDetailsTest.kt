package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.changedDataPoints
import cachet.plugins.health.fakeOf
import cachet.plugins.health.writing.workoutRecords
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The swimming details that reads report for pool and open water swims. */
class SwimmingDetailsTest {
    private val start = Instant.parse("2026-11-08T07:00:00Z")
    private val end = start.plusSeconds(1800)
    private val pool = ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL
    private val openWater = ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER
    private val running = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING

    // [seconds] into the swim.
    private fun at(seconds: Long): Instant = start.plusSeconds(seconds)

    // A lap from [from] to [to] seconds into the swim, of [meters].
    private fun lap(from: Long, to: Long, meters: Double? = 25.0) =
        ExerciseLap(at(from), at(to), meters?.let { Length.meters(it) })

    private fun segment(from: Long, to: Long, segmentType: Int) = ExerciseSegment(at(from), at(to), segmentType)

    /** A swim of [exerciseType] that a watch app wrote, with [laps] and [segments] in the order given. */
    private fun swim(
        laps: List<ExerciseLap>,
        segments: List<ExerciseSegment> = emptyList(),
        exerciseType: Int = pool,
    ) = ExerciseSessionRecord(
        startTime = start,
        startZoneOffset = null,
        endTime = end,
        endZoneOffset = null,
        metadata = metadata(Metadata.RECORDING_METHOD_ACTIVELY_RECORDED, "swim", DataOrigin("com.example.watch")),
        exerciseType = exerciseType,
        segments = segments,
        laps = laps,
    )

    /** The laps of [details]: their start and end in seconds into the swim, and their stroke style. */
    private fun laps(details: Map<*, *>?): List<Triple<Long, Long, Any?>> =
        (details!!["laps"] as List<*>).map {
            val lap = it as Map<*, *>
            Triple(seconds(lap["startTime"]), seconds(lap["endTime"]), lap["strokeStyle"])
        }

    private fun seconds(epochMilli: Any?): Long = ((epochMilli as Long) - start.toEpochMilli()) / 1000

    @Test
    fun lapsAreSortedAndHaveTheStrokeStyleOfTheSegmentTheyStartIn() {
        // Another app's swim: its laps are not sorted (Health Connect sorts them only on Android 14 and later),
        // and its segments are sets of laps, rests and a segment without a style.
        val laps = listOf(
            lap(60, 90), lap(0, 30), lap(30, 60), lap(120, 150), lap(150, 180),
            lap(180, 190), lap(200, 230), lap(270, 300), lap(240, 270), lap(300, 330),
        )
        val segments = listOf(
            segment(118, 150, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BREASTSTROKE),
            segment(0, 90, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_FREESTYLE),
            segment(90, 118, ExerciseSegment.EXERCISE_SEGMENT_TYPE_REST),
            segment(150, 179, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BUTTERFLY),
            segment(195, 240, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_POOL),
            segment(240, 300, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_OTHER),
            segment(300, 330, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_MIXED),
        )
        val session = swim(laps, segments)
        // The session keeps them as given, as Health Connect does before Android 14.
        assertEquals(laps, session.laps)
        val details = swimmingDetails(session)
        assertEquals(
            listOf(
                // A set of three laps.
                Triple(0L, 30L, "freestyle"), Triple(30L, 60L, "freestyle"), Triple(60L, 90L, "freestyle"),
                // A lap that starts after its segment.
                Triple(120L, 150L, "breaststroke"),
                // A lap that starts where one segment ends and the next starts.
                Triple(150L, 180L, "butterfly"),
                // A lap in no segment, and one in a segment without a style.
                Triple(180L, 190L, "unknown"), Triple(200L, 230L, "unknown"),
                Triple(240L, 270L, "other"), Triple(270L, 300L, "other"),
                Triple(300L, 330L, "mixed"),
            ),
            laps(details),
        )
        assertEquals(25.0, details!!["poolLength"])
    }

    @Test
    fun thePoolLengthIsTheLengthThatAllLapsHave() {
        val expected = listOf(
            listOf(lap(0, 30, 50.0), lap(30, 60, 50.0)) to 50.0,
            // 25 yards.
            listOf(lap(0, 30, 22.86), lap(30, 60, 22.86)) to 22.86,
            listOf(lap(0, 30, 25.0), lap(30, 60, 50.0)) to null,
            listOf(lap(0, 30, 25.0), lap(30, 60, null)) to null,
            listOf(lap(0, 30, null), lap(30, 60, null)) to null,
            listOf(lap(0, 30, 0.0), lap(30, 60, 0.0)) to null,
        )
        for ((laps, poolLength) in expected) {
            assertEquals("$laps", poolLength, swimmingDetails(swim(laps))!!["poolLength"])
        }
        // An open water swim has no pool, whatever the length of its laps, and its segment says no stroke style.
        val openWaterSegment = segment(0, 600, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_OPEN_WATER)
        val details = swimmingDetails(swim(listOf(lap(0, 600, 100.0)), listOf(openWaterSegment), openWater))
        assertNull(details!!["poolLength"])
        assertEquals(listOf(Triple(0L, 600L, "unknown")), laps(details))
    }

    @Test
    fun onlySwimsWithLapsHaveSwimmingDetails() {
        val freestyle = segment(0, 30, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_FREESTYLE)
        assertNull(swimmingDetails(swim(listOf(lap(0, 30)), exerciseType = running)))
        assertNull(swimmingDetails(swim(emptyList(), listOf(freestyle))))
        assertNull(swimmingDetails(swim(emptyList(), exerciseType = openWater)))
    }

    @Test
    fun workoutsAndChangesHaveTheirSwimmingDetails() {
        val backstroke = segment(0, 60, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BACKSTROKE)
        val workouts = listOf(
            swim(listOf(lap(30, 60), lap(0, 30)), listOf(backstroke)),
            swim(listOf(lap(0, 30)), exerciseType = running),
        )
        val expected = listOf(swimmingDetails(workouts[0]), null)
        assertEquals(listOf(Triple(0L, 30L, "backstroke"), Triple(30L, 60L, "backstroke")), laps(expected[0]))

        // Without permission to read the totals, nothing else is read.
        val read = mutableListOf<Map<String, Any?>>()
        val client = fakeOf<HealthConnectClient> { error("Unexpected call of $it") }
        val converter = WorkoutConverter(client, HealthRecordingFilter())
        runBlocking { converter.handleWorkoutData(workouts, emptyList(), read, emptySet()) }
        assertEquals(expected, read.map { it["swimming"] })
        assertEquals(expected, changedDataPoints(workouts).map { it["swimming"] })
    }

    @Test
    fun aSwimReadsBackAsItWasWritten() {
        val styles = listOf(
            "unknown", "mixed", "freestyle", "backstroke", "breaststroke", "butterfly", "kickboard", "other",
        )
        // Laps of each style that touch, and one after a rest.
        val laps = styles.indices.map { writtenLap(it * 30L, it * 30L + 30, styles[it]) } +
            writtenLap(300, 330, "freestyle")
        for ((activityType, poolLength) in listOf("SWIMMING_POOL" to 25.0, "SWIMMING_OPEN_WATER" to null)) {
            val call = MethodCall(
                "writeWorkoutData",
                hashMapOf(
                    "activityType" to activityType,
                    "startTime" to start.toEpochMilli(),
                    "endTime" to end.toEpochMilli(),
                    "recordingMethod" to Metadata.RECORDING_METHOD_ACTIVELY_RECORDED,
                    "swimming" to mapOf("poolLength" to poolLength, "laps" to laps),
                ),
            )
            val exerciseType = if (poolLength == null) openWater else pool
            val details = swimmingDetails(workoutRecords(call, exerciseType).first() as ExerciseSessionRecord)
            // Health Connect has no kickboard style: kickboard laps read back as other.
            val read = laps.map { if (it["strokeStyle"] == "kickboard") it + ("strokeStyle" to "other") else it }
            assertEquals(activityType, mapOf("poolLength" to poolLength, "laps" to read), details)
        }
    }

    // A lap as Dart writes it and reads it back, from [from] to [to] seconds into the swim.
    private fun writtenLap(from: Long, to: Long, strokeStyle: String): Map<String, Any> =
        mapOf("startTime" to at(from).toEpochMilli(), "endTime" to at(to).toEpochMilli(), "strokeStyle" to strokeStyle)
}
