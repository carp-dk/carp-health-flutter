package cachet.plugins.health.write

import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.units.Velocity
import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.requests.SpeedWriteRequest
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant

/**
 * Writes speed records to Health Connect.
 */
class SpeedWriter(
    private val executor: HealthConnectWriteExecutor,
    private val metadataFactory: HealthMetadataFactory,
) {
    /** Inserts a sampled speed record. */
    fun write(request: SpeedWriteRequest, result: Result) {
        val metadata = metadataFactory.create(
            recordingMethod = request.metadata.recordingMethod,
            clientRecordId = request.metadata.clientRecordId,
            clientRecordVersion = request.metadata.clientRecordVersion,
            deviceType = request.metadata.deviceType,
        )
        val record = SpeedRecord(
            startTime = Instant.ofEpochMilli(request.startTime),
            endTime = Instant.ofEpochMilli(request.endTime),
            samples = request.samples.map {
                SpeedRecord.Sample(
                    time = Instant.ofEpochMilli(it.time),
                    speed = Velocity.metersPerSecond(it.speed),
                )
            },
            startZoneOffset = null,
            endZoneOffset = null,
            metadata = metadata,
        )
        executor.insert(
            records = listOf(record),
            result = result,
            failureCode = "WRITE_SPEED_DATA_ERROR",
            failureMessage = "Error writing speed data",
        )
    }
}
