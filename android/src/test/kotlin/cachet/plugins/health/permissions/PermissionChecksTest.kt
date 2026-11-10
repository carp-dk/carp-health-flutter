package cachet.plugins.health.permissions

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.RecordingResult
import cachet.plugins.health.fakeOf
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PermissionChecksTest {
    // Exceptions that escaped the coroutine of a check, which would crash the app. The checks run at
    // once, as the fakes answer without suspending.
    private val escaped = mutableListOf<Throwable>()
    private val scope = CoroutineScope(Dispatchers.Unconfined + CoroutineExceptionHandler { _, e -> escaped.add(e) })

    private val readSteps = HealthPermission.getReadPermission(StepsRecord::class)

    private fun client(permissions: PermissionController, features: HealthConnectFeatures) =
        fakeOf<HealthConnectClient> { method ->
            when (method) {
                "getPermissionController" -> permissions
                "getFeatures" -> features
                else -> throw UnsupportedOperationException(method)
            }
        }

    private fun hasPermissions(access: Int) = MethodCall(
        "hasPermissions",
        hashMapOf("types" to arrayListOf(HealthConstants.STEPS), "permissions" to arrayListOf(access)),
    )

    /** Each check of the plugin, replying to the result it is given. */
    private fun checks(client: HealthConnectClient): Map<String, (RecordingResult) -> Unit> {
        val permissions = GrantedPermissions(client, scope)
        val features = FeatureAvailability(client, scope)
        return mapOf(
            "hasPermissions" to { result: RecordingResult -> permissions.hasPermissions(hasPermissions(0), result) },
            "isHealthDataHistoryAuthorized" to permissions::isHealthDataHistoryAuthorized,
            "isHealthDataInBackgroundAuthorized" to permissions::isHealthDataInBackgroundAuthorized,
            "revokePermissions" to permissions::revokePermissions,
            "isHealthDataHistoryAvailable" to features::isHealthDataHistoryAvailable,
            "isHealthDataInBackgroundAvailable" to features::isHealthDataInBackgroundAvailable,
            "isSkinTemperatureAvailable" to features::isSkinTemperatureAvailable,
        )
    }

    @Test
    fun aCheckThatHealthConnectFailsRepliesTheError() {
        val failing = IllegalStateException("Health Connect is unavailable")
        for ((name, check) in checks(client(fakeOf { throw failing }, fakeOf { throw failing }))) {
            val result = RecordingResult()
            check(result)
            assertEquals(name, 1, result.replies)
            assertEquals(name, HealthErrors.HEALTH_ERROR, result.code)
            assertEquals(name, "Health Connect is unavailable", result.message)
        }
        assertEquals(emptyList<Throwable>(), escaped)
    }

    @Test
    fun checksReplyHealthConnectsAnswer() {
        val permissions = fakeOf<PermissionController> { method ->
            if (method == "getGrantedPermissions") setOf(readSteps) else Unit
        }
        val features = fakeOf<HealthConnectFeatures> { HealthConnectFeatures.FEATURE_STATUS_AVAILABLE }
        val replies = checks(client(permissions, features)).mapValues { (name, check) ->
            val result = RecordingResult()
            check(result)
            assertEquals(name, 1, result.replies)
            assertNull(name, result.code)
            result.value
        }
        assertEquals(
            mapOf(
                "hasPermissions" to true,
                "isHealthDataHistoryAuthorized" to false,
                "isHealthDataInBackgroundAuthorized" to false,
                "revokePermissions" to true,
                "isHealthDataHistoryAvailable" to true,
                "isHealthDataInBackgroundAvailable" to true,
                "isSkinTemperatureAvailable" to true,
            ),
            replies,
        )
        val writeSteps = RecordingResult()
        GrantedPermissions(client(permissions, features), scope).hasPermissions(hasPermissions(1), writeSteps)
        assertEquals(false, writeSteps.value)
    }
}
