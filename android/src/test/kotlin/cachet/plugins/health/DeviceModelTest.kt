package cachet.plugins.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import cachet.plugins.health.reading.WorkoutConverter
import cachet.plugins.health.reading.WorkoutRoutes
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Every reader sends the model of the device that recorded the data, and null when the app named none. */
class DeviceModelTest {
    private val start = Instant.parse("2026-11-08T10:00:00Z")
    private val end = start.plusSeconds(1800)

    // Each test reads data recorded on a watch and data entered by hand, without a device.
    private val metadata = listOf(
        Metadata.autoRecorded(Device(type = Device.TYPE_WATCH, manufacturer = "Google", model = "Pixel Watch 2")),
        Metadata.manualEntry(),
    )
    private val models = listOf("Pixel Watch 2", null)

    @Test
    fun recordsHaveTheModelOfTheirDevice() {
        val converter = HealthDataConverter()
        val steps = metadata.map { StepsRecord(start, null, end, null, 1200, it) }
        assertEquals(models, steps.map { converter.convertRecord(it, HealthConstants.STEPS).single().deviceModel() })
        assertEquals(models, changedDataPoints(steps).map { it.deviceModel() })
    }

    @Test
    fun sleepStagesHaveTheModelOfTheirSessionsDevice() {
        val converter = HealthDataConverter()
        val stage = SleepSessionRecord.Stage(start, end, SleepSessionRecord.STAGE_TYPE_LIGHT)
        val stages = metadata.map { converter.convertRecordStage(stage, HealthConstants.SLEEP_LIGHT, it).single() }
        assertEquals(models, stages.map { it.deviceModel() })
    }

    @Test
    fun workoutsAndTheirRoutesHaveTheModelOfTheirDevice() {
        val sessions = metadata.map {
            ExerciseSessionRecord(
                startTime = start,
                startZoneOffset = null,
                endTime = end,
                endZoneOffset = null,
                metadata = it,
                exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
            )
        }
        // Without permission to read the totals, nothing else is read.
        val workouts = mutableListOf<Map<String, Any?>>()
        val client = fakeOf<HealthConnectClient> { error("Unexpected call of $it") }
        val converter = WorkoutConverter(client, HealthRecordingFilter())
        runBlocking { converter.handleWorkoutData(sessions, emptyList(), workouts, emptySet()) }
        assertEquals(models, workouts.map { it.deviceModel() })
        assertEquals(models, changedDataPoints(sessions).map { it.deviceModel() })

        val routes = WorkoutRoutes(HealthRecordingFilter())
        val route = ExerciseRoute(listOf(ExerciseRoute.Location(start, 55.78, 12.52)))
        assertEquals(models, sessions.map { routes.buildWorkoutRouteMap(it, route)!!.deviceModel() })
        assertEquals(models, sessions.map { routes.buildConsentRequiredRouteMap(it).deviceModel() })
    }

    /** The device model of this data point, which has the key also when it is null. */
    private fun Map<*, *>.deviceModel(): Any? {
        assertTrue("device_model in $keys", containsKey("device_model"))
        return this["device_model"]
    }
}
