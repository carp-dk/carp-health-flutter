package cachet.plugins.health.writing

import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.units.Length
import java.time.Instant

/**
 * The locations in [rawLocations], maps with 'latitude', 'longitude', 'timestamp' (epoch
 * milliseconds) and optionally 'altitude', 'horizontalAccuracy' and 'verticalAccuracy' (meters), all
 * numbers. Throws IllegalArgumentException if a location is not a map, lacks a required value, or has
 * a value that is not a number or is out of range.
 */
internal fun parseRouteLocations(rawLocations: List<*>): List<ExerciseRoute.Location> =
    rawLocations.map { raw ->
        val entry = raw as? Map<*, *> ?: throw IllegalArgumentException("A route location must be a map")
        ExerciseRoute.Location(
            time = Instant.ofEpochMilli(entry.requireNumber("timestamp").toLong()),
            latitude = entry.requireNumber("latitude").toDouble(),
            longitude = entry.requireNumber("longitude").toDouble(),
            horizontalAccuracy = entry.optionalNumber("horizontalAccuracy")?.let { Length.meters(it.toDouble()) },
            verticalAccuracy = entry.optionalNumber("verticalAccuracy")?.let { Length.meters(it.toDouble()) },
            altitude = entry.optionalNumber("altitude")?.let { Length.meters(it.toDouble()) },
        )
    }

private fun Map<*, *>.requireNumber(key: String): Number =
    optionalNumber(key) ?: throw IllegalArgumentException("Missing $key in route location")

private fun Map<*, *>.optionalNumber(key: String): Number? = when (val value = this[key]) {
    null -> null
    is Number -> value
    else -> throw IllegalArgumentException("Route location $key must be a number, not ${value.javaClass.simpleName}")
}
