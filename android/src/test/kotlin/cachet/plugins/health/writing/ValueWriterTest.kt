package cachet.plugins.health.writing

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.response.InsertRecordsResponse
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.RecordingResult
import cachet.plugins.health.fakeOf
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class ValueWriterTest {
    private val start = 1_700_000_000_000L
    private val end = start + 600_000

    // Health Connect inserts every record it is given; the writes run at once, as it answers without suspending.
    private val writer = ValueWriter(
        fakeOf<HealthConnectClient> { method ->
            if (method != "insertRecords") throw UnsupportedOperationException(method)
            InsertRecordsResponse(listOf("id"))
        },
        CoroutineScope(Dispatchers.Unconfined),
    )

    // A writeData call as Dart sends it.
    private fun write(type: String, startTime: Long, endTime: Long, value: Double) = MethodCall(
        "writeData",
        hashMapOf(
            "dataTypeKey" to type, "startTime" to startTime, "endTime" to endTime, "value" to value,
            "recordingMethod" to RECORDING_METHOD_MANUAL_ENTRY,
        ),
    )

    // The replies of writeData and writeDataUUID to [call].
    private fun replies(call: MethodCall): List<Any?> = listOf(
        RecordingResult().also { writer.writeData(call, it) },
        RecordingResult().also { writer.writeDataUUID(call, it) },
    ).map { result ->
        assertEquals(1, result.replies)
        result.value
    }

    @Test
    fun aValueIsWritten() {
        assertEquals(listOf(true, "id"), replies(write(HealthConstants.STEPS, start, end, 10.0)))
    }

    @Test
    fun aValueHealthConnectRejectsFailsTheWriteNotTheCall() {
        // A step count of 0 is out of Health Connect's range. It is checked while the record is built:
        // here by connect-client, on Android 14+ by the platform, which checked some types on insert before.
        assertEquals(listOf(false, ""), replies(write(HealthConstants.STEPS, start, end, 0.0)))
    }

    @Test
    fun aValueWithADurationThatEndsWhenItStartsFailsTheCall() {
        // The plugin's own check, before the record is built, as on every Android version before.
        val call = write(HealthConstants.STEPS, start, start, 10.0)
        for (method in listOf(writer::writeData, writer::writeDataUUID)) {
            val result = RecordingResult()
            val error = assertThrows(IllegalArgumentException::class.java) { method(call, result) }
            assertEquals("startTime must be before endTime.", error.message)
            assertEquals(0, result.replies)
        }
    }

    @Test
    fun aSeriesValueMayEndWhenItStarts() {
        assertEquals(listOf(true, "id"), replies(write(HealthConstants.HEART_RATE, start, start, 70.0)))
    }
}
