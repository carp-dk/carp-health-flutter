package cachet.plugins.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures

/**
 * Availability of Health Connect record types that are gated by the version of the Health Connect
 * implementation *installed on the device*, rather than by the version of `connect-client` this
 * plugin is compiled against.
 *
 * A record can therefore be perfectly resolvable at compile time and still be rejected at runtime.
 * The helpers here let the plugin answer "not supported here" instead of surfacing the platform
 * exception that such a call would otherwise raise.
 */
object HealthFeatures {

    /**
     * Whether this device's Health Connect knows the mindfulness session record.
     *
     * `MindfulnessSessionRecord` was added to Health Connect after the initial release, so on an
     * older Health Connect the record type is unknown and reading, writing, or even requesting its
     * permissions fails. Guarding on this keeps those paths to a clean negative result.
     *
     * @param client The Health Connect client to interrogate
     * @return Boolean True when mindfulness sessions can be used on this device
     */
    fun isMindfulnessSessionAvailable(client: HealthConnectClient): Boolean =
            client.features.getFeatureStatus(
                    HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION
            ) == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE

    /** Log message shared by every call that had to bail out on an unsupported device. */
    internal const val MINDFULNESS_UNSUPPORTED_MESSAGE =
            "[Health Connect] Mindfulness sessions are not supported by the version of " +
                    "Health Connect installed on this device"
}
