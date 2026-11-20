package cachet.plugins.health.reading

import androidx.health.connect.client.records.HeartRateRecord
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Heart rate reads where Health Connect counts another app's record only if it starts in the range
 * counted, as Android 16 and 17 do for an app that holds READ_HEALTH_DATA_HISTORY ([Counting.ANDROID_16]):
 * every sample once, also of other apps' records that began before the read. The shapes are those of the
 * device probes of 2026-11-12 (Android 16 emulator, module 361153320; Pixel 8a with Android 17, module
 * 372042540), where the reader before this fix would have left those records out.
 */
class HeartRateOtherAppsCountsTest {
    private val minute = 60_000L
    private val hour = 60 * minute
    private val day = 24 * hour
    private val t0 = 1_456_790_400_000L // 2016-03-01, the window of the device tests

    private fun own(id: String, start: Long, samples: Int, stepMs: Long = 1000) =
        heartRate(id, start, samples, stepMs, packageName = OWN_PACKAGE)

    private fun other(id: String, start: Long, samples: Int, stepMs: Long = 1000) =
        heartRate(id, start, samples, stepMs, packageName = OTHER)

    /** Reads [records] as [Counting.ANDROID_16] counts them, every app's or only this app's ([ownOnly]). */
    private fun read(
        records: List<HeartRateRecord>,
        start: Long,
        end: Long,
        budget: Int,
        sdkInt: Int = 37,
        ownOnly: Boolean = false,
    ): HeartRateRead {
        val all = FakeHeartRateSource(records, Counting.ANDROID_16)
        val source = if (ownOnly) all.ownRecordsOnly(OWN_PACKAGE) as FakeHeartRateSource else all
        val read = readHeartRate(source, start, end, budget, sdkInt, ownOnly)
        val readable = records.filter { !ownOnly || it.metadata.dataOrigin.packageName == OWN_PACKAGE }
        assertEverySampleOnce(readable, read, start, end)
        return read
    }

    @Test
    fun findsAnotherAppsRecordWhereNoRecordStartsInTheRead() {
        // Another app's hour from T, a sample a minute, read from T + 30 minutes: no count of the read holds
        // its samples, so the first page returned none, also where the whole read was counted (three days).
        val watch = listOf(other("watch", t0, 60, minute))
        for (sdkInt in listOf(36, 37)) {
            for (end in listOf(t0 + 2 * hour, t0 + 3 * day)) {
                for (budget in listOf(3, 20000)) {
                    val read = read(watch, t0 + 30 * minute, end, budget, sdkInt)
                    assertEquals(30, samplesOf(read.records, t0 + 30 * minute, end).size)
                }
            }
        }
    }

    @Test
    fun findsAnotherAppsRecordThatBeganBeforeAReadOfOnePage() {
        // Another app's record from 30 minutes before the read, and records of this app in it: the count of
        // the one page held only this app's samples, so none seemed to be missing.
        val records = listOf(other("watch", t0 - 30 * minute, 60, minute)) +
            List(10) { own("spot$it", t0 + hour + it * minute, 1) }
        for (sdkInt in listOf(36, 37)) {
            for (budget in listOf(100, 20000)) {
                val read = read(records, t0, t0 + 2 * hour, budget, sdkInt)
                assertEquals(1, read.pages.size)
                assertEquals(30, samplesOf(read.records, t0, t0 + 2 * hour).count { it.first == "watch" })
            }
        }
    }

    @Test
    fun findsAnotherAppsRecordThatBeganBeforeAReadOfOneLargePage() {
        // A watch's record from an hour before the read, off the wrist for its first six hours there, and six
        // hours of this app at 1 Hz, all in one page: the count held the app's samples only.
        val start = t0 + day
        val times = List(6) { start - hour + it * 10 * minute } + List(12) { start + 6 * hour + it * 10 * minute }
        val watch = HeartRateRecord(
            Instant.ofEpochMilli(start - hour), null, Instant.ofEpochMilli(start + 8 * hour), null,
            times.map { HeartRateRecord.Sample(Instant.ofEpochMilli(it), 70) },
            writtenBy(OTHER, "watch"),
        )
        val read = read(listOf(watch, own("app", start, 6 * 3600)), start, start + day, 50000)
        assertEquals(1, read.pages.size)
        assertEquals(12, samplesOf(read.records, start, start + day).count { it.first == "watch" })
    }

    @Test
    fun theCountStillRulesOutTheLookBackOfTheAppsOwnRecords() {
        // Health Connect counts the app's own records by their samples' time whatever their start, so a read
        // of them alone skips the look-back where the count shows no earlier record, and ends it once found.
        val spots = List(3 * 24 * 60) { own("spot$it", t0 + it * minute, 1) }
        val none = read(spots, t0 + day, t0 + 2 * day, 20000, ownOnly = true)
        assertTrue(none.source.reads.none { it.from < t0 + day })
        assertEquals(2, none.source.calls)

        val early = own("early", t0 + day - 30 * minute, 60, minute)
        val found = read(spots + early, t0 + day, t0 + 2 * day, 20000, ownOnly = true)
        assertEquals(30, samplesOf(found.records, t0 + day, t0 + 2 * day).count { it.first == "early" })
        assertTrue("${found.calls}", found.source.calls <= 4)

        // A read of every app's records reads the whole day before.
        val all = read(spots + early, t0 + day, t0 + 2 * day, 20000)
        assertTrue(all.source.reads.any { it.from == t0 })
    }

    private companion object {
        const val OTHER = "com.example.other"
    }
}
