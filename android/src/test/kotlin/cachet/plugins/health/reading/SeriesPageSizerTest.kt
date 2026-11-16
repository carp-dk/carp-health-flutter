package cachet.plugins.health.reading

import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.units.Velocity
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.reading.SeriesPageSizer.cap
import cachet.plugins.health.reading.SeriesPageSizer.firstRecords
import cachet.plugins.health.reading.SeriesPageSizer.nextRecords
import cachet.plugins.health.reading.SeriesPageSizer.shrinkForOversize
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SeriesPageSizerTest {
    @Test
    fun capsRecordsSoThatHourLongRecordsStillFitAPage() {
        assertEquals(5, cap(20000))
        assertEquals(13, cap(50000))
        assertEquals(1, cap(3599))
        assertEquals(1, cap(1))
    }

    @Test
    fun firstPageReadsOneRecordFromAndroid14() {
        assertEquals(1, firstRecords(34, 20000))
        assertEquals(1, firstRecords(37, 50000))
    }

    @Test
    fun firstPageBeforeAndroid14UsesTheCapForTheWholeChain() {
        assertEquals(5, firstRecords(33, 20000))
        assertEquals(13, firstRecords(26, 50000))
        assertEquals(1, firstRecords(33, 100))
    }

    @Test
    fun growsFourfoldUpToTheCap() {
        val sizes = mutableListOf(firstRecords(34, 50000))
        repeat(4) { sizes.add(nextRecords(sizes.last(), 50000, 1, 34)) }
        assertEquals(listOf(1, 4, 13, 13, 13), sizes)
    }

    @Test
    fun sizesByTheLargestRecord() {
        // 6000 samples per record (100 minutes at 1 Hz): 3 records hold 18,000 points.
        assertEquals(3, nextRecords(5, 20000, 6000, 34))
        assertEquals(4, nextRecords(1, 50000, 10000, 34))
        // A record larger than a page still moves on.
        assertEquals(1, nextRecords(5, 20000, 50000, 34))
    }

    @Test
    fun anEmptyPageCountsAsOneSamplePerRecord() {
        assertEquals(4, nextRecords(1, 20000, 0, 34))
    }

    @Test
    fun keepsTheSizeBeforeAndroid14() {
        assertEquals(5, nextRecords(5, 20000, 1, 33))
        assertEquals(5, nextRecords(5, 20000, 100_000, 33))
    }

    @Test
    fun shrinksAPageWithMoreThanTwicePageSizeSamplesToTheRecordsThatFit() {
        // 500 records of 6000 samples each: read the 3 that fit (18,000 samples) instead.
        assertEquals(3, shrinkForOversize(List(500) { 6000 }, 20000))
        // As on the Pixel 8a: 4096 records asked for, 735 came back, 635 of a sample and 100 of 6000. The
        // re-read was sized from the 4096 (136 records, all of a sample), now from what came back.
        assertEquals(635 + 3, shrinkForOversize(List(635) { 1 } + List(100) { 6000 }, 20000))
        assertEquals(20000, shrinkForOversize(List(40_001) { 1 }, 20000))
        // Never below one record.
        assertEquals(1, shrinkForOversize(listOf(1_000_000, 1), 1))
        assertEquals(1, shrinkForOversize(listOf(50_000, 1, 1), 20000))
    }

    @Test
    fun keepsAPageWithUpToTwicePageSizeSamplesOrOneRecord() {
        assertNull(shrinkForOversize(List(500) { 80 }, 20000))
        assertNull(shrinkForOversize(List(500) { 0 }, 20000))
        assertNull(shrinkForOversize(emptyList(), 20000))
        assertNull(shrinkForOversize(listOf(1_000_000), 20000))
    }

    @Test
    fun aSeriesPageIsReadAgainWithTheRecordsThatCameBackAndFit() {
        // 8 speed records of a sample, then one of 120,000: the third request asks for 13 records and gets 4.
        val start = Instant.parse("2026-11-01T00:00:00Z")
        val singles = (0 until 8).map { speed(start.plusSeconds(60L * it), 1, "s$it") }
        val records = singles + speed(start.plusSeconds(3600), 120_000, "long")
        val requests = mutableListOf<ReadRecordsRequest<*>>()
        val client = fakeRecordStore(SpeedRecord::class, records, requests)
        val replies = PageReplies(client).read(HealthConstants.SPEED, start, start.plusSeconds(86400 * 2), 50000)

        assertEquals(listOf(1, 4, 3, 120_000), replies.map { it.points.size })
        // Read again with the 3 that fit, not with 13 * 50000 / 120,003 = 5 records, which hold 4 again.
        val reads = requests.filter { it.timeRangeFilter.startTime == start }
        assertEquals(listOf(1, 4, 13, 3, 12), reads.map { it.pageSize })
    }

    /** A speed record from [from] with [samples] samples, one a second. */
    private fun speed(from: Instant, samples: Int, id: String): SpeedRecord {
        val speed = Velocity.metersPerSecond(2.0)
        val series = (0 until samples).map { SpeedRecord.Sample(from.plusSeconds(it.toLong()), speed) }
        val to = from.plusSeconds(maxOf(60L, samples.toLong()))
        return SpeedRecord(from, null, to, null, series, writtenBy(OWN_PACKAGE, id))
    }
}
