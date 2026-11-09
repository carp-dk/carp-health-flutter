package cachet.plugins.health.reading

import androidx.health.connect.client.records.HeartRateRecord
import java.time.Instant

/** The records of one heart rate page, and the token of the next page (null on the last). */
internal class HeartRatePage(val records: List<HeartRateRecord>, val next: SliceToken?)

/**
 * Reads heart rate page by page in time slices planned ahead from histograms of sample counts
 * ([HistogramPlanner]): every page holds the records that start in one slice (or part of them),
 * and every slice holds at most about the page size of samples. Each record belongs to the slice it
 * starts in, so none is returned twice. A slice is a Health Connect token chain of its own with a
 * fixed number of records per request, which is what the Health Connect APK (before Android 14) needs.
 */
internal class HeartRatePageReader(private val source: HeartRateSource, private val sdkInt: Int) {
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
                    // records that began earlier; none if the first histogram covered the whole read.
                    val earlier = when {
                        token != null -> emptyList()
                        window >= endMs - startMs -> emptyList()
                        else -> readEarlier(startMs, budget, source.countSamples(startMs, endMs), endMs)
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

        var page = source.read(sliceStart, sliceEnd, records, chainToken)
        // Records that run far past the slice can make a page much larger than counted: read the same
        // position with fewer records. The Health Connect APK cannot change that number inside a chain.
        var retries = 0
        while (retries < MAX_SHRINK_RETRIES && (chainToken == null || sdkInt >= 34)) {
            val raw = page.records.sumOf { it.samples.size.toLong() }.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
            records = SeriesPageSizer.shrinkForOversize(page.records.size, budget, raw) ?: break
            page = source.read(sliceStart, sliceEnd, records, chainToken)
            retries++
        }

        val inSlice = page.records.filter { startsIn(it, sliceStart, sliceEnd) }
        val earlier =
            if (token == null) {
                // Samples counted in the first slice that its records do not hold belong to records that
                // began before the read. Unknown if the slice takes more than one request.
                val missing = if (page.pageToken == null) counted!! - samplesIn(inSlice, startMs, sliceEnd) else null
                readEarlier(startMs, budget, missing, sliceEnd)
            } else {
                emptyList()
            }
        val next = when {
            page.pageToken != null -> SliceToken(sliceStart, span, sliceEnd, records, page.pageToken, plan)
            sliceEnd >= endMs -> null
            // The usual case: the next slice starts where this one ends.
            inSlice.isNotEmpty() && samplesIn(inSlice, sliceEnd, Long.MAX_VALUE) <= budget / 2 ->
                SliceToken(sliceEnd, span, plan = plan)
            // The next slices would mostly hold samples of records that began earlier (long records):
            // go on where the next record starts, or stop if none does.
            else -> source.firstStart(sliceEnd, endMs, newest = false)?.let { at ->
                SliceToken(at, span, plan = plan.filter { it > at })
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
            if (next < windowEnd) return Planned(from, SlicePlan(listOf(windowEnd), 0, window))
            from = next
        }
        return Planned(from, SlicePlan(listOf(minOf(end, from + window.coerceAtLeast(MIN_SLICE_MS))), 0, window))
    }

    /**
     * The records that began in the [SERIES_LOOKBACK] before [start] and reach it, oldest first.
     * Health Connect returns records by their start time only, so the read itself leaves them out.
     * The look-back range is read newest first, slice by slice, until the records found hold the
     * [missing] samples in [start, until) (null: unknown, so the whole range is read).
     */
    private suspend fun readEarlier(start: Long, budget: Int, missing: Long?, until: Long): List<HeartRateRecord> {
        if (missing != null && missing <= 0) return emptyList()
        // Nothing to look back at from a read that starts at the epoch, a common "everything" start.
        val length = start - maxOf(start - SERIES_LOOKBACK.toMillis(), 0L)
        val kept = mutableListOf<HeartRateRecord>()
        var found = 0L
        // Slices are planned on a mirrored axis, position = start - 1 - time, so that they go newest
        // first: positions [from, to) are the times [start - to, start - from).
        var cursor = 0L
        var span = length
        while (cursor < length && (missing == null || found < missing)) {
            // The record that reaches into the read has usually begun shortly before it: small first slice.
            val sliceBudget = if (cursor == 0L) maxOf(1, budget / 16) else budget
            val slice = SlicePlanner.plan(
                cursor,
                length,
                span,
                sliceBudget,
                { from, to -> source.countSamples(start - to, start - from) },
            ) { from, to -> source.firstStart(start - to, start - from, newest = true)?.let { start - 1 - it } }
            if (!slice.hasRecords) break
            val sliceFrom = start - slice.end
            val sliceTo = start - cursor
            var pageToken: String? = null
            do {
                val page = source.read(sliceFrom, sliceTo, HC_MAX_RECORDS, pageToken)
                for (record in page.records) {
                    if (startsIn(record, sliceFrom, sliceTo) && record.endTime.toEpochMilli() >= start) {
                        kept.add(record)
                        found += samplesIn(listOf(record), start, until)
                    }
                }
                pageToken = page.pageToken
            } while (pageToken != null)
            span = SlicePlanner.nextSpan(slice.end - cursor, slice.samples, budget)
            cursor = slice.end
        }
        return kept.sortedBy { it.startTime }
    }

    private fun startsIn(record: HeartRateRecord, from: Long, to: Long): Boolean =
        record.startTime.toEpochMilli().let { it >= from && it < to }

    private fun samplesIn(records: List<HeartRateRecord>, from: Long, to: Long): Long =
        records.sumOf { record -> record.samples.count { it.time.toEpochMilli().let { t -> t >= from && t < to } }.toLong() }
}
