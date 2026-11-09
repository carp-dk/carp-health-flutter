package cachet.plugins.health.permissions

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Answers whether Health Connect features are available on the device, for
 * isHealthDataHistoryAvailable, isHealthDataInBackgroundAvailable and isSkinTemperatureAvailable.
 */
internal class FeatureAvailability(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun isHealthDataHistoryAvailable(result: Result) {
        replyAvailable(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY, result)
    }

    fun isHealthDataInBackgroundAvailable(result: Result) {
        replyAvailable(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND, result)
    }

    fun isSkinTemperatureAvailable(result: Result) {
        replyAvailable(HealthConnectFeatures.FEATURE_SKIN_TEMPERATURE, result)
    }

    /** Replies whether [feature], a HealthConnectFeatures.FEATURE_* value, is available. */
    private fun replyAvailable(feature: Int, result: Result) {
        scope.launch {
            result.success(
                healthConnectClient.features.getFeatureStatus(feature) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE,
            )
        }
    }
}
