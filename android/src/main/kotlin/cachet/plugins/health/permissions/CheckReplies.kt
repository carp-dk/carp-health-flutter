package cachet.plugins.health.permissions

import cachet.plugins.health.HealthErrors
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Runs [check] on this scope and replies its answer, or what it throws through HealthErrors.report
 * for [operation]. Health Connect can throw (e.g. when its service is unavailable), and an exception
 * that escaped the coroutine would leave the call without a reply and crash the app.
 */
internal fun CoroutineScope.launchCheck(result: Result, operation: String, check: suspend () -> Any?) {
    launch {
        try {
            result.success(check())
        } catch (e: Throwable) {
            HealthErrors.report(result, e, operation)
        }
    }
}
