package cachet.plugins.health.write

import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.units.Pressure
import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.requests.BloodPressureWriteRequest
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant

/**
 * Writes blood pressure records to Health Connect.
 */
class BloodPressureWriter(
    private val executor: HealthConnectWriteExecutor,
    private val metadataFactory: HealthMetadataFactory,
) {
    /** Inserts a blood pressure record. */
    fun write(request: BloodPressureWriteRequest, result: Result) {
        val metadata = metadataFactory.create(
            recordingMethod = request.metadata.recordingMethod,
            clientRecordId = request.metadata.clientRecordId,
            clientRecordVersion = request.metadata.clientRecordVersion,
            deviceType = request.metadata.deviceType,
        )
        val record = BloodPressureRecord(
            time = Instant.ofEpochMilli(request.startTime),
            systolic = Pressure.millimetersOfMercury(request.systolic),
            diastolic = Pressure.millimetersOfMercury(request.diastolic),
            zoneOffset = null,
            metadata = metadata,
        )
        executor.insert(
            records = listOf(record),
            result = result,
            failureCode = "WRITE_BLOOD_PRESSURE_ERROR",
            failureMessage = "[Health Connect] There was an error adding the Blood Pressure",
        )
    }
}
