package cachet.plugins.health

import android.health.connect.HealthConnectException
import android.os.RemoteException
import cachet.plugins.health.HealthErrors.DATA_TOO_LARGE
import cachet.plugins.health.HealthErrors.HEALTH_ERROR
import cachet.plugins.health.HealthErrors.INVALID_ARGUMENT
import cachet.plugins.health.HealthErrors.NOT_SUPPORTED
import cachet.plugins.health.HealthErrors.PERMISSION_DENIED
import cachet.plugins.health.HealthErrors.RATE_LIMIT_EXCEEDED
import cachet.plugins.health.HealthErrors.UNAVAILABLE
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import kotlinx.coroutines.CancellationException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class HealthErrorsTest {
    private fun codeFor(error: Throwable, healthConnectErrorCode: Int? = null) =
        HealthErrors.codeFor(error, healthConnectErrorCode)

    @Test
    fun tooManyRecordsInTheCursorIsDataTooLargeAlthoughReportedAsInvalidArgument() {
        // androidx wraps HealthConnectException(ERROR_INVALID_ARGUMENT) in an IllegalArgumentException.
        val error = IllegalArgumentException(
            IllegalStateException("Too many records in the cursor. Max allowed: 100000")
        )
        assertEquals(DATA_TOO_LARGE, codeFor(error, HealthConnectException.ERROR_INVALID_ARGUMENT))
        assertEquals(DATA_TOO_LARGE, codeFor(error))
        assertEquals(DATA_TOO_LARGE, codeFor(IllegalArgumentException("Too many records in the cursor")))
    }

    @Test
    fun outOfMemoryAnywhereInTheChainIsDataTooLarge() {
        assertEquals(DATA_TOO_LARGE, codeFor(OutOfMemoryError()))
        assertEquals(
            DATA_TOO_LARGE,
            codeFor(
                IllegalStateException(OutOfMemoryError("Failed to allocate")),
                HealthConnectException.ERROR_INTERNAL,
            ),
        )
    }

    @Test
    fun healthConnectErrorCodeWinsOverClassAndMessage() {
        // A rate limit arrives as IllegalStateException(HealthConnectException(ERROR_RATE_LIMIT_EXCEEDED)).
        val rateLimit = IllegalStateException(RuntimeException("API call quota exceeded"))
        assertEquals(RATE_LIMIT_EXCEEDED, codeFor(rateLimit, HealthConnectException.ERROR_RATE_LIMIT_EXCEEDED))
        assertEquals(HEALTH_ERROR, codeFor(IllegalStateException("rate limit"), HealthConnectException.ERROR_INTERNAL))
        assertEquals(INVALID_ARGUMENT, codeFor(SecurityException(), HealthConnectException.ERROR_INVALID_ARGUMENT))
        assertEquals(
            NOT_SUPPORTED,
            codeFor(IllegalStateException(), HealthConnectException.ERROR_UNSUPPORTED_OPERATION),
        )
    }

    @Test
    fun quotaMessagesWithoutHealthConnectErrorCodeAreRateLimits() {
        // The Health Connect APK (Android 13 and lower) only says so in the message.
        val apk = IllegalStateException("Request rejected. Rate limited request quota has been exceeded.")
        assertEquals(RATE_LIMIT_EXCEEDED, codeFor(apk))
        // Anywhere in the chain, in any case, before the class fallbacks.
        val inChain = SecurityException(IOException("API call QUOTA EXCEEDED, availableQuota: 0"))
        assertEquals(RATE_LIMIT_EXCEEDED, codeFor(inChain))
    }

    @Test
    fun exceptionClassesWithoutHealthConnectErrorCode() {
        val expected = listOf(
            SecurityException("Caller doesn't have android.permission.health.READ_HEART_RATE") to PERMISSION_DENIED,
            IllegalArgumentException("end time needs be after start time") to INVALID_ARGUMENT,
            NumberFormatException("For input string: \"abc\"") to INVALID_ARGUMENT,
            UnsupportedOperationException() to NOT_SUPPORTED,
            RemoteException() to UNAVAILABLE,
            IOException() to UNAVAILABLE,
            IllegalStateException("Service not bound") to HEALTH_ERROR,
            RuntimeException() to HEALTH_ERROR,
            NullPointerException() to HEALTH_ERROR,
            ClassCastException() to HEALTH_ERROR,
        )
        for ((error, code) in expected) {
            assertEquals(error.toString(), code, codeFor(error))
        }
    }

    @Test
    fun healthConnectErrorCodes() {
        val expected = mapOf(
            HealthConnectException.ERROR_UNKNOWN to HEALTH_ERROR,
            HealthConnectException.ERROR_INTERNAL to HEALTH_ERROR,
            HealthConnectException.ERROR_INVALID_ARGUMENT to INVALID_ARGUMENT,
            HealthConnectException.ERROR_IO to UNAVAILABLE,
            HealthConnectException.ERROR_SECURITY to PERMISSION_DENIED,
            HealthConnectException.ERROR_REMOTE to UNAVAILABLE,
            HealthConnectException.ERROR_RATE_LIMIT_EXCEEDED to RATE_LIMIT_EXCEEDED,
            HealthConnectException.ERROR_DATA_SYNC_IN_PROGRESS to UNAVAILABLE,
            HealthConnectException.ERROR_UNSUPPORTED_OPERATION to NOT_SUPPORTED,
        )
        // The platform constants are 1 to 9.
        assertEquals((1..9).toList(), expected.keys.sorted())
        for ((healthConnectErrorCode, code) in expected) {
            val actual = HealthErrors.codeForHealthConnectErrorCode(healthConnectErrorCode)
            assertEquals("$healthConnectErrorCode", code, actual)
        }
        for (unknown in listOf(0, 10, -1)) {
            assertEquals(HEALTH_ERROR, HealthErrors.codeForHealthConnectErrorCode(unknown))
        }
    }

    @Test
    fun dataTooLargeIsOutOfMemoryOrTooManyRecords() {
        assertTrue(HealthErrors.isDataTooLarge(OutOfMemoryError()))
        val tooMany = IllegalArgumentException(IllegalStateException("Too many records in the cursor"))
        assertTrue(HealthErrors.isDataTooLarge(tooMany))
        assertFalse(HealthErrors.isDataTooLarge(IllegalArgumentException("Valid pageSize range is 1 - 5000")))
        assertFalse(HealthErrors.isDataTooLarge(SecurityException()))
    }

    @Test
    fun cyclicCauseChainsEnd() {
        val first = IllegalStateException("first")
        val second = IllegalStateException("second", first)
        first.initCause(second)
        assertEquals(HEALTH_ERROR, codeFor(first))
    }

    @Test
    fun reportRepliesWithCodeMessageAndDetails() {
        val result = RecordingResult()
        HealthErrors.report(result, SecurityException("Caller doesn't have permission"), "test")
        assertEquals(1, result.replies)
        assertEquals(PERMISSION_DENIED, result.code)
        assertEquals("Caller doesn't have permission", result.message)
        assertEquals(
            mapOf("exception" to "java.lang.SecurityException", "healthConnectErrorCode" to null),
            result.details,
        )
    }

    @Test
    fun reportUsesTheExceptionAsMessageWhenItHasNone() {
        val result = RecordingResult()
        HealthErrors.report(result, UnsupportedOperationException(), "test")
        assertEquals(NOT_SUPPORTED, result.code)
        assertEquals("java.lang.UnsupportedOperationException", result.message)
    }

    @Test
    fun reportRethrowsCancellationWithoutReplying() {
        val result = RecordingResult()
        assertThrows(CancellationException::class.java) {
            HealthErrors.report(result, CancellationException("detached"), "test")
        }
        assertEquals(0, result.replies)
    }
}

/** Records the reply a method call handler sends. */
internal class RecordingResult : MethodChannel.Result {
    var replies = 0
    var value: Any? = null
    var code: String? = null
    var message: String? = null
    var details: Any? = null

    override fun success(result: Any?) {
        replies++
        value = result
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        replies++
        code = errorCode
        message = errorMessage
        details = errorDetails
    }

    override fun notImplemented() {
        replies++
    }
}
