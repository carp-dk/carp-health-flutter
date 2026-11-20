package cachet.plugins.health.reading

import android.os.Build
import androidx.health.connect.client.records.HeartRateRecord
import java.time.Instant

/** The records of one heart rate page, and the token of the next page (null on the last). */
internal class HeartRatePage(val records: List<HeartRateRecord>, val next: SliceToken?)

/**
 * Reads heart rate page by page in time slices planned ahead from histograms of sample counts
 * ([HistogramPlanner]): every page holds the records that start in one slice (or part of them),
 * and every slice holds at most about the page size of samples. Each record belongs to the slice it
 * starts in, so none is returned twice. A slice is a Health Connect token chain of its own
 * ([HeartRateChain]), with a fixed number of records per request on the Health Connect APK (before
 * Android 14), which needs that.
 *
 * Which records a page holds does not depend on the counts, only how large it is: Android 16 and
 * later count samples by their own time (another app's only if its record starts in the range, where
 * the app holds READ_HEALTH_DATA_HISTORY), Android 14 and 15 count records whole, where they start
 * ([HeartRateSource]). Records that began before the read are found by [HeartRateLookback].
 * Every page makes at most [MAX_HEART_RATE_PAGE_CALLS] Health Connect calls, whatever the data, and one
 * more for each read that ends inside the records of one start time ([readPastTies]).
 *
 * In the background, without READ_HEALTH_DATA_IN_BACKGROUND, Health Connect counts no samples (and
 * reads only the app's own records), so a read that goes to the background between pages fails there
 * with PERMISSION_DENIED, also a read of the app's own records.
 *
 * @param ownOnly Whether [source] reads this app's records only ([ownRecordsOnly]); its page tokens say so
 */
