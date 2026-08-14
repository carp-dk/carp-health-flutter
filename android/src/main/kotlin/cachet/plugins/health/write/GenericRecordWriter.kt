package cachet.plugins.health.write

import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.requests.GenericWriteRequest
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Writes scalar Flutter health values as Health Connect records.
 */
class GenericRecordWriter(
    private val executor: HealthConnectWriteExecutor,
    private val metadataFactory: HealthMetadataFactory,
    private val recordFactory: GenericRecordFactory = GenericRecordFactory(),
) {
    /** Inserts the Health Connect record represented by a generic write request. */
    fun write(request: GenericWriteRequest, result: Result) {
        val metadata = metadataFactory.create(
            recordingMethod = request.metadata.recordingMethod,
            clientRecordId = request.metadata.clientRecordId,
            clientRecordVersion = request.metadata.clientRecordVersion,
            deviceType = request.metadata.deviceType,
        )
        val record = recordFactory.create(request, metadata)
        if (record == null) {
            result.error(
                "WRITE_DATA_ERROR",
                "Error writing ${request.dataTypeKey}",
                "Unsupported data type",
            )
            return
        }
        executor.insert(
            records = listOf(record),
            result = result,
            failureCode = "WRITE_DATA_ERROR",
            failureMessage = "Error writing ${request.dataTypeKey}",
        )
    }
}
