package cachet.plugins.health.writing

import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.RecordingResult
import cachet.plugins.health.fakeOf
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class RouteLocationsTest {
    private val time = 1_700_000_000_000L

    // A location as Dart sends it, with [values] added or replaced.
    private fun location(vararg values: Pair<String, Any?>): Map<String, Any?> =
        mapOf("latitude" to 55.68, "longitude" to 12.57, "timestamp" to time) + values

    @Test
    fun readsNumbersOfEveryTypeTheCodecSends() {
        // Dart ints arrive as Integer or Long, doubles as Double.
        val locations = parseRouteLocations(
            listOf(
                location(),
                location("latitude" to 55, "longitude" to 12L, "timestamp" to 1_000, "altitude" to 7),
                location("horizontalAccuracy" to 3.5, "verticalAccuracy" to 2L),
            )
        )
        assertEquals(
            listOf(
                ExerciseRoute.Location(Instant.ofEpochMilli(time), 55.68, 12.57),
                ExerciseRoute.Location(Instant.ofEpochMilli(1_000), 55.0, 12.0, altitude = Length.meters(7.0)),
                ExerciseRoute.Location(
                    Instant.ofEpochMilli(time), 55.68, 12.57,
                    horizontalAccuracy = Length.meters(3.5), verticalAccuracy = Length.meters(2.0),
                ),
            ),
            locations,
        )
    }

    @Test
    fun aValueThatIsNotANumberIsAnInvalidArgument() {
        // A string used to recurse until StackOverflowError, which crashed the app.
        for (key in listOf("latitude", "longitude", "timestamp", "altitude", "horizontalAccuracy")) {
            for (value in listOf("55.68", true)) {
                val error = assertThrows(IllegalArgumentException::class.java) {
                    parseRouteLocations(listOf(location(key to value)))
                }
                assertEquals("Route location $key must be a number, not ${value.javaClass.simpleName}", error.message)
            }
        }
    }

    @Test
    fun aMissingValueOrALocationThatIsNotAMapIsAnInvalidArgument() {
        for (key in listOf("latitude", "longitude", "timestamp")) {
            val error = assertThrows(IllegalArgumentException::class.java) {
                parseRouteLocations(listOf(location() - key))
            }
            assertEquals("Missing $key in route location", error.message)
        }
        assertThrows(IllegalArgumentException::class.java) { parseRouteLocations(listOf(listOf(55.68, 12.57))) }
    }

    @Test
    fun insertWorkoutRouteDataRepliesInvalidArgumentAndKeepsTheRoute() {
        // Collecting locations does not call Health Connect.
        val writer = WorkoutRouteWriter(
            fakeOf { throw UnsupportedOperationException(it) }, CoroutineScope(Dispatchers.Unconfined),
        )
        val started = RecordingResult()
        writer.startWorkoutRoute(started)
        fun insert(vararg locations: Map<String, Any?>) = RecordingResult().also {
            val arguments = hashMapOf("builderId" to started.value, "locations" to locations.toList())
            writer.insertWorkoutRouteData(MethodCall("insertWorkoutRouteData", arguments), it)
        }

        val invalid = insert(location(), location("latitude" to "55.68"))
        assertEquals(1, invalid.replies)
        assertEquals(HealthErrors.INVALID_ARGUMENT, invalid.code)
        assertEquals("Route location latitude must be a number, not String", invalid.message)

        // The builder is still there.
        assertEquals(true, insert(location()).value)
    }
}
