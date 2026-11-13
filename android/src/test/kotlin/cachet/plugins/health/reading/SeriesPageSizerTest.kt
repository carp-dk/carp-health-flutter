package cachet.plugins.health.reading

import cachet.plugins.health.reading.SeriesPageSizer.cap
import cachet.plugins.health.reading.SeriesPageSizer.firstRecords
import cachet.plugins.health.reading.SeriesPageSizer.nextRecords
import cachet.plugins.health.reading.SeriesPageSizer.shrinkForOversize
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
    fun shrinksAPageWithMoreThanTwicePageSizeSamples() {
        // 500 records grown on sparse data, then 6000 samples each: read 3 records (18,000 samples) instead.
        assertEquals(3, shrinkForOversize(500, 20000, 3_000_000))
        assertEquals(249, shrinkForOversize(500, 20000, 40_001))
        assertEquals(2499, shrinkForOversize(5000, 50000, 100_001))
        // Never below one record.
        assertEquals(1, shrinkForOversize(2, 1, 1_000_000))
    }

    @Test
    fun keepsAPageWithUpToTwicePageSizeSamplesOrOneRecord() {
        assertNull(shrinkForOversize(500, 20000, 40_000))
        assertNull(shrinkForOversize(500, 20000, 0))
        assertNull(shrinkForOversize(1, 20000, 1_000_000))
    }
}
