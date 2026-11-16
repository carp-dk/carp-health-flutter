package cachet.plugins.health.reading

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthConstants
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A getDataPage page that Android 14 or 15 had to read again with the rest of the range ([readRecordsPage])
 * replies only the sessions it asked for, and every further one of the last one's start time; the next page
 * starts at the first one left out ([RecordsPage.cut]) and may have to be read again in turn.
 */
class RouteOutsidePageCutTest {
    private val start = Instant.parse("2026-10-20T00:00:00Z")
    private val end = start.plusSeconds(86400)
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    private fun at(hour: Int): Instant = start.plusSeconds(3600L * hour)

    // Each of its own app, so that its point tells which session it is.
    private fun sessions(vararg hours: Int, routes: Set<Int> = emptySet()): List<ExerciseSessionRecord> =
        hours.mapIndexed { i, hour -> runSession("s$i", at(hour), route = i in routes, packageName = "app.s$i") }

    @Test
    fun aChainOfPagesReadAgainRepliesEverySessionOnceInOrder() {
        // Three workouts a page; the first at 13:00 has a route. The third page ends in the middle of 13:00, whose
        // sessions one more request reads whole, so that page holds four and needs no read again.
        val runs = sessions(7, 8, 9, 9, 10, 11, 11, 11, 12, 13, 13, 13, 14, 15, 16, routes = setOf(9))
        val types = listOf(ExerciseSessionRecord::class, DistanceRecord::class, TotalCaloriesBurnedRecord::class)
        val granted = (types + StepsRecord::class).mapTo(HashSet()) { HealthPermission.getReadPermission(it) }
        val replies = PageReplies(fakeSessionStore(runs, requests, granted), sdkInt = 35)
            .read(HealthConstants.WORKOUT, start, end, pageSize = 3)

        // Every page holds the sessions of its last start time: 9:00 and 11:00 are not split.
        val pages = replies.map { page -> page.points.map { it.source } }
        val ids = listOf(0..3, 4..7, 8..11, 12..14).map { page -> page.map { "app.s$it" } }
        assertEquals(ids, pages)
        assertTrue(replies.all { it.error == null } && replies.last().token == null)

        val reads = requests.filter { it.recordType == ExerciseSessionRecord::class }
        assertEquals(listOf(3, HC_MAX_RECORDS, 3, HC_MAX_RECORDS, 3, HC_MAX_RECORDS, 3), reads.map { it.pageSize })
        fun token(at: Instant) = HealthConnectPosition(false, at.toEpochMilli(), 0).encode()
        val tokens = listOf(null, null, token(at(10)), token(at(10)), token(at(12)), null, token(at(13).plusMillis(1)))
        assertEquals(tokens, reads.map { it.pageToken })
        assertEquals(at(13) to at(13).plusMillis(1), reads[5].timeRangeFilter.let { it.startTime to it.endTime })

        // Each page reads the totals (distance, energy, steps) of its own workouts only, each once.
        val totals = requests.fold(mutableListOf<MutableList<Instant>>()) { perPage, request ->
            if (request.recordType != ExerciseSessionRecord::class) {
                perPage.last() += request.timeRangeFilter.startTime!!
            } else if (perPage.lastOrNull()?.isEmpty() != true) {
                perPage += mutableListOf<Instant>()
            }
            perPage
        }
        assertEquals(replies.map { page -> page.points.flatMap { point -> List(3) { point.from } } }, totals)
    }

    @Test
    fun aPageIsCutAfterTheSessionsOfItsLastStartTime() {
        val runs = sessions(7, 8, 8, 8, 9, 10, routes = setOf(5))
        val page = RecordsPage(runs, null, reread = true)

        val cut = page.cut(2, descending = false)
        assertEquals(listOf("s0", "s1", "s2", "s3"), cut.records.map { it.metadata.id })
        assertTrue(cut.reread)
        val position = HealthConnectPosition.decode(cut.pageToken!!)!!
        assertEquals(false to 0, position.descending to position.offset)
        assertEquals(at(9).toEpochMilli(), position.timeMillis)
        // From that token, Health Connect reads the sessions left out, and no other.
        val request = ReadRecordsRequest(
            ExerciseSessionRecord::class, TimeRangeFilter.between(start, end), emptySet(), true, 3, cut.pageToken,
        )
        val rest = runBlocking { fakeSessionStore(runs).readRecordsPage(request, 35) }
        assertEquals(listOf("s4", "s5"), rest.records.map { it.metadata.id })
        assertNull(rest.pageToken)

        // Newest first, the token reads the sessions that start at or before the first one left out.
        val newestFirst = RecordsPage(runs.reversed(), null, reread = true).cut(1, descending = true)
        assertEquals(listOf("s5"), newestFirst.records.map { it.metadata.id })
        assertEquals(HealthConnectPosition(true, at(9).toEpochMilli(), 0).encode(), newestFirst.pageToken)

        // Uncut: no more sessions than asked for, only more of the last one's start time, or before 1970.
        assertSame(page, page.cut(6, descending = false))
        val ties = RecordsPage(runs.take(4), "42", reread = true)
        assertSame(ties, ties.cut(2, descending = false))
        val early = RecordsPage(
            listOf(runSession("x", Instant.EPOCH, false), runSession("y", Instant.EPOCH.minusSeconds(60), false)),
            null,
            reread = true,
        )
        assertSame(early, early.cut(1, descending = true))
    }
}
