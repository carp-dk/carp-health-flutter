package cachet.plugins.health.reading

import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.WheelchairPushesRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Mass
import java.time.Instant
import kotlin.reflect.KClass
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [readPastTies] over records that share a start time, from a Health Connect whose page tokens lose count of
 * them ([tiedTokenStore]): every record comes once and in order, a page that ends inside the records of one
 * start time takes one more request for all of them, and no request carries an offset.
 */
class PageTokensTest {
    private val eight = Instant.parse("2016-11-02T08:00:00Z")
    private val range = TimeRangeFilter.between(eight.minusSeconds(7200), eight.plusSeconds(7200))
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    private fun at(minute: Int): Instant = eight.plusSeconds(60L * minute)

    // Steps records s1, s2, ... that start at these minutes after 08:00, in the order written.
    private fun steps(vararg minutes: Int): List<StepsRecord> = minutes.mapIndexed { i, minute ->
        StepsRecord(at(minute), null, at(minute).plusSeconds(60L + i), null, 10, writtenBy("app", "s${i + 1}"))
    }

    private fun ids(vararg numbers: Int) = numbers.map { "s$it" }

    private fun position(time: Instant, descending: Boolean = false) =
        HealthConnectPosition(descending, time.toEpochMilli(), 0).encode()

    /** The ids of each page and the tokens sent. */
    private class Chain(val pages: List<List<String>>, val sent: List<String?>)

    /** Reads [records] page by page with [readPastTies], as Health Connect pages them ([tiedTokenStore]). */
    private fun read(
        records: List<Record>,
        pageSize: Int,
        ascending: Boolean = true,
        filter: TimeRangeFilter = range,
        type: KClass<out Record> = StepsRecord::class,
    ): Chain {
        val client = tiedTokenStore(records, requests = requests)
        val pages = mutableListOf<List<String>>()
        val sent = mutableListOf<String?>()
        var token: String? = null
        do {
            val request = ReadRecordsRequest(type, filter, emptySet(), ascending, pageSize, token)
            val page = runBlocking { client.readPastTies(request) }
            pages += page.records.map { it.metadata.id }
            sent += token
            token = page.pageToken
        } while (token != null)
        assertTrue("${requests.map { it.pageToken }}", noOffsets(requests))
        return Chain(pages, sent)
    }

    @Test
    fun theMeasuredStepsComeOnceWithOneMoreRequest() {
        // Five records at 08:00 and one at 08:10: Health Connect's own tokens return s2 forever at pageSize 1.
        val records = steps(0, 0, 0, 0, 0, 10)
        val chain = read(records, pageSize = 1)
        assertEquals(listOf(ids(1, 2, 3, 4, 5), ids(6)), chain.pages)
        assertEquals(listOf(null, position(eight.plusMillis(1))), chain.sent)
        // The first page, the records of 08:00, and the second page.
        assertEquals(listOf(1, HC_MAX_RECORDS, 1), requests.map { it.pageSize })
        val tieRange = tieReads(requests).single().timeRangeFilter
        assertEquals(eight to eight.plusMillis(1), tieRange.startTime to tieRange.endTime)

        // Newest first, the records of 08:00 come in the order written, as Health Connect returns them.
        requests.clear()
        val newestFirst = read(records, pageSize = 1, ascending = false)
        assertEquals(listOf(ids(6), ids(1, 2, 3, 4, 5), emptyList()), newestFirst.pages)
        val sent = listOf(null, position(eight, descending = true), position(eight.minusMillis(1), descending = true))
        assertEquals(sent, newestFirst.sent)
        assertEquals(1, tieReads(requests).size)
    }

    @Test
    fun tiesOfDifferentStartTimesComeOnceInOrderAtEveryPageSize() {
        // Three at 08:00, five at 08:10, one at 08:20, and an instant record type the same way.
        val records = steps(0, 0, 0, 10, 10, 10, 10, 10, 20)
        val newestFirst = ids(9, 4, 5, 6, 7, 8, 1, 2, 3)
        val weights = listOf(0, 0, 0, 10, 10).mapIndexed { i, minute ->
            WeightRecord(at(minute), null, Mass.kilograms(70.0 + i), writtenBy("app", "w${i + 1}"))
        }
        for (pageSize in 1..10) {
            val chain = read(records, pageSize)
            assertEquals("$pageSize", ids(1, 2, 3, 4, 5, 6, 7, 8, 9), chain.pages.flatten())
            // One more request for each page that ended inside the records of one start time, which it then holds
            // all of, more than asked for; none for the others.
            assertEquals("$pageSize", chain.pages.count { it.size > pageSize }, tieReads(requests).size)
            requests.clear()
            assertEquals("$pageSize", newestFirst, read(records, pageSize, ascending = false).pages.flatten())
            val weighed = read(weights, pageSize, type = WeightRecord::class)
            assertEquals("$pageSize", (1..5).map { "w$it" }, weighed.pages.flatten())
            requests.clear()
        }
    }

