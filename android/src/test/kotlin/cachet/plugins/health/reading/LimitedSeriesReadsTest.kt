package cachet.plugins.health.reading

import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Velocity
import cachet.plugins.health.HealthConstants
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Reads of a series type with a 'limit' are paged like reads without one, newest first: a record
 * may hold an hour of 1 Hz samples, so a request asks for few of them ([SeriesPageSizer]). The JVM
 * tests read as on Android 13 and lower (Build.VERSION.SDK_INT is 0 there).
 */
class LimitedSeriesReadsTest {
    private val reads = SleepReads()
    private val start = Instant.parse("2026-11-08T09:00:00Z")
    private val end = start.plusSeconds(7200)

    // Three records of 30 minutes with a sample a minute, from 09:00, 09:30 and 10:00.
    private val speeds = (0..2).map { i ->
        val from = start.plusSeconds(1800L * i)
        val samples = (0 until 30).map { SpeedRecord.Sample(from.plusSeconds(60L * it), Velocity.metersPerSecond(2.0)) }
        SpeedRecord(from, null, from.plusSeconds(1800), null, samples, Metadata.manualEntryWithId("speed$i"))
    }

    @Test
    fun aLimitedReadAsksForFewRecordsAndGoesOnWithTheToken() {
        val client = fakeRecordStore(SpeedRecord::class, speeds, reads.requests)
        // As Dart reads: pages of at most 'limit' points, until it has 'limit' of them.
        val read = reads.pages(HealthConstants.SPEED, start, end, client, pageSize = 50, limit = 50)

        // The samples of the record that starts last, then those of the one before it. One request
        // used to ask for 50 records, up to 180,000 samples of records of an hour of 1 Hz samples.
        assertEquals(listOf(30, 30), read.pages.map { it.size })
        assertEquals(start.plusSeconds(3600), read.pages.first().first().from)
        assertEquals(listOf(null, "1"), reads.requests.map { it.pageToken })
        assertEquals(1, SeriesPageSizer.cap(50))
        assertTrue(reads.requests.all { !it.ascendingOrder && it.pageSize <= SeriesPageSizer.cap(50) })
    }

    @Test
    fun aLimitedPageHealthConnectCannotReturnIsReadAgainWithFewerRecords() {
        // As Health Connect fails for a cursor of more than 100,000 rows.
        val tooMany = IllegalStateException("Too many records in the cursor. Max allowed: 100000")
        val client = fakeRecordStore(SpeedRecord::class, speeds, reads.requests) { request ->
            tooMany.takeIf { request.pageSize > 1 }
        }
        val read = reads.pages(HealthConstants.SPEED, start, end, client, pageSize = 20_000, limit = 20_000)

        // Five records (SeriesPageSizer.cap(20000)) failed and were read again one by one, newest first.
        assertEquals(listOf(5, 1, 1, 1), reads.requests.map { it.pageSize })
        assertEquals(listOf(null, null, "1", "2"), reads.requests.map { it.pageToken })
        assertTrue(reads.requests.none { it.ascendingOrder })
        assertEquals(listOf(30, 30, 30), read.pages.map { it.size })
        assertEquals(listOf(3600L, 1800L, 0L), read.pages.map { it.first().from.epochSecond - start.epochSecond })
    }
}
