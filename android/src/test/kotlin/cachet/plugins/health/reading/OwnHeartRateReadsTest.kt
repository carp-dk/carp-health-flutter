package cachet.plugins.health.reading

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import cachet.plugins.health.HealthConstants
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Heart rate read with only the write permission ([ReadAccess.OWN]): in time slices planned from counts
 * of the app's own samples, which Health Connect allows since Android 14 QPR2 when every call asks for
 * the app's records only; by record, at most [SeriesPageSizer.cap] records a call, where it refuses.
 */
class OwnHeartRateReadsTest {
    private val start = Instant.parse("2026-11-01T00:00:00Z")
    private val calls = mutableListOf<HeartRateCall>()
    private val writeHeartRate = setOf(HealthPermission.getWritePermission(HeartRateRecord::class))

    @Test
    fun aSlicedReadOfTheAppsOwnHeartRateAsksForItOnEveryCall() {
        // The app's record that began 10 minutes before the read, its records a minute, and an hour at 1 Hz;
        // another app's records every 30 seconds and its own hour.
        val own = listOf(heartRate(start.minusSeconds(600), 1200, "own-early")) +
            (0 until 1440).map { heartRate(start.plusSeconds(60L * it), 1, "own$it") } +
            heartRate(start.plusSeconds(12 * 3600L), 3600, "own-hour")
        val other = (0 until 2880).map { heartRate(start.plusSeconds(30L * it), 1, "other$it", OTHER) } +
            heartRate(start.plusSeconds(6 * 3600L), 3600, "other-hour", OTHER)
        val client = fakeHeartRateStore(own + other, calls, writeHeartRate)
        val replies = PageReplies(client).read(HealthConstants.HEART_RATE, start, start.plusSeconds(86400), 1000)

        assertNull(replies.last().error)
        assertEquals(600 + 1440 + 3600, replies.sumOf { it.points.size })
        assertTrue(replies.flatMap { it.points }.all { it.source == OWN_PACKAGE })
        assertTrue(replies.size > 1)
        assertTrue(replies.all { it.permissionDenied == true })
        // Later pages carry the slice tokens of a read of the app's own records.
        assertTrue(replies.dropLast(1).all { it.token!!.startsWith("o2:") })
        // The counts that plan the slices and every read ask for the app's records only.
        assertTrue(calls.any { it.method == "aggregateGroupByDuration" } && calls.any { it.method == "readRecords" })
        assertTrue(calls.all { it.origins == setOf(DataOrigin(OWN_PACKAGE)) })
    }

    @Test
    fun aWeekOfTheAppsOwnHeartRateAMinuteTakesAFewCalls() {
        // writeHealthData writes one sample per record: by record, 5 a call, that was 2017 calls.
        val minutes = 7 * 24 * 60
        val records = (0 until minutes).map { heartRate(start.plusSeconds(60L * it), 1, "hr$it") }
        val client = fakeHeartRateStore(records, calls, writeHeartRate)
        val replies = PageReplies(client).read(HealthConstants.HEART_RATE, start, start.plusSeconds(60L * minutes))

        assertNull(replies.last().error)
        assertEquals(minutes, replies.sumOf { it.points.size })
        assertTrue("${calls.size} calls", calls.size <= 10)
        assertTrue(calls.all { it.origins == setOf(DataOrigin(OWN_PACKAGE)) })
    }

