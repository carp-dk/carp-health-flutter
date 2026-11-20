package cachet.plugins.health.writing

import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import io.flutter.plugin.common.MethodCall
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WorkoutWriterTest {
    private val start = 1_700_000_000_000L

    /** The records of a run with a distance and energy burned, written with the [extra] arguments. */
    private fun run(vararg extra: Pair<String, Any>): List<Record> {
        val arguments = hashMapOf<String, Any?>(
            "activityType" to "RUNNING",
            "startTime" to start,
            "endTime" to start + 1_800_000,
            "totalDistance" to 5000,
            "totalEnergyBurned" to 200,
            "recordingMethod" to RECORDING_METHOD_MANUAL_ENTRY,
            *extra,
        )
        val call = MethodCall("writeWorkoutData", arguments)
        val records = workoutRecords(call, ExerciseSessionRecord.EXERCISE_TYPE_RUNNING)
        val types = listOf(ExerciseSessionRecord::class, DistanceRecord::class, TotalCaloriesBurnedRecord::class)
        assertEquals(types, records.map { it::class })
        return records
    }

    /** The zone offsets of the start and the end of [record]. */
    private fun zoneOffsets(record: Record): Pair<ZoneOffset?, ZoneOffset?> = when (record) {
        is ExerciseSessionRecord -> record.startZoneOffset to record.endZoneOffset
        is DistanceRecord -> record.startZoneOffset to record.endZoneOffset
        is TotalCaloriesBurnedRecord -> record.startZoneOffset to record.endZoneOffset
        else -> error("Unexpected $record")
    }

    @Test
    fun theOtherRecordsHaveTheClientRecordIdOfTheSessionWithASuffix() {
        val records = run("clientRecordId" to "run-1", "clientRecordVersion" to 3.0)
        assertEquals(listOf("run-1", "run-1:distance", "run-1:calories"), records.map { it.metadata.clientRecordId })
        assertEquals(listOf(3L, 3L, 3L), records.map { it.metadata.clientRecordVersion })
    }

    @Test
    fun withoutAClientRecordIdTheRecordsHaveNone() {
        val records = run()
        assertEquals("RUNNING", (records[0] as ExerciseSessionRecord).title)
        for (record in records) {
            assertNull(record.metadata.clientRecordId)
            assertEquals(0L, record.metadata.clientRecordVersion)
        }
    }

    @Test
    fun everyRecordHasTheZoneOffsets() {
        val records = run("startZoneOffsetSeconds" to 19_800, "endZoneOffsetSeconds" to -28_800)
        val offsets = ZoneOffset.ofHoursMinutes(5, 30) to ZoneOffset.ofHours(-8)
        assertEquals(List(3) { offsets }, records.map { zoneOffsets(it) })
        // Without them, Health Connect sets its default.
        assertEquals(List(3) { null to null }, run().map { zoneOffsets(it) })
    }
}
