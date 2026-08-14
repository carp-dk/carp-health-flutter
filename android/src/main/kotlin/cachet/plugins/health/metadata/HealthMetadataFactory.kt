package cachet.plugins.health.metadata

import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata

/**
 * Creates Health Connect metadata from Flutter write arguments.
 */
class HealthMetadataFactory {
    /** Metadata configured with recording method, client record ID, and device type. */
    fun create(
        recordingMethod: Int,
        clientRecordId: String? = null,
        clientRecordVersion: Long? = null,
        deviceType: Int? = null,
    ): Metadata {
        val device = when (recordingMethod) {
            RECORDING_METHOD_AUTOMATIC,
            RECORDING_METHOD_ACTIVE -> Device(type = deviceType ?: Device.TYPE_UNKNOWN)
            else -> null
        }

        return when (recordingMethod) {
            RECORDING_METHOD_MANUAL ->
                withClientRecord(clientRecordId, clientRecordVersion) { id, version ->
                    Metadata.manualEntry(device = null, clientRecordId = id, clientRecordVersion = version)
                } ?: Metadata.manualEntry()
            RECORDING_METHOD_AUTOMATIC ->
                withClientRecord(clientRecordId, clientRecordVersion) { id, version ->
                    Metadata.autoRecorded(device!!, clientRecordId = id, clientRecordVersion = version)
                } ?: Metadata.autoRecorded(device!!)
            RECORDING_METHOD_ACTIVE ->
                withClientRecord(clientRecordId, clientRecordVersion) { id, version ->
                    Metadata.activelyRecorded(device!!, clientRecordId = id, clientRecordVersion = version)
                } ?: Metadata.activelyRecorded(device!!)
            else ->
                withClientRecord(clientRecordId, clientRecordVersion) { id, version ->
                    Metadata.unknownRecordingMethod(
                        device = null,
                        clientRecordId = id,
                        clientRecordVersion = version
                    )
                } ?: Metadata.unknownRecordingMethod()
        }
    }

    private fun withClientRecord(
        id: String?,
        version: Long?,
        build: (String, Long) -> Metadata,
    ): Metadata? = if (id != null && version != null) build(id, version) else null

    companion object {
        const val RECORDING_METHOD_UNKNOWN = 0
        const val RECORDING_METHOD_MANUAL = 1
        const val RECORDING_METHOD_AUTOMATIC = 2
        const val RECORDING_METHOD_ACTIVE = 3
    }
}
