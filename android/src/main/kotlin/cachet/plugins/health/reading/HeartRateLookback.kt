package cachet.plugins.health.reading

import android.util.Log
import androidx.health.connect.client.records.HeartRateRecord
import java.time.Instant

/**
 * Finds the heart rate records that began in the [SERIES_LOOKBACK] before the start of a read and
 * reach into it, for its first page: Health Connect returns series records by their start time only,
 * so the read itself leaves them out. The look-back range is read newest first, in slices of at most
 * [LOOKBACK_SLICE_SAMPLES] samples (or the page size, if larger) planned from histograms
 * ([HistogramPlanner]), and the records that reach the start are kept.
 *
 * In a read of the app's own records of one page on Android 16 and later, which count those samples
 * by their own time, the caller knows how many samples of such records lie in the read, and the
 * search stops once they are found, usually after one slice. Otherwise the whole range is read: a
 * record that began earlier may have no sample in the part of the read that was counted and some
 * after it, Android 14 and 15 count each record whole, where it starts, and Android 16 and 17 do not
 * count another app's record that began before the range at all where the app holds
 * READ_HEALTH_DATA_HISTORY ([HeartRateSource]). Either way the search makes at most
 * [MAX_LOOKBACK_CALLS] Health Connect calls (one more where its last read ends inside the records of
 * one start time, [readPastTies]); a range that takes more is read only in part, newest first, and a
 * warning is logged.
 */
internal class HeartRateLookback(private val source: HeartRateSource, private val sdkInt: Int) {
    /**
     * The records that began in the look-back range before [start] and end at or after it, oldest
     * first, until those found hold [missing] samples in [start, until) (null: unknown, so the whole
     * range is read). Times are epoch ms.
     */
    suspend fun find(start: Long, budget: Int, missing: Long?, until: Long): List<HeartRateRecord> {
        if (missing != null && missing <= 0) return emptyList()
        val search = Search(start, until, missing, maxOf(budget, LOOKBACK_SLICE_SAMPLES))
        try {
            search.run()
        } catch (e: CallsSpent) {
            Log.w(
                "FLUTTER_HEALTH",
                "HEART_RATE: stopped looking for records that began before ${Instant.ofEpochMilli(start)} after " +
                    "$MAX_LOOKBACK_CALLS Health Connect calls, at ${Instant.ofEpochMilli(search.reached)}",
            )
        }
        return search.kept.sortedBy { it.startTime }
    }

    /** One search from [start]: the records kept so far, and how far back it has read. */
    private inner class Search(val start: Long, val until: Long, val missing: Long?, val sliceBudget: Int) {
        val kept = mutableListOf<HeartRateRecord>()
        var reached = start
        private var found = 0L
        private val limited = LimitedSource(source)
        private val done get() = missing != null && found >= missing

        suspend fun run() {
            // Nothing to look back at from a read that starts at the epoch, a common "everything" start.
            val length = start - maxOf(start - SERIES_LOOKBACK.toMillis(), 0L)
            // Slices are planned on a mirrored axis, position = start - 1 - time, so that they go newest
            // first: positions [from, to) are the times [start - to, start - from).
            var cursor = 0L
            while (cursor < length && !done) {
                // A bucket that alone holds more than a slice is not split: on Android 14 and 15 that is one
                // long record (or records that start together), which no finer histogram splits.
                val plan =
                    HistogramPlanner.plan(cursor, length, length - cursor, sliceBudget, ::histogram, split = false)
                // Nothing counted in the rest: read it whole, for records whose samples all lie later.
                val slices = plan?.ends?.zip(plan.samples) ?: listOf(length to null)
                for ((end, samples) in slices) {
                    // Records per request: as many as Health Connect allows where the counts bound a slice; a few
                    // to begin with where they do not, or the slice holds more than a slice of samples (one on
                    // Android 14 and later, where the next requests ask for more).
                    val records =
                        if (samples != null && samples <= sliceBudget) HC_MAX_RECORDS
                        else SeriesPageSizer.firstRecords(sdkInt, sliceBudget)
                    readSlice(start - end, start - cursor, records)
                    cursor = end
                    if (done) break
                }
            }
        }

        /**
         * The histogram of the positions [from, to) in buckets of [bucket] ms, as [HistogramPlanner] asks
         * for it. Health Connect cuts a range into buckets from its start, so the times asked for begin a
         * whole number of buckets before start - from, and the last bucket may reach a little before
         * [to]. Zeros where that would be before the epoch, so that the rest is read whole.
         */
        private suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long> {
            val buckets = ((to - from + bucket - 1) / bucket).toInt()
            val latest = start - from
            val earliest = latest - buckets * bucket
            if (earliest < 0) return List(buckets) { 0L }
            return limited.histogram(earliest, latest, bucket).reversed()
        }

        /** Reads the records that start in [from, to), [first] in the first request; keeps those that reach [start]. */
        private suspend fun readSlice(from: Long, to: Long, first: Int) {
            var records = first
            var token: String? = null
            do {
                // Not read again with fewer records when it holds more than counted: it has been read, and only
                // the records that reach the start are kept. The next request asks for fewer instead.
                val page = limited.read(from, to, records, token)
                for (record in page.records) {
                    if (startsIn(record, from, to) && record.endTime.toEpochMilli() >= start) {
                        kept.add(record)
                        found += samplesIn(listOf(record), start, until)
                    }
                }
                val largest = page.records.maxOfOrNull { it.samples.size } ?: 0
                records = HeartRateChain.nextRecords(records, largest, sliceBudget, sdkInt)
                token = page.pageToken
            } while (token != null && !done)
            reached = from
        }
    }
}

/** Thrown when a look-back has made its [MAX_LOOKBACK_CALLS] calls. */
private class CallsSpent : RuntimeException()

/** The calls of [source], at most [MAX_LOOKBACK_CALLS] of them (and one more, [read]); then [CallsSpent]. */
private class LimitedSource(private val source: HeartRateSource) : HeartRateSource {
    private var calls = 0

    private fun spend() {
        if (calls >= MAX_LOOKBACK_CALLS) throw CallsSpent()
        calls++
    }

    override suspend fun countSamples(from: Long, to: Long): Long {
        spend()
        return source.countSamples(from, to)
    }

    override suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long> {
        spend()
        return source.histogram(from, to, bucket)
    }

    // A read that ends inside the records of one start time makes one more call for them ([pastTies]): it counts
    // after the read, so the last read may take the look-back one call past its limit.
    override suspend fun read(from: Long, to: Long, records: Int, pageToken: String?): HeartRateRecords {
        spend()
        return source.read(from, to, records, pageToken).also { if (it.tied > 0) calls++ }
    }

    override suspend fun firstStart(from: Long, to: Long, newest: Boolean): Long? {
        spend()
        return source.firstStart(from, to, newest)
    }

    override fun ownRecordsOnly(packageName: String): HeartRateSource = source.ownRecordsOnly(packageName)
}
