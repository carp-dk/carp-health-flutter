package cachet.plugins.health.reading

import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord

/*
 * Android 15 (module 350820300) skips a page token's offset of rows of the read's join, not of records
 * (measured with tokens made on the client, one record per request): a speed record's samples, a sleep
 * session's stages, and a pool swim's laps times its segments. With 3 samples a record, offset 1 returns the
 * first record's last 2 samples, 2 its last one, and 3 the second record whole; with 3 stages a session, offset
 * 1 returns the first session without its first stage, 2 with its last one only, 3 the second session; with
 * 2 laps x 2 segments a swim, offsets 2 and 3 return the first swim with 1 lap, 4 the second swim.
 */

/** The rows of [record] in the join of a Health Connect read: one for a record without a child table. */
internal fun joinRows(record: Record): Int = when (record) {
    is HeartRateRecord -> record.samples.size
    is SpeedRecord -> record.samples.size
    is PowerRecord -> record.samples.size
    is CyclingPedalingCadenceRecord -> record.samples.size
    is SkinTemperatureRecord -> record.deltas.size
    is SleepSessionRecord -> record.stages.size
    // Lap by lap, each with every segment.
    is ExerciseSessionRecord -> maxOf(1, record.laps.size) * maxOf(1, record.segments.size)
    else -> 1
}.coerceAtLeast(1)

/** [record] as Android 15 returns it after skipping [rows] of its rows of the join ([joinRows]), fewer than all. */
internal fun withoutRows(record: Record, rows: Int): Record = when (record) {
    is HeartRateRecord -> HeartRateRecord(
        record.startTime, record.startZoneOffset, record.endTime, record.endZoneOffset, record.samples.drop(rows),
        record.metadata,
    )
    is SpeedRecord -> SpeedRecord(
        record.startTime, record.startZoneOffset, record.endTime, record.endZoneOffset, record.samples.drop(rows),
        record.metadata,
    )
    is SleepSessionRecord -> SleepSessionRecord(
        record.startTime, record.startZoneOffset, record.endTime, record.endZoneOffset, record.metadata,
        record.title, record.notes, record.stages.drop(rows),
    )
    is ExerciseSessionRecord -> {
        val segments = maxOf(1, record.segments.size)
        val left = rows until joinRows(record)
        ExerciseSessionRecord(
            startTime = record.startTime, startZoneOffset = record.startZoneOffset,
            endTime = record.endTime, endZoneOffset = record.endZoneOffset, metadata = record.metadata,
            exerciseType = record.exerciseType, title = record.title, notes = record.notes,
            segments = left.map { it % segments }.distinct().sorted().mapNotNull { record.segments.getOrNull(it) },
            laps = left.map { it / segments }.distinct().mapNotNull { record.laps.getOrNull(it) },
            exerciseRoute = (record.exerciseRouteResult as? ExerciseRouteResult.Data)?.exerciseRoute,
        )
    }
    else -> throw UnsupportedOperationException("No rows of ${record::class.simpleName} to leave out")
}
