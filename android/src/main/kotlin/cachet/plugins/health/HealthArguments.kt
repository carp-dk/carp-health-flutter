package cachet.plugins.health

import io.flutter.plugin.common.MethodCall

/*
 * Typed access to method channel arguments. A missing or mistyped argument throws an
 * IllegalArgumentException, which HealthErrors reports as INVALID_ARGUMENT (instead of the
 * generic 'error' Flutter replies for a ClassCastException or NullPointerException).
 *
 * Numbers are read as Number: the standard message codec sends Dart ints that fit in 32 bits
 * as Integer and larger ones as Long, so `argument<Long>` fails for small values.
 */

internal fun MethodCall.requireString(key: String): String =
    optionalString(key) ?: throw IllegalArgumentException("Missing argument '$key'")

internal fun MethodCall.optionalString(key: String): String? = when (val value = raw(key)) {
    null -> null
    is String -> value
    else -> throw IllegalArgumentException("Argument '$key' must be a String, not ${value.javaClass.simpleName}")
}

internal fun MethodCall.requireLong(key: String): Long =
    optionalLong(key) ?: throw IllegalArgumentException("Missing argument '$key'")

internal fun MethodCall.optionalLong(key: String): Long? = when (val value = raw(key)) {
    null -> null
    is Number -> value.toLong()
    else -> throw IllegalArgumentException("Argument '$key' must be a number, not ${value.javaClass.simpleName}")
}

/** A list of ints; a missing list is empty. */
internal fun MethodCall.intList(key: String): List<Int> = when (val value = raw(key)) {
    null -> emptyList()
    is List<*> -> value.map {
        (it as? Number)?.toInt() ?: throw IllegalArgumentException("Argument '$key' must be a list of ints")
    }
    else -> throw IllegalArgumentException("Argument '$key' must be a list, not ${value.javaClass.simpleName}")
}

private fun MethodCall.raw(key: String): Any? =
    try {
        argument<Any>(key)
    } catch (e: ClassCastException) {
        // The arguments are not a map.
        throw IllegalArgumentException("Method '$method' needs a map of arguments", e)
    }
