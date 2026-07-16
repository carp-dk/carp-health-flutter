package cachet.plugins.health

import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class HealthConnectOperationTest {
    @Test
    fun mapsKnownServiceConnectionFailures() {
        assertEquals(
                "health_connect_bind_failed",
                healthConnectErrorCode(RuntimeException("Binding to service failed")),
        )
        assertEquals(
                "health_connect_binder_died",
                healthConnectErrorCode(RuntimeException("Binder died")),
        )
        assertEquals(
                "health_connect_binding_died",
                healthConnectErrorCode(RuntimeException("Binding died")),
        )
        assertEquals(
                "health_connect_null_binding",
                healthConnectErrorCode(RuntimeException("Null binding")),
        )
        assertEquals(
                "health_connect_binder_died",
                healthConnectErrorCode(RuntimeException("wrapper", IOException("Binder died"))),
        )
    }

    @Test
    fun mapsExpectedHealthConnectFailures() {
        assertEquals("health_connect_security_error", healthConnectErrorCode(SecurityException()))
        assertEquals("health_connect_io_error", healthConnectErrorCode(IOException()))
        assertEquals(
                "health_connect_cancelled",
                healthConnectErrorCode(CancellationException()),
        )
        assertEquals(
                "health_connect_invalid_argument",
                healthConnectErrorCode(IllegalArgumentException()),
        )
        assertEquals(
                "health_connect_invalid_state",
                healthConnectErrorCode(IllegalStateException()),
        )
        assertEquals(
                "health_connect_unsupported",
                healthConnectErrorCode(UnsupportedOperationException()),
        )
        assertEquals(
                "health_connect_unknown_error",
                healthConnectErrorCode(RuntimeException()),
        )
    }

    @Test
    fun guardedResultCompletesOnlyOnce() {
        val delegate = RecordingResult()
        val result = GuardedResult(delegate, "hasPermissions")

        result.success(true)
        result.error("late_error", "ignored", null)

        assertEquals(true, delegate.successValue)
        assertNull(delegate.errorCode)
        assertEquals(1, delegate.completionCount)
    }

    @Test
    fun coroutineFailureCompletesWithStableError() = runBlocking {
        val result = RecordingResult()

        val job =
                CoroutineScope(coroutineContext).launchHealthConnectOperation(
                        "hasPermissions",
                        result,
                ) {
                    throw RuntimeException("Binder died")
                }
        job.join()

        assertEquals("health_connect_binder_died", result.errorCode)
        assertEquals(1, result.completionCount)
    }

    private class RecordingResult : Result {
        var successValue: Any? = null
        var errorCode: String? = null
        var completionCount = 0

        override fun success(result: Any?) {
            successValue = result
            completionCount++
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            this.errorCode = errorCode
            completionCount++
        }

        override fun notImplemented() {
            completionCount++
        }
    }
}
