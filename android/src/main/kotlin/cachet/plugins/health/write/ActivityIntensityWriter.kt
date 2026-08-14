package cachet.plugins.health.write

import androidx.health.connect.client.records.ActivityIntensityRecord
import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.requests.ActivityIntensityWriteRequest
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant

/**
 * Writes activity intensity records to Health Connect.
 */
class ActivityIntensityWriter(
    private val executor: HealthConnectWriteExecutor,
    private val metadataFactory: HealthMetadataFactory,
) {
    /** Inserts an activity intensity record. */
    fun write(request: ActivityIntensityWriteRequest, result: Result) {
        val metadata = metadataFactory.create(
            recordingMethod = request.metadata.recordingMethod,
            clientRecordId = request.metadata.clientRecordId,
            clientRecordVersion = request.metadata.clientRecordVersion,
            deviceType = request.metadata.deviceType,
        )
        val record = ActivityIntensityRecord(
            startTime = Instant.ofEpochMilli(request.startTime),
            startZoneOffset = null,
            endTime = Instant.ofEpochMilli(request.endTime),
            endZoneOffset = null,
            activityIntensityType = request.intensityType,
            metadata = metadata,
        )
        executor.insert(
            records = listOf(record),
            result = result,
            failureCode = "WRITE_ACTIVITY_INTENSITY_ERROR",
            failureMessage = "[Health Connect] There was an error adding the activity intensity record",
        )
    }
}
