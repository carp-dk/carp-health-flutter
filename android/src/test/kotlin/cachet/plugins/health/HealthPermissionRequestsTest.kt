package cachet.plugins.health

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HealthPermissionRequestsTest {
    // Flutter's default FlutterActivity extends Activity, not ComponentActivity.
    private val activity = Activity()
    private val requests = HealthPermissionRequests({ activity }, { error("unused") })

    private val requestSteps = MethodCall(
        "requestAuthorization",
        hashMapOf("types" to arrayListOf(HealthConstants.STEPS), "permissions" to arrayListOf(0)),
    )

    @Test
    fun anActivityThatIsNotAComponentActivityGetsNoLauncherAndRequestsReplyFalse() {
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
}
