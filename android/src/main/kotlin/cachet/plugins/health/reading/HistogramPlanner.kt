package cachet.plugins.health.reading

/** Slices planned from one histogram: their ends, the samples in the first, and the page span seen. */
internal class SlicePlan(val ends: List<Long>, val firstSamples: Long, val pageSpan: Long)

/**
 * Plans several heart rate slices from one histogram of sample counts (one
 * aggregateGroupByDuration call). Counting the samples of a slice costs about 350 ms however short
 * it is, and a histogram of 64 buckets not much more (measured on a Pixel 8a with Android 17), so
 * one histogram for about [PLAN_PAGES] pages saves most of the time that counting each page would
 * cost. Slices end on bucket boundaries, so each holds at most the page size by the histogram's
 * exact counts. A bucket that alone holds more is planned again in finer buckets.
 */
internal object HistogramPlanner {
    /**
     * Slices from [cursor], each with at most [budget] samples, over the histogram of [cursor] to
     * [cursor] + [window] (at most [end]). Returns null when that range holds no samples.
     */
    suspend fun plan(
        cursor: Long,
        end: Long,
        window: Long,
        budget: Int,
        histogram: suspend (from: Long, to: Long, bucket: Long) -> List<Long>,
        depth: Int = 0,
    ): SlicePlan? {
        val to = minOf(end, cursor + window.coerceAtLeast(MIN_SLICE_MS))
        val bucket = ((to - cursor + PLAN_BUCKETS - 1) / PLAN_BUCKETS).coerceAtLeast(MIN_SLICE_MS)
        val counts = histogram(cursor, to, bucket)
        val total = counts.sum()
        if (total == 0L) return null
        // The span that holds a page at the density of this histogram, for the next plan.
        val pageSpan = ((to - cursor).toDouble() * budget / total).toLong().coerceAtLeast(MIN_SLICE_MS)

        val ends = ArrayList<Long>()
        var firstSamples = 0L
        var sliceStart = cursor
        var samples = 0L
        fun close(at: Long) {
            if (ends.isEmpty()) firstSamples = samples
            ends.add(at)
            sliceStart = at
            samples = 0
        }
        for ((i, count) in counts.withIndex()) {
            val bucketStart = cursor + i * bucket
            if (count > budget) {
                if (bucketStart > cursor) {
                    // Plan up to this bucket; the next plan starts with it.
                    if (bucketStart > sliceStart) close(bucketStart)
                    return SlicePlan(ends, firstSamples, pageSpan)
                }
                val bucketEnd = minOf(to, bucketStart + bucket)
                val finer = if (depth < MAX_PLAN_DEPTH && bucketEnd - bucketStart > MIN_SLICE_MS) {
                    plan(cursor, end, bucketEnd - bucketStart, budget, histogram, depth + 1)
                } else {
                    null
                }
                // Samples in the same second, from many records, cannot be split by time.
                return finer ?: SlicePlan(listOf(bucketEnd), count, pageSpan)
            }
            if (samples + count > budget) {
                close(bucketStart)
                if (ends.size == MAX_PLANNED_SLICES) return SlicePlan(ends, firstSamples, pageSpan)
            }
            samples += count
        }
        // The last slice goes on to the end of the window, over any buckets without samples.
        close(to)
        return SlicePlan(ends, firstSamples, pageSpan)
    }
}
