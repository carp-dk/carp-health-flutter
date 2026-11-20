package cachet.plugins.health.reading

import androidx.health.connect.client.records.HeartRateRecord
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue

/** The pages of a heart rate read, the Health Connect calls each made, and the fake it was read from. */
internal class HeartRateRead(val pages: List<HeartRatePage>, val calls: List<Int>, val source: FakeHeartRateSource) {
    val records get() = pages.flatMap { it.records }
    val maxRequest get() = source.reads.maxOf { it.samples }
}

/**
 * Reads [start, end) page by page from [source] on Android [sdkInt], sending each token back in its
 * encoded form, as Dart does; as a read of this app's own records if [ownOnly] ([source] holds only them).
 */
internal fun readHeartRate(
    source: FakeHeartRateSource,
    start: Long,
    end: Long,
    budget: Int,
    sdkInt: Int = 37,
    ownOnly: Boolean = false,
): HeartRateRead {
    val reader = HeartRatePageReader(source, sdkInt, ownOnly)
    val pages = mutableListOf<HeartRatePage>()
    val calls = mutableListOf<Int>()
    var token: String? = null
    do {
        val before = source.calls
        val page = runBlocking {
            reader.readPage(Instant.ofEpochMilli(start), Instant.ofEpochMilli(end), budget, SliceToken.decode(token))
        }
        pages += page
        calls += source.calls - before
        val next = page.next?.encode()
        assertTrue("The token did not move: $next", next == null || next != token)
        if (next != null) assertEquals(ownOnly, next.startsWith("o2:"))
        token = next
    } while (token != null && pages.size < 100_000)
    return HeartRateRead(pages, calls, source)
}

/** (record id, sample time) of each sample in [start, end) that [records] hold, as the converter keeps them. */
internal fun samplesOf(records: List<HeartRateRecord>, start: Long, end: Long): List<Pair<String, Long>> =
    records.flatMap { record ->
        record.samples.map { it.time.toEpochMilli() }.filter { it in start until end }.map { record.metadata.id to it }
    }.sortedWith(compareBy({ it.second }, { it.first }))

/**
 * Asserts that [read] holds every sample in [start, end) of [records] once, of the records that start in
 * it or in the [SERIES_LOOKBACK] before, and that no page made more than [MAX_HEART_RATE_PAGE_CALLS] calls.
 */
internal fun assertEverySampleOnce(records: List<HeartRateRecord>, read: HeartRateRead, start: Long, end: Long) {
    val lookback = start - SERIES_LOOKBACK.toMillis()
    val expected = records.filter { it.startTime.toEpochMilli() >= lookback }
    assertEquals(samplesOf(expected, start, end), samplesOf(read.records, start, end))
    assertTrue("${read.calls.max()} calls on a page", read.calls.all { it <= MAX_HEART_RATE_PAGE_CALLS })
}
