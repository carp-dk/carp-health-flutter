package cachet.plugins.health.reading

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthRecordingFilter
import java.time.Instant
import kotlin.reflect.KClass
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
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

    /** Record types whose reads throw SecurityException, as the closed-source Health Connect APK might. */
    private var refused = emptySet<KClass<out Record>>()

    /** Reads [stored] as Health Connect does: the records of the request's type and data origins. */
    private val client = fakeHealthConnect { method, args ->
        check(method == "readRecords") { "Unexpected call of $method" }
        val request = args.single() as ReadRecordsRequest<*>
        requests.add(request)
        if (request.recordType in refused) throw SecurityException("Refused")
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

    @Test
    fun aTotalIsReadOnlyWithPermissionToReadIt() {
        // An app that may read distances only: Google Play asks apps not to request more than they use.
        val workout = readRun(DistanceRecord::class)

        assertEquals(listOf(DistanceRecord::class), requests.map { it.recordType })
        assertEquals(3000.0, workout["totalDistance"])
        assertNull(workout["totalEnergyBurned"])
        assertNull(workout["totalSteps"])
    }

    @Test
    fun theTotalsOfTheAppsOwnWorkoutAreReadWithWritePermission() {
        // The watch app may write distances and energy, but read none: Health Connect returns its own.
        val granted = setOf(
            HealthPermission.getWritePermission(DistanceRecord::class),
            HealthPermission.getWritePermission(TotalCaloriesBurnedRecord::class),
        )
        val workout = readRun(granted, packageName = watch)

        assertEquals(3000.0, workout["totalDistance"])
        assertEquals(250.0, workout["totalEnergyBurned"])
        assertNull(workout["totalSteps"])
        assertEquals(listOf(DistanceRecord::class, TotalCaloriesBurnedRecord::class), requests.map { it.recordType })
        for (request in requests) assertEquals(setOf(DataOrigin(watch)), request.dataOriginFilter)
    }

    @Test
    fun theTotalsOfAnotherAppsWorkoutNeedReadPermission() {
        val granted = setOf(HealthPermission.getWritePermission(DistanceRecord::class))
        // The phone app reads the watch app's run: Health Connect would refuse to read its distances.
        val workout = readRun(granted, packageName = phone)

        assertNull(workout["totalDistance"])
        assertNull(workout["totalEnergyBurned"])
        assertEquals(emptyList<ReadRecordsRequest<*>>(), requests)
    }

    @Test
    fun aTotalCountsEveryPageOfRecords() {
        // More step records in the run than one request returns.
        val steps = (0 until HC_MAX_RECORDS + 1).map { i ->
            val from = start.plusMillis(300L * i)
            StepsRecord(from, null, from.plusMillis(300), null, 1, writtenBy(watch, "steps$i"))
        }
        val granted = setOf(HealthPermission.getReadPermission(StepsRecord::class))
        val store = fakeRecordStore(StepsRecord::class, steps, requests, granted)
        val workouts = mutableListOf<Map<String, Any?>>()
        val converter = WorkoutConverter(store, HealthRecordingFilter(), OWN_PACKAGE)
        runBlocking { converter.handleWorkoutData(listOf(run), emptyList(), workouts, granted) }

        assertEquals((HC_MAX_RECORDS + 1).toDouble(), workouts.single()["totalSteps"])
        assertEquals(listOf(null, "$HC_MAX_RECORDS"), requests.map { it.pageToken })
    }

    @Test
    fun aRefusedReadOfTheAppsOwnTotalLeavesItNullBeforeAndroid14() {
        // The Health Connect APK (Android 13 and lower) is closed source: say it refuses the app's own distances.
        refused = setOf(DistanceRecord::class)
        val granted = setOf(
            HealthPermission.getWritePermission(DistanceRecord::class),
            HealthPermission.getWritePermission(TotalCaloriesBurnedRecord::class),
        )
        val workout = readRun(granted, packageName = watch, sdkInt = 33)

        assertNull(workout["totalDistance"])
        assertEquals(250.0, workout["totalEnergyBurned"])
        // From Android 14 on, Health Connect accepts the read, so a refusal fails it, as it does with read permission.
        assertThrows(SecurityException::class.java) { readRun(granted, packageName = watch, sdkInt = 34) }
        val readable = setOf(HealthPermission.getReadPermission(DistanceRecord::class))
        assertThrows(SecurityException::class.java) { readRun(readable, sdkInt = 33) }
    }

    @Test
    fun aRefusedOwnTotalKeepsTheWorkoutsOfThePage() {
        val ownRun = ExerciseSessionRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            metadata = writtenBy(OWN_PACKAGE, "own run"), exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
        )
        val distance = DistanceRecord(start, null, end, null, Length.meters(3000.0), writtenBy(OWN_PACKAGE, "own"))
        val refuseDistances = { request: ReadRecordsRequest<*> ->
            SecurityException("Refused").takeIf { request.recordType == DistanceRecord::class }
        }
        // Every app's workouts, or (with only the write permission of workouts) the app's own: either keeps them.
        val readWorkouts = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        val writeWorkouts = HealthPermission.getWritePermission(ExerciseSessionRecord::class)
        for (workouts in listOf(readWorkouts, writeWorkouts)) {
            val granted = setOf(workouts, HealthPermission.getWritePermission(DistanceRecord::class))
            val stored = listOf<Record>(ownRun, distance)
            val store = fakeRecordStore(ExerciseSessionRecord::class, stored, requests, granted, refuseDistances)
            val reply = PageReplies(store, sdkInt = 33).read(HealthConstants.WORKOUT, start, end).single()

            assertNull(reply.error)
            assertEquals(listOf(ReadPoint(start, end, OWN_PACKAGE)), reply.points)
            assertEquals(reply.points, PageReplies(store, sdkInt = 33).legacy(HealthConstants.WORKOUT, start, end))
        }
    }

    /** The workout that [run] reads as, with permission to read the [readable] record types. */
    private fun readRun(vararg readable: KClass<out Record>): Map<String, Any?> =
        readRun(readable.mapTo(HashSet()) { HealthPermission.getReadPermission(it) })

    /** The workout that [run] reads as with [granted], for the app [packageName] on Android [sdkInt]. */
    private fun readRun(granted: Set<String>, packageName: String = OWN_PACKAGE, sdkInt: Int = 37): Map<String, Any?> {
        val workouts = mutableListOf<Map<String, Any?>>()
        val converter = WorkoutConverter(client, HealthRecordingFilter(), packageName, sdkInt)
        runBlocking { converter.handleWorkoutData(listOf(run), emptyList(), workouts, granted) }
        return workouts.single()
    }
}