    @Test
    fun whereHealthConnectDoesNotCountTheAppsSamplesTheReadGoesByRecord() {
        // Android 14 before QPR2 (34) and the Health Connect APK (33) count samples only with read permission.
        val own = (0 until 120).map { heartRate(start.plusSeconds(60L * it), 1, "own$it") }
        val other = (0 until 120).map { heartRate(start.plusSeconds(60L * it + 30), 1, "other$it", OTHER) }
        for (sdkInt in listOf(34, 33)) {
            calls.clear()
            val client = fakeHeartRateStore(own + other, calls, writeHeartRate, countsNeedRead = true)
            val replies =
                PageReplies(client, sdkInt = sdkInt).read(HealthConstants.HEART_RATE, start, start.plusSeconds(7200))

            assertNull(replies.last().error)
            assertEquals(120, replies.sumOf { it.points.size })
            assertTrue(replies.flatMap { it.points }.all { it.source == OWN_PACKAGE })
            assertTrue(replies.all { it.permissionDenied == true })
            assertTrue(replies.dropLast(1).all { it.token!!.startsWith("o1:") })
            // Only reads of the app's records, at most the cap of a read by record each.
            assertTrue(calls.all { it.method == "readRecords" && it.origins == setOf(DataOrigin(OWN_PACKAGE)) })
            assertTrue(calls.all { it.pageSize <= SeriesPageSizer.cap(DEFAULT_PAGE_SIZE) })
        }
    }

    @Test
    fun thePixelsMixedDataIsReadInPagesOfAboutPageSize() {
        // As on the Pixel 8a: 2000 records of a sample each, then 100 records of 6000 samples, all the app's.
        val singles = (0 until 2000).map { heartRate(start.plusSeconds(60L * it), 1, "hr$it") }
        val long = (0 until 100).map { heartRate(start.plusSeconds(2000 * 60L + 6000L * it), 6000, "long$it") }
        val total = 2000 + 100 * 6000
        val end = start.plusSeconds(2000 * 60L + 100 * 6000L)
        for (countsNeedRead in listOf(false, true)) {
            calls.clear()
            val client = fakeHeartRateStore(singles + long, calls, writeHeartRate, countsNeedRead)
            val replies = PageReplies(client, sdkInt = 34).read(HealthConstants.HEART_RATE, start, end)

            assertNull(replies.last().error)
            assertEquals(total, replies.sumOf { it.points.size })
            val reads = calls.filter { it.method == "readRecords" }
            // No read returns more than twice pageSize samples, so none is dropped and read again: once,
            // 4096 records came back with 600,635 samples.
            assertTrue("${reads.maxOf { it.samples }}", reads.all { it.samples <= OVERSIZE_FACTOR * DEFAULT_PAGE_SIZE })
            assertEquals(total.toLong(), reads.sumOf { it.samples })
            if (countsNeedRead) assertTrue(reads.all { it.pageSize <= SeriesPageSizer.cap(DEFAULT_PAGE_SIZE) })
        }
    }

    @Test
    fun onAndroid15ARecordThatBeganBeforeTheReadKeepsThePagesFull() {
        // Android 15 counts the app's record that began three hours before the read whole, in the first bucket
        // of every histogram that it overlaps: the bucket before is asked for too, and left out.
        val early = heartRate(start.minusSeconds(3 * 3600L), 6 * 3600, "own-early")
        val spots = (0 until 600).map { heartRate(start.plusSeconds(60L * it), 1, "own$it") }
        val client = fakeHeartRateStore(listOf(early) + spots, calls, writeHeartRate, counting = Counting.ANDROID_15)
        val replies =
            PageReplies(client, sdkInt = 35).read(HealthConstants.HEART_RATE, start, start.plusSeconds(86400), 1000)

        assertNull(replies.last().error)
        assertEquals(3 * 3600 + 600, replies.sumOf { it.points.size })
        assertTrue(replies.all { it.permissionDenied == true })
        assertTrue("${replies.size} pages", replies.size <= 3)
        assertTrue("${calls.size} calls", calls.size <= 12)
        assertTrue(calls.all { it.origins == setOf(DataOrigin(OWN_PACKAGE)) })
    }

    /** A heart rate record that [packageName] wrote, from [from] on, with a sample a second. */
    private fun heartRate(from: Instant, samples: Int, id: String, packageName: String = OWN_PACKAGE): HeartRateRecord {
        val series = (0 until samples).map { HeartRateRecord.Sample(from.plusSeconds(it.toLong()), 60L) }
        val to = from.plusSeconds(maxOf(60L, samples.toLong()))
        return HeartRateRecord(from, null, to, null, series, writtenBy(packageName, id))
    }

    private companion object {
        const val OTHER = "com.example.other"
    }
}
