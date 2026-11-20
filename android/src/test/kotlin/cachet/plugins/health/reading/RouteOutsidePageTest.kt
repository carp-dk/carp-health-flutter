package cachet.plugins.health.reading

import android.health.connect.HealthConnectException.ERROR_INTERNAL
import android.health.connect.HealthConnectException.ERROR_IO
import android.health.connect.TestHealthConnectException
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Android 14 and 15 Health Connect fail a read of exercise sessions when a session with a route that the
 * read matches is not in the page ([fakeSessionStore]); the readers then read the rest of the range in one
 * request ([readRecordsPage]), and getDataPage replies the sessions it asked for ([RecordsPage.cut]). As on
 * the API 35 emulator, the app may read every route.
 */
class RouteOutsidePageTest {
    private val start = Instant.parse("2026-10-20T00:00:00Z")
    private val end = start.plusSeconds(86400)
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    private fun at(hour: Int, minute: Int = 0): Instant = start.plusSeconds(3600L * hour + 60L * minute)

    @Test
    fun routesAreReadAgainWithTheRestOfTheRangeAndRepliedAPageAtATime() {
        // Seven runs with routes, which are read 5 at a time.
        val client = fakeSessionStore((0 until 7).map { runSession("run$it", at(7 + it), route = true) }, requests)
        for (sdkInt in listOf(34, 35)) {
            requests.clear()
            val replies = PageReplies(client, sdkInt = sdkInt).read(HealthConstants.WORKOUT_ROUTE, start, end)

            assertNull(replies.last().error)
            val pages = replies.map { page -> page.points.map { it.from } }
            assertEquals((0 until 7).map { at(7 + it, 10) }.chunked(ROUTE_MAX_RECORDS), pages)
            assertEquals(listOf(ROUTE_MAX_RECORDS, HC_MAX_RECORDS, ROUTE_MAX_RECORDS), requests.map { it.pageSize })
            // The second page starts at the first run left out, which Health Connect then reads in one page.
            val next = HealthConnectPosition(false, at(12).toEpochMilli(), 0).encode()
            assertEquals(listOf(null, null, next), requests.map { it.pageToken })
        }
    }

