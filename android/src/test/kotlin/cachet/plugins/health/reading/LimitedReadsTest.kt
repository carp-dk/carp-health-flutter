package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord.Stage
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.RecordingResult
import cachet.plugins.health.fakeOf
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Reads with a 'limit': pages of the records that start last first, until the Dart side has
 * 'limit' points (where [SleepReads.pages] stops too). Series reads: [LimitedSeriesReadsTest].
 */
class LimitedReadsTest {
    private val reads = SleepReads()

    private fun time(hhmm: String, day: Int = 8): Instant = Instant.parse("2026-11-0${day}T$hhmm:00Z")

    private fun point(from: String, to: String) = ReadPoint(time(from), time(to), APP)

    // A night that began before the range, with a stage that starts in it, and three naps in the range.
    private val night = sleepSession(
        time("22:00", day = 7), time("06:00"),
        stages = listOf(
            Stage(time("22:00", day = 7), time("01:00"), SleepSessionRecord.STAGE_TYPE_LIGHT),
            Stage(time("01:00"), time("06:00"), SleepSessionRecord.STAGE_TYPE_LIGHT),
        ),
        packageName = APP,
    )
    private val naps = listOf("09:00", "12:00", "15:00").map { start ->
        val (from, half, to) = listOf(0L, 1800L, 3600L).map { time(start).plusSeconds(it) }
        sleepSession(
            from, to,
            stages = listOf(
                Stage(from, half, SleepSessionRecord.STAGE_TYPE_LIGHT),
                Stage(half, to, SleepSessionRecord.STAGE_TYPE_LIGHT),
            ),
            packageName = APP,
        )
    }
    private val sessions = naps + night

    @Test
    fun aLimitedReadAsksForTheRecordsThatStartLastFirst() {
        // As Dart reads: pages of at most 'limit' points, until it has 'limit' of them.
        val read = reads.pages(
            HealthConstants.SLEEP_SESSION, time("00:00"), time("23:00"), sessions, pageSize = 2, limit = 2,
        )
        assertEquals(listOf(listOf(point("15:00", "16:00"), point("12:00", "13:00"))), read.pages)
        assertNotNull(read.tokens.single())
        val request = reads.requests.single()
        assertFalse(request.ascendingOrder)
        assertEquals(2, request.pageSize)
        assertNull(request.pageToken)
    }

    @Test
    fun aLimitedStageReadGoesOnPastSessionsWithoutTheStage() {
        // A night with deep sleep, then a nap of light sleep only, or one without stages.
        val deepNight = sleepSession(
            time("23:00", day = 7), time("07:00"),
            stages = listOf(
                Stage(time("23:00", day = 7), time("01:00"), SleepSessionRecord.STAGE_TYPE_LIGHT),
                Stage(time("01:00"), time("02:00"), SleepSessionRecord.STAGE_TYPE_DEEP),
                Stage(time("02:00"), time("07:00"), SleepSessionRecord.STAGE_TYPE_LIGHT),
            ),
            packageName = APP,
        )
        val lightNap = sleepSession(
            time("14:00"), time("15:00"),
            stages = listOf(Stage(time("14:00"), time("15:00"), SleepSessionRecord.STAGE_TYPE_LIGHT)),
            packageName = APP,
        )
        for (nap in listOf(lightNap, sleepSession(time("14:00"), time("15:00"), packageName = APP))) {
            reads.requests.clear()
            val read = reads.pages(
                HealthConstants.SLEEP_DEEP, time("00:00", day = 7), time("23:00"), listOf(deepNight, nap),
                pageSize = 1, limit = 1,
            )
            // Used to be the nap alone, as the only page: no point although the night has one.
            assertEquals(listOf(point("01:00", "02:00")), read.points)
            assertEquals(listOf(null, "1"), reads.requests.map { it.pageToken })
            assertTrue(reads.requests.all { !it.ascendingOrder && it.pageSize == 1 })
        }
    }

    @Test
    fun aLimitedStageReadDoesNotLookBack() {
        // A read without a limit also finds the stage of the night that starts in the range.
        val all = reads.pages(HealthConstants.SLEEP_LIGHT, time("00:00"), time("23:00"), sessions)
        assertTrue(point("01:00", "06:00") in all.points)
        reads.requests.clear()
        // Every stage of the nap that starts last: the Dart side keeps the newest of them.
        val light = reads.pages(HealthConstants.SLEEP_LIGHT, time("00:00"), time("23:00"), sessions, limit = 1)
        assertEquals(listOf(point("15:00", "15:30"), point("15:30", "16:00")), light.points)
        assertEquals(1, reads.requests.size)
        // A limit above what the range holds reads every nap, but not the night that began before it.
        val more = reads.pages(HealthConstants.SLEEP_LIGHT, time("00:00"), time("23:00"), sessions, limit = 10)
        assertEquals(6, more.points.size)
        assertFalse(point("01:00", "06:00") in more.points)
    }

    @Test
    fun getDataReadsWhatTheLimitedPageReads() {
        for (type in listOf(HealthConstants.SLEEP_SESSION, HealthConstants.SLEEP_LIGHT)) {
            val page = reads.pages(type, time("00:00"), time("23:00"), sessions, limit = 2).points
            reads.requests.clear()
            assertEquals(type, page, reads.legacy(type, time("00:00"), time("23:00"), sessions, limit = 2))
            assertFalse(reads.requests.single().ascendingOrder)
            reads.requests.clear()
        }
    }

