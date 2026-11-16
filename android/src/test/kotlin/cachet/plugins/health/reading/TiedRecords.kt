package cachet.plugins.health.reading

import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Velocity
import java.time.Instant

/*
 * Records that start together, as the devices were measured with: each of its own app ("<prefix><index>"), so
 * that its data points tell which record they come from, and of its own end, as Health Connect would take
 * records of one app with the same start and end for one.
 */

/** [count] steps records that start at [at], from number [first] on. */
internal fun tiedSteps(at: Instant, count: Int, first: Int = 0, prefix: String = "app.s"): List<StepsRecord> =
    List(count) { i ->
        val n = first + i
        StepsRecord(at, null, at.plusSeconds(60).plusMillis(n.toLong()), null, 1, writtenBy("$prefix$n", "s$n"))
    }

/** [count] speed records that start at [at], each with [samples] samples a second apart. */
internal fun tiedSpeeds(at: Instant, count: Int, samples: Int = 3, first: Int = 0): List<SpeedRecord> =
    List(count) { i ->
        val n = first + i
        val points = List(samples) { SpeedRecord.Sample(at.plusSeconds(it.toLong()), Velocity.metersPerSecond(2.0)) }
        val end = at.plusSeconds(samples.toLong()).plusMillis(n.toLong())
        SpeedRecord(at, null, end, null, points, writtenBy("app.v$n", "v$n"))
    }

/** [count] sleep sessions that start at [at], each awake for 10 minutes, then light for 30, then deep. */
internal fun tiedNights(at: Instant, count: Int, first: Int = 0): List<SleepSessionRecord> = List(count) { i ->
    val n = first + i
    val end = at.plusSeconds(3600L + n)
    val stages = listOf(
        SleepSessionRecord.Stage(at, at.plusSeconds(600), SleepSessionRecord.STAGE_TYPE_AWAKE),
        SleepSessionRecord.Stage(at.plusSeconds(600), at.plusSeconds(2400), SleepSessionRecord.STAGE_TYPE_LIGHT),
        SleepSessionRecord.Stage(at.plusSeconds(2400), end, SleepSessionRecord.STAGE_TYPE_DEEP),
    )
    SleepSessionRecord(at, null, end, null, writtenBy("app.n$n", "n$n"), stages = stages)
}

/** [count] pool swims that start at [at], each of two laps (freestyle, then breaststroke) in two segments. */
internal fun tiedSwims(at: Instant, count: Int, first: Int = 0): List<ExerciseSessionRecord> = List(count) { i ->
    val n = first + i
    fun lap(from: Long) = ExerciseLap(at.plusSeconds(from), at.plusSeconds(from + 60), Length.meters(25.0))
    fun segment(from: Long, type: Int) = ExerciseSegment(at.plusSeconds(from), at.plusSeconds(from + 60), type)
    ExerciseSessionRecord(
        startTime = at, startZoneOffset = null, endTime = at.plusSeconds(1800L + n), endZoneOffset = null,
        metadata = writtenBy("app.w$n", "w$n"), exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL,
        segments = listOf(
            segment(0, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_FREESTYLE),
            segment(60, ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BREASTSTROKE),
        ),
        laps = listOf(lap(0), lap(60)),
    )
}
