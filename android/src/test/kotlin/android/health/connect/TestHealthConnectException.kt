package android.health.connect

/**
 * A HealthConnectException with [errorCode] and [message], as Health Connect sends them on Android 14 and
 * later. The android.jar of JVM unit tests has no public constructor for it, and its stubs keep nothing,
 * so this subclass lives in its package and answers both itself.
 */
class TestHealthConnectException(private val code: Int, override val message: String?) : HealthConnectException() {
    override fun getErrorCode(): Int = code
}