    @Test
    fun aLimitedReadAsksForNoMoreRecordsThanOneWithout() {
        // A limit above 5000 is 5000, and sessions are read at most 500 at a time.
        reads.pages(HealthConstants.SLEEP_SESSION, time("00:00"), time("23:00"), sessions, limit = 100_000)
        assertEquals(SLEEP_MAX_RECORDS, reads.requests.single().pageSize)
    }

    @Test
    fun aLimitedRouteReadIsOneNewestFirstRequestWhenTheLatestWorkoutHasARoute() {
        val workouts = listOf(
            workout("run", "07:00", route = true), workout("gym", "12:00", route = false),
            workout("ride", "18:00", route = true),
        )
        val client = fakeRecordStore(ExerciseSessionRecord::class, workouts, reads.requests)
        val ride = listOf(point("18:10", "18:10"))
        assertEquals(
            ride,
            reads.pages(HealthConstants.WORKOUT_ROUTE, time("00:00"), time("23:00"), client, limit = 1).points,
        )
        assertEquals(ride, reads.legacy(HealthConstants.WORKOUT_ROUTE, time("00:00"), time("23:00"), client, limit = 1))
        // One request for each read.
        assertEquals(2, reads.requests.size)
        for (request in reads.requests) {
            assertEquals(ExerciseSessionRecord::class, request.recordType)
            assertFalse(request.ascendingOrder)
            assertEquals(1, request.pageSize)
            assertNull(request.pageToken)
        }
    }

    @Test
    fun aLimitedRouteReadGoesOnPastWorkoutsWithoutARoute() {
        val workouts = listOf(workout("run", "07:00", route = true), workout("gym", "18:00", route = false))
        val client = fakeRecordStore(ExerciseSessionRecord::class, workouts, reads.requests)
        val read = reads.pages(HealthConstants.WORKOUT_ROUTE, time("00:00"), time("23:00"), client, limit = 1)
        // Used to be the indoor workout alone, as the only page: no route although the run has one.
        assertEquals(listOf(point("07:10", "07:10")), read.points)
        assertEquals(listOf(null, "1"), reads.requests.map { it.pageToken })
    }

    @Test
    fun heartRateIsReadByRecordNotInTimeSlices() {
        val records = (0..2).map { i ->
            val from = time("10:00").plusSeconds(600L * i)
            val samples = listOf(HeartRateRecord.Sample(from, 60L + i), HeartRateRecord.Sample(from.plusSeconds(60), 70L))
            HeartRateRecord(from, null, from.plusSeconds(120), null, samples, Metadata.manualEntryWithId("hr$i"))
        }
        val requests = mutableListOf<ReadRecordsRequest<*>>()
        val permissions = fakeOf<PermissionController> { setOf(HealthPermission.getReadPermission(HeartRateRecord::class)) }
        val client = fakeHealthConnect { method, args ->
            when (method) {
                "getPermissionController" -> permissions
                "readRecords" -> {
                    val request = (args.single() as ReadRecordsRequest<*>).also { requests += it }
                    ReadRecordsResponse(records.sortedByDescending { it.startTime }.take(request.pageSize), null)
                }
                else -> throw UnsupportedOperationException(method)
            }
        }
        val source = FakeHeartRateSource(records)

        val page = readPage(client, HeartRatePageReader(source, 37), HealthConstants.HEART_RATE, limit = 1)

        // Both samples of the record that starts last, from Health Connect's records, not its sample counts.
        val times = (page["data"] as List<*>).map { Instant.ofEpochMilli((it as Map<*, *>)["date_from"] as Long) }
        assertEquals(listOf(time("10:20"), time("10:21")), times)
        assertNull(page["nextPageToken"])
        assertEquals(0, source.calls)
        assertEquals(1, requests.single().pageSize)
        assertFalse(requests.single().ascendingOrder)
    }

    /** An hour's exercise session from [start], with a route of one location 10 minutes in if [route]. */
    private fun workout(id: String, start: String, route: Boolean): ExerciseSessionRecord {
        val location = ExerciseRoute.Location(time(start).plusSeconds(600), 55.78, 12.52)
        return ExerciseSessionRecord(
            startTime = time(start), startZoneOffset = null, endTime = time(start).plusSeconds(3600),
            endZoneOffset = null, metadata = metadata(Metadata.RECORDING_METHOD_ACTIVELY_RECORDED, id, DataOrigin(APP)),
            exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
            exerciseRoute = if (route) ExerciseRoute(listOf(location)) else null,
        )
    }

    /** One getDataPage reply for [dataType] in 09:00 to 11:00 from [client]. */
    private fun readPage(
        client: HealthConnectClient,
        heartRate: HeartRatePageReader,
        dataType: String,
        limit: Int,
    ): Map<*, *> {
        val job = SupervisorJob()
        val dataConverter = HealthDataConverter()
        val filter = HealthRecordingFilter()
        val converter = RecordConverter(
            dataConverter, filter, WorkoutConverter(client, filter), SleepConverter(dataConverter, filter),
        )
        val reader = DataPageReader(
            client, CoroutineScope(job), dataConverter, converter, WorkoutRoutes(filter), SeriesLookback(client),
            SleepLookback(client), heartRate,
        )
        val arguments = hashMapOf(
            "dataTypeKey" to dataType, "startTime" to time("09:00").toEpochMilli(),
            "endTime" to time("11:00").toEpochMilli(), "limit" to limit,
        )
        val result = RecordingResult()
        reader.getDataPage(MethodCall("getDataPage", arguments), result)
        runBlocking { job.children.toList().joinAll() }
        assertEquals(1, result.replies)
        assertNull(result.message, result.code)
        return result.value as Map<*, *>
    }

    private companion object {
        const val APP = "com.example.sleep"
    }
}