    @Test
    fun workoutsAreReadAgainWithTheRestOfTheRangeAndRepliedAPageAtATime() {
        // 21 workouts, read 20 at a time, whose last has a route.
        val runs = (0 until 21).map { runSession("run$it", at(0, 30 * it), route = it == 20) }
        val replies =
            PageReplies(fakeSessionStore(runs, requests), sdkInt = 35).read(HealthConstants.WORKOUT, start, end)

        assertNull(replies.last().error)
        assertEquals(listOf(20, 1), replies.map { it.points.size })
        assertEquals(listOf(WORKOUT_MAX_RECORDS, HC_MAX_RECORDS, WORKOUT_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun aPageThatEndsInsideTheSessionsOfOneStartTimeReadsThemWhole() {
        // Two apps' sessions of the same start time: the first page ends with the one with a route. A token past it
        // would skip it although Health Connect still reads its route; the plugin reads all of 8:00 instead.
        val sessions = listOf(
            runSession("a", at(7), route = false), runSession("b", at(8), route = true),
            runSession("c", at(8), route = false, OTHER), runSession("d", at(9), route = false),
        )
        val replies = PageReplies(fakeSessionStore(sessions, requests), sdkInt = 35)
            .read(HealthConstants.WORKOUT, start, end, pageSize = 2)

        assertNull(replies.last().error)
        val pages = replies.map { page -> page.points.map { it.from to it.source } }
        val expected = listOf(at(7) to OWN_PACKAGE, at(8) to OWN_PACKAGE, at(8) to OTHER, at(9) to OWN_PACKAGE)
        assertEquals(listOf(expected.take(3), expected.drop(3)), pages)
        assertEquals(listOf(2, HC_MAX_RECORDS, 2), requests.map { it.pageSize })
        val past = HealthConnectPosition(false, at(8).toEpochMilli() + 1, 0).encode()
        assertEquals(listOf(null, null, past), requests.map { it.pageToken })
        assertEquals(at(8) to at(8).plusMillis(1), requests[1].timeRangeFilter.let { it.startTime to it.endTime })
    }

    @Test
    fun aNewestFirstChainReadAgainAndCutReadsEverySessionOnce() {
        // Three sessions start at 8:00; the route of the one at 9:00 is in the first page, that of b is not.
        val sessions = listOf(
            runSession("a", at(7), route = false), runSession("b", at(8), route = true, OTHER),
            runSession("c", at(8), route = false, OTHER), runSession("d", at(8), route = false),
            runSession("e", at(9), route = true),
        )
        val client = fakeSessionStore(sessions, requests)
        val page = runBlocking { client.readRecordsPage(sessionsRequest(ascending = false, 1, null), 35) }
        assertEquals(listOf("e", "b", "c", "d", "a"), page.records.map { it.metadata.id })
        assertTrue(page.reread && page.pageToken == null)
        assertEquals(listOf(1 to null, HC_MAX_RECORDS to null), requests.map { it.pageSize to it.pageToken })

        // Cut to its first session, the next page starts at 8:00, newest first, and ends inside its sessions.
        val cut = page.cut(1, descending = true)
        assertEquals(listOf("e"), cut.records.map { it.metadata.id })
        val rest = runBlocking { client.readRecordsPage(sessionsRequest(ascending = false, 1, cut.pageToken), 35) }
        assertEquals(listOf("b", "c", "d"), rest.records.map { it.metadata.id })
        assertTrue(!rest.reread && rest.tied == 3)
        assertEquals(HealthConnectPosition(true, at(8).toEpochMilli() - 1, 0).encode(), rest.pageToken)
        val last = runBlocking { client.readRecordsPage(sessionsRequest(ascending = false, 1, rest.pageToken), 35) }
        assertEquals(listOf("a"), last.records.map { it.metadata.id })
        assertNull(last.pageToken)
    }

    @Test
    fun aTokenWithAnOffsetIsNotReadAgain() {
        // Health Connect's own token after a page that ended inside the sessions of 8:00, which the plugin does not
        // send: its where clause still matches b, whose route is not in the page, and so would a read again.
        val sessions = listOf(
            runSession("a", at(7), route = false), runSession("b", at(8), route = true, OTHER),
            runSession("c", at(8), route = false, OTHER), runSession("d", at(8), route = false),
        )
        val client = fakeSessionStore(sessions, requests)
        val token = HealthConnectPosition(true, at(8).toEpochMilli(), 2).encode()
        val error = assertThrows(IllegalStateException::class.java) {
            runBlocking { client.readRecordsPage(sessionsRequest(ascending = false, 3, token), 35) }
        }
        assertTrue(isRouteOutsidePage(error, ExerciseSessionRecord::class, 35))
        assertEquals(1, requests.size)
    }

    @Test
    fun aTokenInTheOtherOrderIsNotReadAgain() {
        // Health Connect takes the order from the token, so the read again could not know which one was meant.
        val sessions = (0 until 4).map { runSession("run$it", at(7), route = it == 3) }
        val client = fakeSessionStore(sessions, requests)
        for (offset in listOf(0, 1)) {
            val token = HealthConnectPosition(true, at(7).toEpochMilli(), offset).encode()
            requests.clear()
            val error = assertThrows(IllegalStateException::class.java) {
                runBlocking { client.readRecordsPage(sessionsRequest(ascending = true, 1, token), 35) }
            }
            assertTrue(isRouteOutsidePage(error, ExerciseSessionRecord::class, 35))
            assertEquals(1, requests.size)
        }
    }

    @Test
    fun aReadAgainThatFailsTooIsReported() {
        // 5001 workouts, whose last has a route: it is not in the read again of 5000 either.
        val runs = (0..HC_MAX_RECORDS).map {
            runSession("run$it", start.plusSeconds(10L * it), route = it == HC_MAX_RECORDS)
        }
        val replies =
            PageReplies(fakeSessionStore(runs, requests), sdkInt = 35).read(HealthConstants.WORKOUT, start, end)

        assertEquals(listOf(HealthErrors.HEALTH_ERROR), replies.map { it.error })
        assertEquals(listOf(WORKOUT_MAX_RECORDS, HC_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun aLimitedReadConvertsOnlyTheNewestSessionsItNeeds() {
        // The latest workout was indoors; the two before have routes.
        val sessions = listOf(
            runSession("run", at(7), route = true), runSession("ride", at(12), route = true),
            runSession("gym", at(18), route = false),
        )
        val client = fakeSessionStore(sessions, requests)
        val routes = PageReplies(client, sdkInt = 35).read(HealthConstants.WORKOUT_ROUTE, start, end, limit = 1)
        val workouts = PageReplies(client, sdkInt = 35).read(HealthConstants.WORKOUT, start, end, limit = 1)

        // The ride's route and the gym workout, each the last page, though more sessions were read.
        assertEquals(listOf(listOf(at(12, 10))), routes.map { page -> page.points.map { it.from } })
        assertEquals(listOf(listOf(at(18))), workouts.map { page -> page.points.map { it.from } })
        assertTrue((routes + workouts).all { it.token == null })
        assertEquals(listOf(1, HC_MAX_RECORDS, 1, HC_MAX_RECORDS), requests.map { it.pageSize })
        assertTrue(requests.none { it.ascendingOrder })

        // getData keeps the 'limit' sessions that start last.
        requests.clear()
        val legacyWorkouts = PageReplies(client, sdkInt = 35).legacy(HealthConstants.WORKOUT, start, end, 1)
        assertEquals(listOf(at(18)), legacyWorkouts.map { it.from })
        val legacyRoutes = PageReplies(client, sdkInt = 35).legacy(HealthConstants.WORKOUT_ROUTE, start, end, 2)
        assertEquals(listOf(at(12, 10)), legacyRoutes.map { it.from })
        assertEquals(listOf(1, HC_MAX_RECORDS, 2, HC_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun aReadOfTheAppsOwnSessionsReadsThemAgainOnly() {
        val sessions = (0 until 7).map { runSession("run$it", at(7 + it), route = true) } +
            runSession("other", at(6), route = true, packageName = OTHER)
        val granted = setOf(HealthPermission.getWritePermission(ExerciseSessionRecord::class))
        val replies = PageReplies(fakeSessionStore(sessions, requests, granted), sdkInt = 35)
            .read(HealthConstants.WORKOUT_ROUTE, start, end)

        assertEquals(listOf(5, 2), replies.map { it.points.size })
        assertEquals(listOf(true, true), replies.map { it.permissionDenied })
        assertTrue(requests.size == 3 && requests.allOwn())
    }

    @Test
    fun otherVersionsAndOtherErrorsAreReportedAsBefore() {
        // Android 16 and later check for the session: their errors are something else.
        val client = fakeSessionStore((0 until 7).map { runSession("run$it", at(7 + it), route = true) }, requests)
        for (sdkInt in listOf(33, 36, 37)) {
            requests.clear()
            val reply = PageReplies(client, sdkInt = sdkInt).read(HealthConstants.WORKOUT_ROUTE, start, end).single()
            assertEquals(HealthErrors.HEALTH_ERROR, reply.error)
            assertEquals(1, requests.size)
        }
        // Another internal error on Android 15.
        requests.clear()
        val failing = fakeRecordStore(ExerciseSessionRecord::class, emptyList(), requests) {
            IllegalStateException(TestHealthConnectException(ERROR_INTERNAL, "java.lang.NullPointerException"))
        }
        val reply = PageReplies(failing, sdkInt = 35).read(HealthConstants.WORKOUT, start, end).single()
        assertEquals(HealthErrors.HEALTH_ERROR, reply.error)
        assertEquals(1, requests.size)
    }

    @Test
    fun recognizesOnlyHealthConnectsFailureOnARouteOutsideThePage() {
        val failure = IllegalStateException(TestHealthConnectException(ERROR_INTERNAL, ROUTE_OUTSIDE_PAGE))
        assertTrue(isRouteOutsidePage(failure, ExerciseSessionRecord::class, 34))
        assertTrue(isRouteOutsidePage(failure, ExerciseSessionRecord::class, 35))
        for (sdkInt in listOf(33, 36, 37)) {
            assertFalse(isRouteOutsidePage(failure, ExerciseSessionRecord::class, sdkInt))
        }
        assertFalse(isRouteOutsidePage(failure, SleepSessionRecord::class, 35))
        val others = listOf(
            TestHealthConnectException(ERROR_INTERNAL, ROUTE_OUTSIDE_PAGE),
            IllegalArgumentException(TestHealthConnectException(ERROR_INTERNAL, ROUTE_OUTSIDE_PAGE)),
            IllegalStateException(TestHealthConnectException(ERROR_IO, ROUTE_OUTSIDE_PAGE)),
            IllegalStateException(TestHealthConnectException(ERROR_INTERNAL, "java.lang.NullPointerException")),
            IllegalStateException(RuntimeException(ROUTE_OUTSIDE_PAGE)),
            IllegalStateException(ROUTE_OUTSIDE_PAGE),
        )
        for (other in others) assertFalse("$other", isRouteOutsidePage(other, ExerciseSessionRecord::class, 35))
    }

    @Test
    fun readsThePositionOfAHealthConnectPageToken() {
        // PageTokenWrapper.of(true, 1_700_000_000_000, 3).encode(), and android14-release's newest first token.
        val ascending = HealthConnectPosition.decode("108953116266496")!!
        assertFalse(ascending.descending)
        assertEquals(1_700_000_000_000L, ascending.timeMillis)
        assertEquals(3, ascending.offset)
        val descending = HealthConnectPosition.decode("3400000000001")!!
        assertTrue(descending.descending)
        assertEquals(1_700_000_000_000L, descending.timeMillis)
        assertEquals(0, descending.offset)
        for (token in listOf("-1", "", "a:1", "1.5")) assertNull(token, HealthConnectPosition.decode(token))

        // And back: with no offset, also android14-release's token (time * 2, plus 1 if descending).
        assertEquals("108953116266496", HealthConnectPosition(false, 1_700_000_000_000L, 3).encode())
        assertEquals("3400000000001", HealthConnectPosition(true, 1_700_000_000_000L, 0).encode())
        assertEquals("3400000000000", HealthConnectPosition(false, 1_700_000_000_000L, 0).encode())
        assertThrows(IllegalArgumentException::class.java) { HealthConnectPosition(false, -1, 0).encode() }
    }

    private fun sessionsRequest(ascending: Boolean, pageSize: Int, token: String?) = ReadRecordsRequest(
        ExerciseSessionRecord::class, TimeRangeFilter.between(start, end), emptySet(), ascending, pageSize, token,
    )

    private companion object {
        const val OTHER = "com.example.other"
    }
}
