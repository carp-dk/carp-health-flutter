package cachet.plugins.health.write

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.Record
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Executes Health Connect write calls and reports results to Flutter.
 */
class HealthConnectWriteExecutor(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    /** Inserts Health Connect records and returns inserted record IDs. */
    fun insert(
        records: List<Record>,
        result: Result,
        failureCode: String,
        failureMessage: String,
    ) {
        scope.launch {
            try {
                val response = healthConnectClient.insertRecords(records)
                result.success(response.recordIdsList)
            } catch (e: Exception) {
                Log.e(LOG_TAG, "$failureMessage: ${e.message}")
                result.error(failureCode, failureMessage, errorDetails(e))
            }
        }
    }

    /** Updates Health Connect records and returns the supplied success payload. */
    fun update(
        records: List<Record>,
        onSuccess: () -> Any?,
        result: Result,
        failureCode: String,
        failureMessage: String,
    ) {
        scope.launch {
            try {
                healthConnectClient.updateRecords(records)
                result.success(onSuccess())
            } catch (e: Exception) {
                Log.e(LOG_TAG, "$failureMessage: ${e.message}")
                result.error(failureCode, failureMessage, errorDetails(e))
            }
        }
    }

    private fun errorDetails(e: Exception) = mapOf(
        "message" to (e.message ?: "unknown error"),
        "stackTrace" to e.stackTraceToString(),
    )

    companion object {
        private const val LOG_TAG = "FLUTTER_HEALTH::ERROR"
    }
}
