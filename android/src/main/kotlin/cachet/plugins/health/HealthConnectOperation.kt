package cachet.plugins.health

import android.os.DeadObjectException
import android.os.RemoteException
import android.util.Log
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Guarantees that a method-channel call is completed at most once.
 *
 * Health Connect callbacks can race with activity/engine detachment and Binder death. Flutter
 * rejects duplicate replies, so all native handlers receive this wrapper at the dispatch boundary.
 */
internal class GuardedResult(
        private val delegate: Result,
        private val operation: String,
) : Result {
    private val completed = AtomicBoolean(false)

    override fun success(result: Any?) = complete { delegate.success(result) }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) =
            complete { delegate.error(errorCode, errorMessage, errorDetails) }

    override fun notImplemented() = complete { delegate.notImplemented() }

    private inline fun complete(reply: () -> Unit) {
        if (completed.compareAndSet(false, true)) {
            try {
                reply()
            } catch (exception: Exception) {
                Log.w(TAG, "Unable to deliver result for $operation", exception)
            }
        } else {
            Log.w(TAG, "Ignoring duplicate result for $operation")
        }
    }

    private companion object {
        const val TAG = "FLUTTER_HEALTH"
    }
}

/** Runs one suspending Health Connect operation and converts every expected failure to Flutter. */
internal fun CoroutineScope.launchHealthConnectOperation(
        operation: String,
        result: Result,
        block: suspend () -> Any?,
): Job =
        launch {
            try {
                result.success(block())
            } catch (exception: CancellationException) {
                result.failHealthConnect(operation, exception)
            } catch (exception: Exception) {
                result.failHealthConnect(operation, exception)
            }
        }

/** Maps native failures to stable, non-sensitive method-channel errors. */
internal fun Result.failHealthConnect(operation: String, exception: Throwable) {
    val errorCode = healthConnectErrorCode(exception)
    Log.e(TAG, "$operation failed ($errorCode)", exception)
    error(
            errorCode,
            exception.message ?: exception.javaClass.simpleName,
            mapOf(
                    "operation" to operation,
                    "exception" to exception.javaClass.name,
            ),
    )
}

internal fun healthConnectErrorCode(exception: Throwable): String {
    val causes = generateSequence(exception) { it.cause }.take(10).toList()
    val message = causes.joinToString(" ") { it.message.orEmpty() }.lowercase()
    return when {
        causes.any { it is DeadObjectException } || "binder died" in message ->
                "health_connect_binder_died"
        "binding died" in message -> "health_connect_binding_died"
        "null binding" in message -> "health_connect_null_binding"
        "binding to service failed" in message -> "health_connect_bind_failed"
        causes.any { it is RemoteException } -> "health_connect_remote_error"
        causes.any { it is SecurityException } -> "health_connect_security_error"
        causes.any { it is IOException } -> "health_connect_io_error"
        causes.any { it is CancellationException } -> "health_connect_cancelled"
        causes.any { it is IllegalArgumentException } -> "health_connect_invalid_argument"
        causes.any { it is IllegalStateException } -> "health_connect_invalid_state"
        causes.any { it is UnsupportedOperationException } -> "health_connect_unsupported"
        else -> "health_connect_unknown_error"
    }
}

private const val TAG = "FLUTTER_HEALTH"