internal class HeartRatePageReader(
    private val source: HeartRateSource,
    private val sdkInt: Int,
    private val ownOnly: Boolean = false,
) {
    private val lookback = HeartRateLookback(source, sdkInt)

    // Whether the samples counted in a range are those whose time is in it, so that a count shows how
    // many samples of records that began earlier lie in the read: on Android 16 and later for the app's
    // own records only. With READ_HEALTH_DATA_HISTORY, another app's record that began before a range is
    // not counted in it at all: [T, T+1h) with a sample a minute counts 30 in [T-1h, T+30m) but none in
    // [T+30m, T+2h), the app's own 30 (measured on Android 16, module 361153320, and 17, 372042540).
    private val countsBySampleTime = ownOnly && sdkInt >= Build.VERSION_CODES.BAKLAVA

    /**
     * A reader of the records that the app [packageName] wrote only, for an app that may write heart
     * rate but not read it ([ReadAccess.OWN]): every Health Connect call asks for them only.
     */
    fun ownRecordsOnly(packageName: String): HeartRatePageReader =
        HeartRatePageReader(source.ownRecordsOnly(packageName), sdkInt, ownOnly = true)

    /**
     * Reads the page of [start, end) that [token] points to (null: the first page), with at most
     * about [budget] samples. The first page also holds the records that began before [start] but
     * reach into the read; the caller cuts every record's samples to [start, end).
     */
    suspend fun readPage(start: Instant, end: Instant, budget: Int, token: SliceToken?): HeartRatePage {
        val startMs = start.toEpochMilli()
        val endMs = end.toEpochMilli()
        val chainToken = token?.healthConnectToken
        var sliceStart: Long
        val sliceEnd: Long
        var span: Long
        var plan: List<Long>
        var records: Int
        var counted: Long? = null
        if (token != null && chainToken != null) {
            // More records start in the current slice than the last request returned.
            sliceStart = token.cursor
            sliceEnd = token.sliceEnd!!
            records = token.records!!
            span = token.span
            plan = token.plan
        } else {
            sliceStart = token?.cursor ?: startMs
            require(sliceStart < endMs) { "Page token ${token?.encode()} is past the end of the read" }
            span = token?.span ?: 0L
            plan = token?.plan ?: emptyList()
            if (plan.isEmpty()) {
                val window = if (token == null) minOf(endMs - sliceStart, FIRST_PLAN_WINDOW_MS) else span * PLAN_PAGES
                val planned = planFrom(sliceStart, endMs, window, budget)
                if (planned == null) {
                    // No record starts in the rest of the read. On the first page, samples in it belong to
                    // records that began earlier; none if the first histogram counted none in the whole read.
                    val earlier = when {
                        token != null -> emptyList()
                        !countsBySampleTime -> lookback.find(startMs, budget, null, endMs)
                        window >= endMs - startMs -> emptyList()
                        else -> lookback.find(startMs, budget, source.countSamples(startMs, endMs), endMs)
                    }
                    return HeartRatePage(earlier, null)
                }
                sliceStart = planned.cursor
                plan = planned.plan.ends
                span = planned.plan.pageSpan
                counted = planned.plan.firstSamples
            }
            sliceEnd = plan.first()
            plan = plan.drop(1)
            records = HC_MAX_RECORDS
        }

        // Records that run far past the slice can make a page much larger than counted: it is read again
        // with fewer records.
        val read = HeartRateChain.read(source, sliceStart, sliceEnd, records, chainToken, budget, sdkInt)
        val page = read.page
        val inSlice = page.records.filter { startsIn(it, sliceStart, sliceEnd) }
        val earlier = when {
            token != null -> emptyList()
            // Where samples are counted by their time and this page is the whole read, the samples counted
            // that its records do not hold are those of records that began earlier.
            countsBySampleTime && sliceStart == startMs && sliceEnd >= endMs && page.pageToken == null ->
                lookback.find(startMs, budget, counted!! - samplesIn(inSlice, startMs, sliceEnd), sliceEnd)
            // A count of part of the read rules out no record that began earlier: it may have no sample in
            // that part and some after it.
            else -> lookback.find(startMs, budget, null, endMs)
        }
        val next = when {
            page.pageToken != null -> {
                // Never fewer, so that a chain that had to read a long record alone goes on at full speed
                // after it; a request that holds too much is read again with fewer.
                val largest = page.records.maxOfOrNull { it.samples.size } ?: 0
                val more = maxOf(read.records, HeartRateChain.nextRecords(read.records, largest, budget, sdkInt))
                SliceToken(sliceStart, span, sliceEnd, more, page.pageToken, plan, ownOnly)
            }
            sliceEnd >= endMs -> null
            // The usual case: the next slice starts where this one ends.
            inSlice.isNotEmpty() && samplesIn(inSlice, sliceEnd, Long.MAX_VALUE) <= budget / 2 ->
                SliceToken(sliceEnd, span, plan = plan, ownOnly = ownOnly)
            // The next slices would mostly hold samples of records that began earlier (long records):
            // go on where the next record starts, or stop if none does.
            else -> source.firstStart(sliceEnd, endMs, newest = false)?.let { at ->
                SliceToken(at, span, plan = plan.filter { it > at }, ownOnly = ownOnly)
            }
        }
        return HeartRatePage(earlier + inSlice, next)
    }

    private class Planned(val cursor: Long, val plan: SlicePlan)

    /**
     * Plans the slices from [cursor] over about [window] ms. A range without samples is skipped up to
     * the next record start, found with one read of one record. Null if no record starts in
     * [cursor, end).
     */
    private suspend fun planFrom(cursor: Long, end: Long, window: Long, budget: Int): Planned? {
        var from = cursor
        repeat(2) {
            HistogramPlanner.plan(from, end, window, budget, source::histogram)?.let { return Planned(from, it) }
            val next = source.firstStart(from, end, newest = false) ?: return null
            val windowEnd = minOf(end, from + window.coerceAtLeast(MIN_SLICE_MS))
            // A record starts in the window but has no samples there: read the window.
            if (next < windowEnd) return Planned(from, SlicePlan(listOf(windowEnd), listOf(0L), window))
            from = next
        }
        val windowEnd = minOf(end, from + window.coerceAtLeast(MIN_SLICE_MS))
        return Planned(from, SlicePlan(listOf(windowEnd), listOf(0L), window))
    }
}
