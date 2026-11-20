package cachet.plugins.health.reading

import java.time.Duration
import java.time.Instant
import java.util.TreeMap

/** The time [startTime, endTime) that a data point of the app [source] covers. */
internal class CoveredInterval(val startTime: Instant, val endTime: Instant, val source: String)

/** A bucket [startTime, endTime) of an interval read: the minutes its data covers, and the apps of that data. */
internal class BucketMinutes(val startTime: Instant, val endTime: Instant, val minutes: Double, val sources: List<String>)

/**
 * The minutes of each bucket that [intervals] cover, overlapping intervals counted once. The buckets
 * split [start, end) into [bucket]s from [start], the last one ending at [end]; intervals are clipped
 * to that range, and buckets they do not cover are left out. The sources of a bucket are those of the
 * intervals that cover part of it, each once, in the order the intervals start.
 */
internal fun minutesPerBucket(
    intervals: List<CoveredInterval>,
    start: Instant,
    end: Instant,
    bucket: Duration,
): List<BucketMinutes> {
    require(bucket >= Duration.ofMillis(1)) { "Buckets must be at least a millisecond long, not $bucket" }
    val from = start.toEpochMilli()
    val to = end.toEpochMilli()
    if (from >= to) return emptyList()
    // A bucket longer than the range is the whole range.
    val step = if (bucket > Duration.ofMillis(to - from)) to - from else bucket.toMillis()
    fun index(time: Long) = (time - from) / step
    fun bucketStart(index: Long) = from + index * step
    fun bucketEnd(index: Long) = minOf(bucketStart(index) + step, to)

    val clipped = intervals
        .mapNotNull { interval ->
            val clippedStart = maxOf(interval.startTime.toEpochMilli(), from)
            val clippedEnd = minOf(interval.endTime.toEpochMilli(), to)
            if (clippedStart < clippedEnd) Triple(clippedStart, clippedEnd, interval.source) else null
        }
        .sortedBy { it.first }

    val buckets = TreeMap<Long, CoveredBucket>()
    // In start order, the interval that ends last so far (at coveredUntil) began no later than the
    // current one: only the part of the current interval after coveredUntil is not counted yet.
    var coveredUntil = from
    for ((intervalStart, intervalEnd, source) in clipped) {
        for (index in index(intervalStart)..index(intervalEnd - 1)) {
            buckets.getOrPut(index) { CoveredBucket() }.sources.add(source)
        }
        val newStart = maxOf(intervalStart, coveredUntil)
        if (newStart < intervalEnd) {
            for (index in index(newStart)..index(intervalEnd - 1)) {
                buckets.getValue(index).coveredMillis +=
                    minOf(intervalEnd, bucketEnd(index)) - maxOf(newStart, bucketStart(index))
            }
            coveredUntil = intervalEnd
        }
    }
    return buckets.map { (index, covered) ->
        BucketMinutes(
            Instant.ofEpochMilli(bucketStart(index)),
            Instant.ofEpochMilli(bucketEnd(index)),
            covered.coveredMillis / 60_000.0,
            covered.sources.toList(),
        )
    }
}

private class CoveredBucket {
    var coveredMillis = 0L
    val sources = LinkedHashSet<String>()
}
