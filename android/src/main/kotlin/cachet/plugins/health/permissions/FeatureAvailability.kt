package cachet.plugins.health.permissions

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope

/**
 * Answers whether Health Connect features are available on the device, for
 * isHealthDataHistoryAvailable, isHealthDataInBackgroundAvailable, isSkinTemperatureAvailable and
 * isMindfulnessSessionAvailable. A check that fails replies the error ([launchCheck]).
 */
internal class FeatureAvailability(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun isHealthDataHistoryAvailable(result: Result) {
        replyAvailable(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY, "isHealthDataHistoryAvailable", result)
    }

    fun isHealthDataInBackgroundAvailable(result: Result) {
        replyAvailable(
            HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND, "isHealthDataInBackgroundAvailable", result,
        )
    }

    fun isSkinTemperatureAvailable(result: Result) {
        replyAvailable(HealthConnectFeatures.FEATURE_SKIN_TEMPERATURE, "isSkinTemperatureAvailable", result)
    }

    fun isMindfulnessSessionAvailable(result: Result) {
        replyAvailable(HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION, "isMindfulnessSessionAvailable", result)
    }

    /** Replies whether [feature], a HealthConnectFeatures.FEATURE_* value, is available. */
    private fun replyAvailable(feature: Int, operation: String, result: Result) {
        scope.launchCheck(result, operation) {
            healthConnectClient.features.getFeatureStatus(feature) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
        }
    }
}