    @Test
    fun groupsAtTheStartAndEndOfTheRangeComeOnceAndEndTheRead() {
        // Three records at the start of the range and three just before its end.
        val filter = TimeRangeFilter.between(at(0), at(30))
        val last = at(30).minusMillis(1)
        val records = steps(0, 0, 0) + List(3) { i ->
            StepsRecord(last, null, last.plusSeconds(60L + i), null, 10, writtenBy("app", "s${i + 4}"))
        }
        for (ascending in listOf(true, false)) {
            // The second group ends the read: the position past it is outside the range, so nothing more is read.
            val whole = read(records, pageSize = 4, ascending = ascending, filter = filter)
            val expected = if (ascending) ids(1, 2, 3, 4, 5, 6) else ids(4, 5, 6, 1, 2, 3)
            assertEquals(listOf(expected), whole.pages)
            assertEquals(listOf(4, HC_MAX_RECORDS), requests.map { it.pageSize })
            requests.clear()

            val pages = read(records, pageSize = 2, ascending = ascending, filter = filter).pages
            assertEquals(expected.chunked(3), pages)
            assertEquals(listOf(2, HC_MAX_RECORDS, 2, HC_MAX_RECORDS), requests.map { it.pageSize })
            requests.clear()
        }
    }

    @Test
    fun twoGroupsOneMillisecondApartComeOnce() {
        val next = eight.plusMillis(1)
        val records = steps(0, 0, 0) + List(3) { i ->
            StepsRecord(next, null, next.plusSeconds(60L + i), null, 10, writtenBy("app", "s${i + 4}"))
        }
        val ascending = read(records, pageSize = 2)
        assertEquals(listOf(ids(1, 2, 3), ids(4, 5, 6), emptyList()), ascending.pages)
        assertEquals(listOf(null, position(next), position(next.plusMillis(1))), ascending.sent)

        val newestFirst = read(records, pageSize = 2, ascending = false)
        assertEquals(listOf(ids(4, 5, 6), ids(1, 2, 3), emptyList()), newestFirst.pages)
        val sent = listOf(null, position(eight, descending = true), position(eight.minusMillis(1), descending = true))
        assertEquals(sent, newestFirst.sent)
    }

    @Test
    fun aGroupThatOneRequestCannotHoldFailsTheRead() {
        // 5000 records of one start time come whole in one request, which reads one more to tell; 5001 do not.
        val ninth = StepsRecord(at(60), null, at(61), null, 10, writtenBy("app", "nine"))
        val fits = tiedSteps(eight, HC_MAX_RECORDS) + ninth
        assertEquals(HC_MAX_RECORDS + 1, read(fits, pageSize = 10).pages.flatten().size)
        assertEquals(listOf(10, HC_MAX_RECORDS, 10), requests.map { it.pageSize })
        requests.clear()
        val more = tiedSteps(eight, HC_MAX_RECORDS + 1) + ninth
        val error = assertThrows(IllegalStateException::class.java) { read(more, pageSize = 10) }
        assertTrue(error.message!!, error.message!!.startsWith("More than 5000 StepsRecord records start at"))
        assertEquals(listOf(10, HC_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun aTokenThatCannotBeMovedPastFailsTheRead() {
        // The Health Connect APK (Android 13 and lower), whose tokens are not positions, returns the token it was sent.
        val apk = fakeHealthConnect { _, _ -> ReadRecordsResponse(steps(0), "CgYIARCAAQ") }
        fun apkPage(token: String?) =
            runBlocking { apk.readPastTies(ReadRecordsRequest(StepsRecord::class, range, emptySet(), true, 1, token)) }
        assertEquals("CgYIARCAAQ", apkPage(null).pageToken)
        val error = assertThrows(IllegalStateException::class.java) { apkPage("CgYIARCAAQ") }
        assertTrue(error.message!!, error.message!!.startsWith("Health Connect returned the same page token twice"))

        // A type whose time is not known here, whose page ended inside two records of 08:00: Health Connect's
        // token, which has an offset, is not followed.
        val pushes = WheelchairPushesRecord(eight, null, at(1), null, 5L, writtenBy("app", "p"))
        val tied = fakeHealthConnect { _, _ ->
            ReadRecordsResponse(listOf(pushes), HealthConnectPosition(false, eight.toEpochMilli(), 1).encode())
        }
        val request = ReadRecordsRequest(WheelchairPushesRecord::class, range, emptySet(), true, 1, null)
        val offset = assertThrows(IllegalStateException::class.java) { runBlocking { tied.readPastTies(request) } }
        assertTrue(offset.message!!, offset.message!!.startsWith("Health Connect returned a page token with an offset"))
    }
}
