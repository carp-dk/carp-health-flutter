package cachet.plugins.health

import android.health.connect.HealthConnectException
import android.os.Build
import android.os.RemoteException
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import kotlinx.coroutines.CancellationException

/**
 * Maps failures from Health Connect to method channel error codes, so the Dart side can tell
 * "there is no data" apart from "the read failed" (for example when the API quota is used up).
 * The codes are the ones the iOS side reports for HealthKit errors; Dart turns them into a
 * HealthErrorCode.
 */
object HealthErrors {
    const val RATE_LIMIT_EXCEEDED = "RATE_LIMIT_EXCEEDED"
    const val PERMISSION_DENIED = "PERMISSION_DENIED"
    const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    const val NOT_SUPPORTED = "NOT_SUPPORTED"
    const val UNAVAILABLE = "UNAVAILABLE"
    const val DATA_TOO_LARGE = "DATA_TOO_LARGE"
    const val HEALTH_ERROR = "HEALTH_ERROR"

    // Health Connect's message when a read or a page of changes holds more rows than it returns at once.
    private const val TOO_MANY_RECORDS = "Too many records in the cursor"

    /**
     * Logs [error] once and completes [result] with its code, its message and the details
     * {exception: class name, healthConnectErrorCode: Int?}. Coroutine cancellation (the plugin
     * was detached) is rethrown, as nobody is waiting for a reply.
     */
    fun report(result: Result, error: Throwable, operation: String) {
        if (error is CancellationException) throw error
        val healthConnectErrorCode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) healthConnectErrorCode(error) else null
        val code = codeFor(error, healthConnectErrorCode)
        Log.e("FLUTTER_HEALTH::ERROR", "$operation failed with $code", error)
        result.error(
            code,
            error.message ?: error.toString(),
            mapOf("exception" to error.javaClass.name, "healthConnectErrorCode" to healthConnectErrorCode),
        )
    }

    /** Whether [error] means that the data asked for does not fit in memory or in one Health Connect cursor. */
    internal fun isDataTooLarge(error: Throwable): Boolean = codeFor(error, null) == DATA_TOO_LARGE

    /**
     * The error code for [error]. [healthConnectErrorCode] is the code of the first
     * HealthConnectException in its cause chain (Android 14 and later), or null.
     */
    internal fun codeFor(error: Throwable, healthConnectErrorCode: Int?): String {
        val chain = causes(error)
        return when {
            // Health Connect reports this as an invalid argument, but the request was fine: the data is too big.
            chain.any { it.message?.contains(TOO_MANY_RECORDS) == true } -> DATA_TOO_LARGE
            chain.any { it is OutOfMemoryError } -> DATA_TOO_LARGE
            healthConnectErrorCode != null -> codeForHealthConnectErrorCode(healthConnectErrorCode)
            // The Health Connect APK (Android 13 and lower) only says so in the message.
            chain.any { it.message?.lowercase()?.let { m -> "quota exceeded" in m || "rate limit" in m } == true } ->
                RATE_LIMIT_EXCEEDED
            error is SecurityException -> PERMISSION_DENIED
            // Also NumberFormatException, e.g. from a malformed page token.
            error is IllegalArgumentException -> INVALID_ARGUMENT
            error is UnsupportedOperationException -> NOT_SUPPORTED
            error is RemoteException || error is IOException -> UNAVAILABLE
            else -> HEALTH_ERROR
        }
    }

    /** The error code for a HealthConnectException.ERROR_* value. */
    internal fun codeForHealthConnectErrorCode(code: Int): String = when (code) {
        HealthConnectException.ERROR_RATE_LIMIT_EXCEEDED -> RATE_LIMIT_EXCEEDED
        HealthConnectException.ERROR_SECURITY -> PERMISSION_DENIED
        HealthConnectException.ERROR_INVALID_ARGUMENT -> INVALID_ARGUMENT
        HealthConnectException.ERROR_UNSUPPORTED_OPERATION -> NOT_SUPPORTED
        // A backup or restore in progress is transient, like I/O and remote errors.
        HealthConnectException.ERROR_IO,
        HealthConnectException.ERROR_REMOTE,
        HealthConnectException.ERROR_DATA_SYNC_IN_PROGRESS -> UNAVAILABLE
        else -> HEALTH_ERROR
    }

    /**
     * The client wraps platform errors, e.g. IllegalStateException(HealthConnectException) for a
     * rate limit, so the numeric code is taken from the cause chain.
     */
    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun healthConnectErrorCode(error: Throwable): Int? =
        causes(error).firstNotNullOfOrNull { (it as? HealthConnectException)?.errorCode }

    /** [error] and its causes, at most 10 deep (cause chains can be cyclic). */
    private fun causes(error: Throwable): List<Throwable> {
        val chain = mutableListOf<Throwable>()
        var current: Throwable? = error
        while (current != null && chain.size < 10 && chain.none { it === current }) {
            chain.add(current)
            current = current.cause
        }
        return chain
    }
}
