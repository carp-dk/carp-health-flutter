package cachet.plugins.health.writing

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.response.InsertRecordsResponse
import cachet.plugins.health.RecordingResult
import io.flutter.plugin.common.MethodCall
import java.lang.reflect.Proxy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Test

class BloodPressureWriterTest {
    private val inserted = mutableListOf<Record>()

    // Health Connect keeps the records it is given; the write runs at once, as it answers without suspending.
    private val writer = BloodPressureWriter(
        Proxy.newProxyInstance(
            HealthConnectClient::class.java.classLoader,
            arrayOf(HealthConnectClient::class.java),
        ) { _, method, args ->
            if (method.name != "insertRecords") throw UnsupportedOperationException(method.name)
            @Suppress("UNCHECKED_CAST")
            inserted += args!![0] as List<Record>
            InsertRecordsResponse(listOf("id"))
        } as HealthConnectClient,
        CoroutineScope(Dispatchers.Unconfined),
    )

    // A writeBloodPressure call as Dart sends it, with [extra] arguments.
    private fun write(extra: Map<String, Any?> = emptyMap()): BloodPressureRecord {
        val result = RecordingResult()
        writer.writeBloodPressure(
            MethodCall(
                "writeBloodPressure",
                hashMapOf<String, Any?>(
                    "systolic" to 120.0, "diastolic" to 80.0, "startTime" to 1_700_000_000_000L,
                    "recordingMethod" to RECORDING_METHOD_MANUAL_ENTRY,
                ) + extra,
            ),
            result,
        )
        assertEquals(true, result.value)
        return inserted.single() as BloodPressureRecord
    }

    @Test
    fun theBodyPositionAndMeasurementLocationAreWritten() {
        val record = write(
            mapOf(
                "bodyPosition" to BloodPressureRecord.BODY_POSITION_RECLINING,
                "measurementLocation" to BloodPressureRecord.MEASUREMENT_LOCATION_RIGHT_WRIST,
            ),
        )

        assertEquals(BloodPressureRecord.BODY_POSITION_RECLINING, record.bodyPosition)
        assertEquals(BloodPressureRecord.MEASUREMENT_LOCATION_RIGHT_WRIST, record.measurementLocation)
    }

    @Test
    fun aMissingBodyPositionAndMeasurementLocationAreWrittenAsUnknown() {
        val record = write()

        assertEquals(BloodPressureRecord.BODY_POSITION_UNKNOWN, record.bodyPosition)
        assertEquals(BloodPressureRecord.MEASUREMENT_LOCATION_UNKNOWN, record.measurementLocation)
    }
}
