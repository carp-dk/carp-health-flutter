package cachet.plugins.health.reading

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthRecordingFilter
import java.time.Instant
import kotlin.reflect.KClass
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WorkoutConverterTest {
    private val start = Instant.parse("2026-11-08T10:00:00Z")
    private val end = start.plusSeconds(1800)
    private val watch = "com.example.watch"
    private val phone = "com.example.phone"

    /** A run that the watch app wrote. */
    private val run = ExerciseSessionRecord(
        startTime = start,
        startZoneOffset = null,
        endTime = end,
        endZoneOffset = null,
        metadata = writtenBy(watch, "run"),
        exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
    )

    /** The records in the run's time: distance and energy from the watch app and the phone, steps from the phone. */
    private val stored: List<Record> = listOf(
        DistanceRecord(start, null, end, null, Length.meters(3000.0), writtenBy(watch, "watch distance")),
        DistanceRecord(start, null, end, null, Length.meters(3100.0), writtenBy(phone, "phone distance")),
        TotalCaloriesBurnedRecord(start, null, end, null, Energy.kilocalories(250.0), writtenBy(watch, "watch energy")),
        TotalCaloriesBurnedRecord(start, null, end, null, Energy.kilocalories(240.0), writtenBy(phone, "phone energy")),
        StepsRecord(start, null, end, null, 4100, writtenBy(phone, "phone steps")),
    )
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    /** Reads [stored] as Health Connect does: the records of the request's type and data origins. */
    private val client = fakeHealthConnect { method, args ->
        check(method == "readRecords") { "Unexpected call of $method" }
        val request = args.single() as ReadRecordsRequest<*>
        requests.add(request)
        val origins = request.dataOriginFilter
        val records = stored
            .filter { request.recordType.isInstance(it) }
            .filter { origins.isEmpty() || it.metadata.dataOrigin in origins }
        ReadRecordsResponse(records, null)
    }

    @Test
    fun totalsCountOnlyTheRecordsOfTheAppThatWroteTheWorkout() {
        val workout = readRun(DistanceRecord::class, TotalCaloriesBurnedRecord::class, StepsRecord::class)

        assertEquals(3000.0, workout["totalDistance"])
        assertEquals(250.0, workout["totalEnergyBurned"])
        // The watch app wrote no steps; the phone's steps are not the run's.
        assertNull(workout["totalSteps"])
        assertEquals(3, requests.size)
        for (request in requests) assertEquals(setOf(DataOrigin(watch)), request.dataOriginFilter)
    }

    /** The workout that [run] reads as, with permission to read the [readable] record types. */
    private fun readRun(vararg readable: KClass<out Record>): Map<String, Any?> {
        val granted = readable.mapTo(HashSet()) { HealthPermission.getReadPermission(it) }
        val workouts = mutableListOf<Map<String, Any?>>()
        val converter = WorkoutConverter(client, HealthRecordingFilter())
        runBlocking { converter.handleWorkoutData(listOf(run), emptyList(), workouts, granted) }
        return workouts.single()
    }

    private fun writtenBy(packageName: String, id: String) =
        metadata(Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED, id, DataOrigin(packageName))
}
