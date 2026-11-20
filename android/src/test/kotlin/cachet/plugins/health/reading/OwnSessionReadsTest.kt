package cachet.plugins.health.reading

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord.Stage
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.units.Length
import cachet.plugins.health.HealthConstants
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Reads of sleep stages, workouts and workout routes with only the write permission of their type:
 * the app's own sessions, as [OwnRecordReadsTest] reads series.
 */
class OwnSessionReadsTest {
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    private fun time(hhmm: String, day: Int = 8): Instant = Instant.parse("2026-11-0${day}T$hhmm:00Z")

    @Test
    fun aSleepStageReadWithOnlyWritePermissionLooksBackAtTheAppsOwnSessions() {
        // Nights of both apps that began before the read, each with a stage that starts in it, and a nap of each.
        val sessions = listOf(OWN_PACKAGE, OTHER).flatMap { app ->
            listOf(
                session(app, time("22:00", day = 7), time("06:00"), time("01:00")),
                session(app, time("13:00"), time("14:00"), time("13:30")),
            )
        }
        val granted = setOf(HealthPermission.getWritePermission(SleepSessionRecord::class))
        val client = fakeRecordStore(SleepSessionRecord::class, sessions, requests, granted)
        val replies = PageReplies(client).read(HealthConstants.SLEEP_LIGHT, time("00:00"), time("23:00"))

        val expected = listOf(
            ReadPoint(time("01:00"), time("06:00"), OWN_PACKAGE), ReadPoint(time("13:30"), time("14:00"), OWN_PACKAGE),
        )
        assertEquals(expected, replies.single().points)
        assertEquals(true, replies.single().permissionDenied)
        assertEquals(expected, PageReplies(client).legacy(HealthConstants.SLEEP_LIGHT, time("00:00"), time("23:00")))
        // Each read, and the lookback of the night before it.
        assertEquals(4, requests.size)
        assertTrue(requests.allOwn())
    }

    @Test
    fun aWorkoutReadWithOnlyWritePermissionReadsTheAppsWorkoutsWithTheirTotals() {
        val workouts = listOf(workout(OWN_PACKAGE, "07:00"), workout(OTHER, "09:00"), workout(OWN_PACKAGE, "18:00"))
        val stored: List<Record> = workouts + listOf(OWN_PACKAGE, OTHER).flatMap { app ->
            listOf("07:00", "09:00", "18:00").map { at ->
                val metadata = writtenBy(app, "$app@$at")
                DistanceRecord(time(at), null, time(at).plusSeconds(3600), null, Length.meters(5000.0), metadata)
            }
        }
        // The steps permission is granted to neither: the workouts have no steps total.
        val granted = setOf(
            HealthPermission.getWritePermission(ExerciseSessionRecord::class),
            HealthPermission.getWritePermission(DistanceRecord::class),
        )
        val client = fakeRecordStore(ExerciseSessionRecord::class, stored, requests, granted)
        val replies = PageReplies(client).read(HealthConstants.WORKOUT, time("00:00"), time("23:00"), pageSize = 1)

        assertNull(replies.last().error)
        assertEquals(listOf(time("07:00"), time("18:00")), replies.flatMap { it.points }.map { it.from })
        assertTrue(replies.all { it.permissionDenied == true })
        assertTrue(replies.first().token!!.startsWith("o1:"))
        // The sessions and their distances, each read for the app's own records only.
        val sessionAndDistance = listOf(ExerciseSessionRecord::class, DistanceRecord::class)
        assertEquals(sessionAndDistance + sessionAndDistance, requests.map { it.recordType })
        assertTrue(requests.allOwn())
        assertTrue(requests.none { it.recordType == StepsRecord::class })
    }

    @Test
    fun aWorkoutRouteReadWithOnlyWritePermissionReadsTheRoutesOfTheAppsWorkouts() {
        val workouts = listOf(workout(OWN_PACKAGE, "07:00"), workout(OTHER, "09:00"))
        val granted = setOf(
            HealthPermission.getWritePermission(ExerciseSessionRecord::class),
            HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE,
        )
        val client = fakeRecordStore(ExerciseSessionRecord::class, workouts, requests, granted)
        val replies = PageReplies(client).read(HealthConstants.WORKOUT_ROUTE, time("00:00"), time("23:00"))

        val route = listOf(ReadPoint(time("07:10"), time("07:10"), OWN_PACKAGE))
        assertEquals(route, replies.single().points)
        assertEquals(true, replies.single().permissionDenied)
        assertEquals(route, PageReplies(client).legacy(HealthConstants.WORKOUT_ROUTE, time("00:00"), time("23:00")))
        assertEquals(2, requests.size)
        assertTrue(requests.allOwn())
    }

    /** A sleep session of [app] from [from] to [to], light sleep from [light] on. */
    private fun session(app: String, from: Instant, to: Instant, light: Instant): SleepSessionRecord =
        sleepSession(
            from, to,
            stages = listOf(
                Stage(from, light, SleepSessionRecord.STAGE_TYPE_DEEP),
                Stage(light, to, SleepSessionRecord.STAGE_TYPE_LIGHT),
            ),
            packageName = app,
        )

    /** An hour's run of [app] from [start], with a route of one location 10 minutes in. */
    private fun workout(app: String, start: String): ExerciseSessionRecord =
        ExerciseSessionRecord(
            startTime = time(start), startZoneOffset = null, endTime = time(start).plusSeconds(3600),
            endZoneOffset = null, metadata = writtenBy(app, "$app@$start"),
            exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
            exerciseRoute = ExerciseRoute(listOf(ExerciseRoute.Location(time(start).plusSeconds(600), 55.78, 12.52))),
        )

    private companion object {
        const val OTHER = "com.example.other"
    }
}
