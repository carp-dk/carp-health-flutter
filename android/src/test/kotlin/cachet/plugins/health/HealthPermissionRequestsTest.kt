package cachet.plugins.health

import android.app.Activity
import android.content.ActivityNotFoundException
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.arch.core.executor.ArchTaskExecutor
import androidx.arch.core.executor.TaskExecutor
import androidx.core.app.ActivityOptionsCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.savedstate.SavedStateRegistryController
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
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
    fun aComponentActivityThatHasStartedGetsNoLauncherAndRequestsReplyFalse() = onMainThread {
        val created = componentActivity(Lifecycle.State.CREATED)
        val requests = HealthPermissionRequests({ created }, { error("unused") })
        requests.registerLauncher(created)
        assertNotNull(requests.healthConnectRequestPermissionsLauncher)

        // As when a FlutterFragment with a cached engine is added to a running activity.
        val resumed = componentActivity(Lifecycle.State.RESUMED)
        // Used to throw IllegalStateException out of onAttachedToActivity, which crashed the app.
        requests.registerLauncher(resumed)
        assertNull(requests.healthConnectRequestPermissionsLauncher)
        val result = RecordingResult()
        requests.requestAuthorization(requestSteps, result)
        assertEquals(1, result.replies)
        assertEquals(false, result.value)
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

    /**
     * A ComponentActivity whose lifecycle is at [state]. ON_CREATE needs the saved state that
     * onCreate restores first, and onCreate itself needs more of Android than the JVM tests have.
     * The private field that holds the saved state is found by its type, as its name changed in
     * androidx.activity 1.9.
     */
    private fun componentActivity(state: Lifecycle.State): ComponentActivity {
        val activity = ActivityWithoutApplication()
        val savedState = ComponentActivity::class.java.declaredFields
            .single { it.type == SavedStateRegistryController::class.java }
        savedState.isAccessible = true
        (savedState.get(activity) as SavedStateRegistryController).performRestore(null)
        (activity.lifecycle as LifecycleRegistry).currentState = state
        return activity
    }

    /**
     * A ComponentActivity whose view models need no Application, which the activities of the JVM
     * tests do not have: ON_CREATE restores the saved state handles, which are a view model.
     */
    private class ActivityWithoutApplication : ComponentActivity() {
        private val store = ViewModelStore()
        override val viewModelStore: ViewModelStore get() = store
    }

    /** Runs [test] with the lifecycle library taking this thread for the main thread, as it checks. */
    private fun onMainThread(test: () -> Unit) {
        ArchTaskExecutor.getInstance().setDelegate(object : TaskExecutor() {
            override fun executeOnDiskIO(runnable: Runnable) = runnable.run()
            override fun postToMainThread(runnable: Runnable) = runnable.run()
            override fun isMainThread() = true
        })
        try {
            test()
        } finally {
            ArchTaskExecutor.getInstance().setDelegate(null)
        }
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
