package cachet.plugins.health.writing

import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RecordMetadataTest {
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
