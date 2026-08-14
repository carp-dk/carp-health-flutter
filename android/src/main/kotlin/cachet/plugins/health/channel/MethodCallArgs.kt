package cachet.plugins.health.channel

import io.flutter.plugin.common.MethodCall

/**
 * Typed accessors for Flutter method call arguments.
 */
class MethodCallArgs private constructor(private val values: Map<*, *>) {
    companion object {
        /** Argument accessor for a Flutter method call. */
        fun from(call: MethodCall): MethodCallArgs =
            MethodCallArgs(call.arguments as? Map<*, *> ?: emptyMap<Any, Any?>())
    }

    /** Required string argument. */
    fun requiredString(name: String): String =
        optionalString(name) ?: throw missing(name)

    /** Optional string argument. */
    fun optionalString(name: String): String? = values[name] as? String

    /** Required integer argument. */
    fun requiredInt(name: String): Int =
        optionalInt(name) ?: throw missing(name)

    /** Optional integer argument parsed from a number or string. */
    fun optionalInt(name: String): Int? =
        when (val value = values[name]) {
            is Number -> value.toInt()
            is String -> value.toIntOrNull()
            else -> null
        }

    /** Required long integer argument. */
    fun requiredLong(name: String): Long =
        optionalLong(name) ?: throw missing(name)

    /** Optional long integer argument parsed from a number or string. */
    fun optionalLong(name: String): Long? =
        when (val value = values[name]) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }

    /** Required floating-point argument. */
    fun requiredDouble(name: String): Double =
        optionalDouble(name) ?: throw missing(name)

    /** Optional floating-point argument parsed from a number or string. */
    fun optionalDouble(name: String): Double? =
        when (val value = values[name]) {
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull()
            else -> null
        }

    /** Optional list argument with caller-selected element type. */
    @Suppress("UNCHECKED_CAST")
    fun <T> optionalList(name: String): List<T>? = values[name] as? List<T>

    private fun missing(name: String) =
        IllegalArgumentException("Missing or invalid argument: $name")
}
