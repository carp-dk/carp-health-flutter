package cachet.plugins.health.writing

import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Mass
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthRecordingFilter
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RecordMetadataTest {
    @Test
    fun recordingMethodsAreTheValuesDartSends() {
        // RecordingMethod.toInt(): 0 unknown, 1 active, 2 automatic, 3 manual. Reads report the
        // record's recording method as is, so a record reads back with the method it was written with.
        val expected = listOf(
            Metadata.RECORDING_METHOD_UNKNOWN,
            Metadata.RECORDING_METHOD_ACTIVELY_RECORDED,
            Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED,
            Metadata.RECORDING_METHOD_MANUAL_ENTRY,
        )
        for ((value, recordingMethod) in expected.withIndex()) {
            assertEquals("$value", recordingMethod, buildMetadata(value).recordingMethod)
            assertEquals("$value", recordingMethod, buildMetadata(value, "id", 1).recordingMethod)
        }
    }

    @Test
    fun readsReportAndFilterTheRecordingMethodAWriteWasMadeWith() {
        for (value in 0..3) {
            val record = WeightRecord(Instant.EPOCH, null, Mass.kilograms(70.0), buildMetadata(value))
            val read = HealthDataConverter().convertRecord(record, HealthConstants.WEIGHT).single()
            assertEquals("$value", value, read["recording_method"])
            val filtered = HealthRecordingFilter().filterRecordsByRecordingMethods(listOf(value), listOf(record))
            assertEquals("$value", emptyList<WeightRecord>(), filtered)
        }
    }

    @Test
    fun manualEntriesNameNoDevice() {
        val metadata = buildMetadata(RECORDING_METHOD_MANUAL_ENTRY, deviceType = Device.TYPE_WATCH)
        assertEquals(Metadata.RECORDING_METHOD_MANUAL_ENTRY, metadata.recordingMethod)
        assertNull(metadata.device)
    }

    @Test
    fun recordedDataComesFromADevice() {
        val automatic = buildMetadata(RECORDING_METHOD_AUTOMATICALLY_RECORDED, deviceType = Device.TYPE_WATCH)
        assertEquals(Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED, automatic.recordingMethod)
        assertEquals(Device.TYPE_WATCH, automatic.device?.type)

        val active = buildMetadata(RECORDING_METHOD_ACTIVELY_RECORDED)
        assertEquals(Metadata.RECORDING_METHOD_ACTIVELY_RECORDED, active.recordingMethod)
        assertEquals(Device.TYPE_UNKNOWN, active.device?.type)
    }

    @Test
    fun anyOtherValueIsAnUnknownRecordingMethod() {
        for (value in listOf(0, 4, -1)) {
            val metadata = buildMetadata(value, deviceType = Device.TYPE_WATCH)
            assertEquals(Metadata.RECORDING_METHOD_UNKNOWN, metadata.recordingMethod)
            assertNull(metadata.device)
        }
    }

    @Test
    fun theClientRecordIdIsOnlySetWithItsVersion() {
        val metadata = buildMetadata(RECORDING_METHOD_AUTOMATICALLY_RECORDED, clientRecordId = "id", clientRecordVersion = 2)
        assertEquals("id", metadata.clientRecordId)
        assertEquals(2L, metadata.clientRecordVersion)

        assertNull(buildMetadata(RECORDING_METHOD_MANUAL_ENTRY, clientRecordId = "id").clientRecordId)
        assertNull(buildMetadata(RECORDING_METHOD_MANUAL_ENTRY, clientRecordVersion = 2).clientRecordId)
    }
}
