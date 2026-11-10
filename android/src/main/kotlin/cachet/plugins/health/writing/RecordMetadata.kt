package cachet.plugins.health.writing

import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import io.flutter.plugin.common.MethodCall

// The 'recordingMethod' argument is RecordingMethod.toInt(), which uses Health Connect's values, as
// reads report them: 1 actively recorded, 2 automatically recorded, 3 manual entry, and any other
// value (0 is sent for unknown) an unknown recording method.
internal const val RECORDING_METHOD_ACTIVELY_RECORDED = Metadata.RECORDING_METHOD_ACTIVELY_RECORDED
internal const val RECORDING_METHOD_AUTOMATICALLY_RECORDED = Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED
internal const val RECORDING_METHOD_MANUAL_ENTRY = Metadata.RECORDING_METHOD_MANUAL_ENTRY

/**
 * The metadata of a record written with [recordingMethod]. Automatically and actively recorded
 * records come from a device of [deviceType] (unknown if null), as Health Connect requires a device
 * for them; manual and unknown ones name no device. The client record id is only set together with
 * its version.
 */
internal fun buildMetadata(
    recordingMethod: Int,
    clientRecordId: String? = null,
    clientRecordVersion: Long? = null,
    deviceType: Int? = null,
): Metadata {
    val device = Device(type = deviceType ?: Device.TYPE_UNKNOWN)
    if (clientRecordId == null || clientRecordVersion == null) {
        return when (recordingMethod) {
            RECORDING_METHOD_MANUAL_ENTRY -> Metadata.manualEntry()
            RECORDING_METHOD_AUTOMATICALLY_RECORDED -> Metadata.autoRecorded(device)
            RECORDING_METHOD_ACTIVELY_RECORDED -> Metadata.activelyRecorded(device)
            else -> Metadata.unknownRecordingMethod()
        }
    }
    return when (recordingMethod) {
        RECORDING_METHOD_MANUAL_ENTRY -> Metadata.manualEntry(
            device = null, clientRecordId = clientRecordId, clientRecordVersion = clientRecordVersion,
        )
        RECORDING_METHOD_AUTOMATICALLY_RECORDED -> Metadata.autoRecorded(
            device = device, clientRecordId = clientRecordId, clientRecordVersion = clientRecordVersion,
        )
        RECORDING_METHOD_ACTIVELY_RECORDED -> Metadata.activelyRecorded(
            device = device, clientRecordId = clientRecordId, clientRecordVersion = clientRecordVersion,
        )
        else -> Metadata.unknownRecordingMethod(
            device = null, clientRecordId = clientRecordId, clientRecordVersion = clientRecordVersion,
        )
    }
}

/**
 * The metadata of a record written with [recordingMethod], from the 'clientRecordId',
 * 'clientRecordVersion' and 'deviceType' arguments of this call (read in that order).
 */
internal fun MethodCall.recordMetadata(recordingMethod: Int): Metadata {
    val clientRecordId: String? = argument("clientRecordId")
    val clientRecordVersion: Double? = argument<Double>("clientRecordVersion")
    val deviceType: Int? = argument<Int>("deviceType")
    return buildMetadata(recordingMethod, clientRecordId, clientRecordVersion?.toLong(), deviceType)
}
