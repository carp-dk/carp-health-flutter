package cachet.plugins.health.reading

import java.time.Duration
import java.time.Instant
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class MinutesPerBucketTest {
    private val start = Instant.parse("2026-11-08T00:00:00Z")
    private val hour = Duration.ofHours(1)

    private fun at(minutes: Long): Instant = start.plus(Duration.ofMinutes(minutes))

    private fun covered(from: Long, to: Long, source: String = "app") = CoveredInterval(at(from), at(to), source)

    // Each bucket as (start minute, end minute, minutes covered).
    private fun List<BucketMinutes>.spans() = map { Triple(minuteOf(it.startTime), minuteOf(it.endTime), it.minutes) }

    private fun minuteOf(time: Instant) = Duration.between(start, time).toMinutes()

    @Test
    fun anIntervalIsSplitAtTheBucketBoundaries() {
        val buckets = minutesPerBucket(listOf(covered(30, 150)), start, at(240), hour)
        assertEquals(listOf(Triple(0L, 60L, 30.0), Triple(60L, 120L, 60.0), Triple(120L, 180L, 30.0)), buckets.spans())
    }

    @Test
    fun overlappingIntervalsAreCountedOnce() {
        // Out of order, one inside another, one overlapping its end and one touching that.
        val intervals = listOf(covered(40, 50), covered(10, 70), covered(60, 90), covered(90, 100))
        val buckets = minutesPerBucket(intervals, start, at(120), hour)
        assertEquals(listOf(Triple(0L, 60L, 50.0), Triple(60L, 120L, 40.0)), buckets.spans())
    }

    @Test
    fun bucketsWithoutDataAreLeftOut() {
        val buckets = minutesPerBucket(listOf(covered(0, 15), covered(200, 215)), start, at(300), hour)
        assertEquals(listOf(Triple(0L, 60L, 15.0), Triple(180L, 240L, 15.0)), buckets.spans())
    }

    @Test
    fun intervalsAreClippedToTheRange() {
        // A session that began the evening before, one that ends after the range, and one outside it.
        val intervals = listOf(covered(-120, 20), covered(100, 400), covered(-300, -200), covered(130, 130))
        val buckets = minutesPerBucket(intervals, start, at(120), hour)
        assertEquals(listOf(Triple(0L, 60L, 20.0), Triple(60L, 120L, 20.0)), buckets.spans())
    }

    @Test
    fun theLastBucketEndsAtTheEnd() {
        val buckets = minutesPerBucket(listOf(covered(0, 150)), start, at(150), hour)
        assertEquals(listOf(Triple(0L, 60L, 60.0), Triple(60L, 120L, 60.0), Triple(120L, 150L, 30.0)), buckets.spans())
    }

    @Test
    fun aBucketLongerThanTheRangeIsTheWholeRange() {
        val buckets = minutesPerBucket(listOf(covered(10, 20)), start, at(90), Duration.ofDays(36_500))
        assertEquals(listOf(Triple(0L, 90L, 10.0)), buckets.spans())
    }

    @Test
    fun minutesAreNotRounded() {
        val interval = CoveredInterval(start, start.plusSeconds(90), "app")
        assertEquals(1.5, minutesPerBucket(listOf(interval), start, at(60), hour).single().minutes, 0.0)
    }

    @Test
    fun theSourcesOfABucketAreTheAppsThatCoverPartOfIt() {
        val intervals = listOf(covered(70, 80, "b"), covered(10, 60, "a"), covered(20, 30, "b"), covered(30, 65, "a"))
        val buckets = minutesPerBucket(intervals, start, at(120), hour)
        // Each once, in the order the intervals start: in the second bucket "a" (30-65) before "b" (70-80).
        assertEquals(listOf(listOf("a", "b"), listOf("a", "b")), buckets.map { it.sources })
        // An interval that ends where a bucket starts covers none of it.
        assertEquals(listOf(listOf("a")), minutesPerBucket(listOf(covered(0, 60, "a")), start, at(120), hour).map { it.sources })
    }

    @Test
    fun emptyRangesHaveNoBuckets() {
        assertTrue(minutesPerBucket(listOf(covered(0, 60)), start, start, hour).isEmpty())
        assertTrue(minutesPerBucket(listOf(covered(0, 60)), at(60), start, hour).isEmpty())
        assertTrue(minutesPerBucket(emptyList(), start, at(60), hour).isEmpty())
    }

    @Test
    fun bucketsMustBeAtLeastAMillisecond() {
        for (bucket in listOf(Duration.ZERO, Duration.ofSeconds(-60), Duration.ofNanos(999_999))) {
            assertThrows(IllegalArgumentException::class.java) {
                minutesPerBucket(listOf(covered(0, 60)), start, at(60), bucket)
            }
        }
    }

    @Test
    fun matchesCountingEverySecond() {
        // Random intervals on a 20-minute range, second by second against 70-second buckets.
        val random = Random(526)
        val seconds = 1200
        val bucket = 70
        val end = start.plusSeconds(seconds.toLong())
        repeat(50) {
            val intervals = List(random.nextInt(1, 12)) {
                val from = random.nextInt(-100, seconds + 100).toLong()
                val to = from + random.nextInt(0, 300)
                CoveredInterval(start.plusSeconds(from), start.plusSeconds(to), "app${random.nextInt(3)}")
            }
            val expected = (0 until seconds).groupBy { it / bucket }.mapNotNull { (index, inBucket) ->
                // The intervals that cover each second of the bucket.
                val coveredBy = inBucket.map { second ->
                    val time = start.plusSeconds(second.toLong())
                    intervals.filter { !time.isBefore(it.startTime) && time.isBefore(it.endTime) }
                }
                val covered = coveredBy.count { it.isNotEmpty() }
                val sources = coveredBy.flatten().map { it.source }.toSet()
                if (covered == 0) null else Triple(index.toLong() * bucket, covered / 60.0, sources)
            }
            val buckets = minutesPerBucket(intervals, start, end, Duration.ofSeconds(bucket.toLong()))
            assertEquals(
                expected,
                buckets.map { Triple(Duration.between(start, it.startTime).seconds, it.minutes, it.sources.toSet()) },
            )
        }
    }
}
