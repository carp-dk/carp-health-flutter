package cachet.plugins.health.writing

import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.response.InsertRecordsResponse
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.RecordingResult
import cachet.plugins.health.reading.fakeHealthConnect
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SleepSessionWriterTest {
    private val start = 1_700_000_000_000L
    private val end = start + 8 * 3_600_000

    // The records of each insert.
    private val inserts = mutableListOf<List<*>>()

    // Health Connect inserts every record it is given; the writes run at once, as it answers without suspending.
    private val writer = SleepSessionWriter(
        fakeHealthConnect { method, args ->
            if (method != "insertRecords") throw UnsupportedOperationException(method)
            inserts.add(args.single() as List<*>)
            InsertRecordsResponse(listOf("id"))
        },
        CoroutineScope(Dispatchers.Unconfined),
    )

    // [minutes] into the session.
    private fun at(minutes: Int): Instant = Instant.ofEpochMilli(start + minutes * 60_000L)

    // A stage as Dart sends it, from [from] to [to] minutes into the session.
    private fun stage(type: String, from: Int, to: Int): Map<String, Any> =
        mapOf("type" to type, "startTime" to at(from).toEpochMilli(), "endTime" to at(to).toEpochMilli())

    // A writeSleepSession call as Dart sends it.
    private fun session(
        stages: List<Map<String, Any>>,
        recordingMethod: Int = RECORDING_METHOD_AUTOMATICALLY_RECORDED,
        endTime: Long = end,
        title: String? = "Night",
        notes: String? = "Slept well",
    ) = MethodCall(
        "writeSleepSession",
        hashMapOf(
            "startTime" to start, "endTime" to endTime, "title" to title, "notes" to notes,
            "recordingMethod" to recordingMethod, "stages" to stages,
        ),
    )

    // The reply of writeSleepSession to [call], which replies once.
    private fun reply(call: MethodCall, writer: SleepSessionWriter = this.writer): Any? {
        val result = RecordingResult()
        writer.writeSleepSession(call, result)
        assertEquals(1, result.replies)
        return result.value
    }

    @Test
    fun aSessionIsInsertedAsOneRecordWithItsStages() {
        val stages = listOf(
            stage(HealthConstants.SLEEP_LIGHT, 0, 60),
            stage(HealthConstants.SLEEP_DEEP, 60, 120),
            stage(HealthConstants.SLEEP_REM, 150, 180),
        )
        assertEquals(true, reply(session(stages)))
        val record = inserts.single().single() as SleepSessionRecord
        assertEquals(at(0) to at(480), record.startTime to record.endTime)
        assertEquals("Night" to "Slept well", record.title to record.notes)
        assertEquals(
            listOf(
                SleepSessionRecord.Stage(at(0), at(60), SleepSessionRecord.STAGE_TYPE_LIGHT),
                SleepSessionRecord.Stage(at(60), at(120), SleepSessionRecord.STAGE_TYPE_DEEP),
                SleepSessionRecord.Stage(at(150), at(180), SleepSessionRecord.STAGE_TYPE_REM),
            ),
            record.stages,
        )
        assertEquals(buildMetadata(RECORDING_METHOD_AUTOMATICALLY_RECORDED), record.metadata)
    }

    @Test
    fun aSessionWithoutStagesTitleOrNotes() {
        assertEquals(true, reply(session(emptyList(), title = null, notes = null)))
        val record = inserts.single().single() as SleepSessionRecord
        assertEquals(emptyList<SleepSessionRecord.Stage>(), record.stages)
        assertNull(record.title)
        assertNull(record.notes)
    }

    @Test
    fun everySleepStageTypeIsWrittenAsItsHealthConnectStage() {
        val expected = listOf(
            HealthConstants.SLEEP_AWAKE to SleepSessionRecord.STAGE_TYPE_AWAKE,
            HealthConstants.SLEEP_AWAKE_IN_BED to SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED,
            HealthConstants.SLEEP_ASLEEP to SleepSessionRecord.STAGE_TYPE_SLEEPING,
            HealthConstants.SLEEP_LIGHT to SleepSessionRecord.STAGE_TYPE_LIGHT,
            HealthConstants.SLEEP_DEEP to SleepSessionRecord.STAGE_TYPE_DEEP,
            HealthConstants.SLEEP_REM to SleepSessionRecord.STAGE_TYPE_REM,
            HealthConstants.SLEEP_OUT_OF_BED to SleepSessionRecord.STAGE_TYPE_OUT_OF_BED,
            HealthConstants.SLEEP_UNKNOWN to SleepSessionRecord.STAGE_TYPE_UNKNOWN,
        )
        val types = expected.map { it.first }
        assertEquals(types.toSet(), sleepStageTypes.keys)
        // An hour of each, filling the eight hours of the session.
        val stages = types.mapIndexed { hour, type -> stage(type, hour * 60, hour * 60 + 60) }
        val written = sleepSessionRecord(session(stages)).stages
        assertEquals(expected.map { it.second }, written.map { it.stage })
        // Reads report each stage as the type it was written as.
        assertEquals(types, written.map { HealthConstants.mapSleepStageToType[it.stage] })
    }

    @Test
    fun theRecordingMethodIsTheOneDartSends() {
        // RecordingMethod.toInt(): 0 unknown, 1 active, 2 automatic, 3 manual.
        val expected = listOf(
            Metadata.RECORDING_METHOD_UNKNOWN,
            Metadata.RECORDING_METHOD_ACTIVELY_RECORDED,
            Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED,
            Metadata.RECORDING_METHOD_MANUAL_ENTRY,
        )
        for ((value, recordingMethod) in expected.withIndex()) {
            val metadata = sleepSessionRecord(session(emptyList(), recordingMethod = value)).metadata
            assertEquals("$value", recordingMethod, metadata.recordingMethod)
            assertEquals("$value", buildMetadata(value), metadata)
        }
    }

    @Test
    fun anUnknownStageTypeRepliesFalseAndInsertsNothing() {
        // SLEEP_IN_BED is no Health Connect stage, and a session is no stage of one.
        val types = listOf(HealthConstants.SLEEP_IN_BED, HealthConstants.SLEEP_SESSION, HealthConstants.STEPS, "")
        for (type in types) {
            val stages = listOf(stage(HealthConstants.SLEEP_DEEP, 0, 60), stage(type, 60, 120))
            assertEquals(type, false, reply(session(stages)))
        }
        assertEquals(emptyList<List<*>>(), inserts)
    }

    @Test
    fun aSessionHealthConnectRejectsRepliesFalseAndInsertsNothing() {
        // connect-client checks the stages before Android 14, as in these tests; on Android 14+ the
        // platform does. Sessions that end when they start fail on every version (requireStartBeforeEnd).
        val rejected = listOf(
            session(emptyList(), endTime = start),
            session(emptyList(), endTime = start - 1),
            session(listOf(stage(HealthConstants.SLEEP_LIGHT, 0, 60), stage(HealthConstants.SLEEP_DEEP, 59, 120))),
            session(listOf(stage(HealthConstants.SLEEP_LIGHT, -1, 60))),
            session(listOf(stage(HealthConstants.SLEEP_LIGHT, 420, 481))),
            session(listOf(stage(HealthConstants.SLEEP_LIGHT, 60, 60))),
        )
        for (call in rejected) {
            assertEquals(false, reply(call))
        }
        assertEquals(emptyList<List<*>>(), inserts)
    }

    @Test
    fun aFailedInsertRepliesFalse() {
        val denied = SleepSessionWriter(
            fakeHealthConnect { _, _ -> throw SecurityException("Caller doesn't have WRITE_SLEEP") },
            CoroutineScope(Dispatchers.Unconfined),
        )
        assertEquals(false, reply(session(listOf(stage(HealthConstants.SLEEP_DEEP, 0, 60))), denied))
    }
}
