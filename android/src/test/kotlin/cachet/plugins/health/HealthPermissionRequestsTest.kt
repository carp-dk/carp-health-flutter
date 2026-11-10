package cachet.plugins.health

import android.app.Activity
import android.content.ActivityNotFoundException
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.core.app.ActivityOptionsCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class HealthPermissionRequestsTest {
    // Flutter's default FlutterActivity extends Activity, not ComponentActivity.
    private val activity = Activity()
    private val launcher = FakeLauncher()
    private val readSteps = HealthPermission.getReadPermission(StepsRecord::class)
    private val readHistory = HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY

    private fun requestAuthorization(types: List<String>, access: List<Int>) = MethodCall(
        "requestAuthorization",
        hashMapOf("types" to ArrayList(types), "permissions" to ArrayList(access)),
    )

    private val requestSteps = requestAuthorization(listOf(HealthConstants.STEPS), listOf(0))

    /** The requests of an app whose activity registered [launcher], as a FlutterFragmentActivity does. */
    private fun requests(): HealthPermissionRequests {
        val client = fakeOf<HealthConnectClient> { method -> throw UnsupportedOperationException(method) }
        val dataOperations = HealthDataOperations(client, CoroutineScope(Dispatchers.Unconfined))
        return HealthPermissionRequests({ activity }, { dataOperations }).also {
            it.healthConnectRequestPermissionsLauncher = launcher
        }
    }

    @Test
    fun anActivityThatIsNotAComponentActivityGetsNoLauncherAndRequestsReplyFalse() {
        val requests = HealthPermissionRequests({ activity }, { error("unused") })
        // Used to throw a ClassCastException, which crashed the app or left the plugin unregistered.
        requests.registerLauncher(activity)

        val requestMethods = mapOf(
            "requestAuthorization" to requests::requestAuthorization,
            "requestHealthDataHistoryAuthorization" to requests::requestHealthDataHistoryAuthorization,
            "requestHealthDataInBackgroundAuthorization" to requests::requestHealthDataInBackgroundAuthorization,
        )
        for ((name, request) in requestMethods) {
            val result = RecordingResult()
            request(requestSteps, result)
            assertEquals(name, 1, result.replies)
            assertEquals(name, false, result.value)
            assertNull(name, result.code)
        }
        assertNull(requests.mResult)
    }

    @Test
    fun aRequestMadeWhileTheDialogIsOpenRepliesFalseAndTheFirstGetsTheAnswer() {
        val requests = requests()
        val first = RecordingResult()
        requests.requestAuthorization(requestSteps, first)
        assertEquals(listOf(setOf(readSteps)), launcher.launched)
        assertEquals(0, first.replies)

        // Used to take the first request's place, so the first never got an answer.
        val requestMethods = listOf(
            requests::requestAuthorization,
            requests::requestHealthDataHistoryAuthorization,
            requests::requestHealthDataInBackgroundAuthorization,
        )
        for (request in requestMethods) {
            val result = RecordingResult()
            request(requestSteps, result)
            assertEquals(1, result.replies)
            assertEquals(false, result.value)
        }
        assertEquals(1, launcher.launched.size)

        requests.onHealthConnectPermissionCallback(setOf(readSteps))
        assertEquals(1, first.replies)
        assertEquals(true, first.value)

        // A second result has no request to answer, and the next request opens the dialog again.
        requests.onHealthConnectPermissionCallback(emptySet())
        assertEquals(1, first.replies)
        val next = RecordingResult()
        requests.requestHealthDataHistoryAuthorization(requestSteps, next)
        assertEquals(setOf(readHistory), launcher.launched.last())
        requests.onHealthConnectPermissionCallback(emptySet())
        assertEquals(1, next.replies)
        assertEquals(false, next.value)
    }

    @Test
    fun aRequestAnsweredBeforeTheDialogIsNotLeftWaitingForIt() {
        val requests = requests()
        // A type that Health Connect does not have.
        val unknownType = RecordingResult()
        requests.requestAuthorization(requestAuthorization(listOf("AUDIOGRAM"), listOf(0)), unknownType)
        assertEquals(1, unknownType.replies)
        assertEquals(false, unknownType.value)
        // Malformed arguments throw, and the method channel replies the error.
        val noPermissions = MethodCall("requestAuthorization", hashMapOf("types" to arrayListOf(HealthConstants.STEPS)))
        assertThrows(NullPointerException::class.java) {
            requests.requestAuthorization(noPermissions, RecordingResult())
        }
        assertNull(requests.mResult)
        assertEquals(emptyList<Set<String>>(), launcher.launched)

        // A late dialog result does not answer them a second time, and the next request opens the dialog.
        requests.onHealthConnectPermissionCallback(setOf(readSteps))
        assertEquals(1, unknownType.replies)
        requests.requestAuthorization(requestSteps, RecordingResult())
        assertEquals(listOf(setOf(readSteps)), launcher.launched)
    }

    @Test
    fun aDialogThatCannotBeLaunchedRepliesTheErrorAndLeavesNoRequestWaiting() {
        val requests = requests()
        // As when the Health Connect app (Android 13 and lower) is missing.
        launcher.failure = ActivityNotFoundException("No Activity found to handle Intent")
        val failed = RecordingResult()
        requests.requestHealthDataHistoryAuthorization(requestSteps, failed)
        assertEquals(1, failed.replies)
        assertEquals(HealthErrors.HEALTH_ERROR, failed.code)
        assertNull(requests.mResult)

        launcher.failure = null
        val next = RecordingResult()
        requests.requestHealthDataHistoryAuthorization(requestSteps, next)
        assertEquals(0, next.replies)
        assertEquals(listOf(setOf(readHistory)), launcher.launched)
    }

    @Test
    fun aReplyThatThrowsLeavesNoRequestWaiting() {
        val requests = requests()
        // Flutter's reply throws for a result that was answered already.
        val submitted = object : MethodChannel.Result {
            override fun success(result: Any?) = throw IllegalStateException("Reply already submitted")
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit
            override fun notImplemented() = Unit
        }
        requests.requestAuthorization(requestSteps, submitted)
        assertThrows(IllegalStateException::class.java) {
            requests.onHealthConnectPermissionCallback(setOf(readSteps))
        }
        assertNull(requests.mResult)
    }

    /** The launcher of the permission dialog, which records the permissions it is launched with. */
    private class FakeLauncher : ActivityResultLauncher<Set<String>>() {
        val launched = mutableListOf<Set<String>>()
        var failure: RuntimeException? = null

        override fun launch(input: Set<String>, options: ActivityOptionsCompat?) {
            failure?.let { throw it }
            launched.add(input)
        }

        override fun unregister() = Unit

        override fun getContract(): ActivityResultContract<Set<String>, *> = throw UnsupportedOperationException()
    }
}
