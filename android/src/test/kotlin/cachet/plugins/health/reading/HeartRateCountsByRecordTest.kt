package cachet.plugins.health.reading

import androidx.health.connect.client.records.HeartRateRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Heart rate read where Health Connect counts records whole instead of samples by their time, as
 * Android 15 does (and Android 14 is assumed to): every sample once, also of records that began before
 * the read, and a few calls on every page. Device numbers are from an Android 15 emulator (module
 * 350820300) with the reader before this fix.
 */
class HeartRateCountsByRecordTest {
    private val minute = 60_000L
    private val hour = 60 * minute
    private val day = 24 * hour
    private val t0 = 1_456_790_400_000L // 2016-03-01, the window of the device tests

    private fun own(id: String, start: Long, samples: Int, stepMs: Long = 1000) =
        heartRate(id, start, samples, stepMs, packageName = OWN_PACKAGE)

    private fun other(id: String, start: Long, samples: Int, stepMs: Long = 1000) =
        heartRate(id, start, samples, stepMs, packageName = OTHER)

    /** Reads [records] as an Android 15 Health Connect counts them, all of them or only this app's ([ownOnly]). */
    private fun read(
        records: List<HeartRateRecord>,
        start: Long,
        end: Long,
        budget: Int,
        ownOnly: Boolean = false,
    ): HeartRateRead {
        val all = FakeHeartRateSource(records, Counting.ANDROID_15)
        val source = if (ownOnly) all.ownRecordsOnly(OWN_PACKAGE) as FakeHeartRateSource else all
        val read = readHeartRate(source, start, end, budget, sdkInt = 35, ownOnly = ownOnly)
        val readable = records.filter { !ownOnly || it.metadata.dataOrigin.packageName == OWN_PACKAGE }
        assertEverySampleOnce(readable, read, start, end)
        return read
    }

    @Test
    fun aRecordOfTheAppThatBeganBeforeTheReadCostsAFewCalls() {
        // Six hours at 1 Hz, read from three hours in: 2,460 calls on the device, then RATE_LIMIT_EXCEEDED.
        val records = listOf(own("six", t0, 6 * 3600))
        for (ownOnly in listOf(true, false)) {
            for (budget in listOf(3, 10, 20000)) {
                val read = read(records, t0 + 3 * hour, t0 + day, budget, ownOnly)
                assertTrue("$budget: ${read.calls}", read.source.calls <= 8)
            }
        }
    }

    @Test
    fun smallPagesOfTheAppsOwnRecordsCostAFewCallsEach() {
        // The device's October data: a record that began half an hour before the read, records of five samples
        // every hour and two of one. pageSize 3 made over 2,000 calls on the first page.
        val records = listOf(own("early", t0 - 30 * minute, 4, 20 * minute)) +
            List(8) { own("hour$it", t0 + (it + 1) * hour, 5, 2 * minute) } +
            listOf(own("spot0", t0 + 9 * hour, 1), own("spot1", t0 + 9 * hour + 5 * minute, 1))
        for (budget in listOf(3, 10)) {
            val read = read(records, t0, t0 + day, budget, ownOnly = true)
            assertTrue("$budget: ${read.calls}", read.calls.all { it <= 6 })
        }
    }

    @Test
    fun findsOtherAppsRecordsThatBeganBeforeTheRead() {
        // Android 15 counts another app's record only where it starts, so no count of the read shows it: the
        // first slice's count matched its records, and the look-back was skipped.
        val records = listOf(other("watch", t0 - 30 * minute, 60, minute)) +
            List(20) { own("hour$it", t0 + (it + 1) * hour, 5, minute) }
        for (counting in listOf(Counting.ANDROID_15, Counting.SAMPLE_TIME)) {
            val source = FakeHeartRateSource(records, counting)
            val read = readHeartRate(source, t0, t0 + day, 20000, sdkInt = 35)
            assertEverySampleOnce(records, read, t0, t0 + day)
            assertEquals(30, samplesOf(read.records, t0, t0 + day).count { it.first == "watch" })
        }
    }

    @Test
    fun aLongRecordThatBeganEarlierDoesNotShrinkTheSlices() {
        // A day at 1 Hz from 12 hours before the read: Android 15 counts it whole in the first bucket of every
        // histogram that it overlaps, unless the bucket before is asked for too and left out.
        val records = listOf(own("day", t0 - 12 * hour, 86_400)) +
            List(2880) { other("spot$it", t0 - day + it * minute, 1) } +
            List(288) { own("app$it", t0 - day + it * 10 * minute, 1) }
        val read = read(records, t0, t0 + day, 1000)
        // A page of the day's record, then pages of about 1000 samples each.
        assertTrue("${read.pages.size} pages", read.pages.size <= 4)
        assertTrue("${read.source.calls} calls", read.source.calls <= 20)
    }

    @Test
    fun aLongRecordInTheReadDoesNotShrinkTheSlicesAfterIt() {
        val records = listOf(own("day", t0 + hour, 86_400)) +
            List(330) { own("spot$it", t0 + hour + (it + 1) * minute, 1) }
        val read = read(records, t0, t0 + 2 * day, 20000, ownOnly = true)
        assertTrue("${read.pages.size} pages", read.pages.size <= 6)
    }

    @Test
    fun theLookBackStopsAfterItsCalls() {
        // More than a look-back's worth of slices before the read, each a record of over 20,000 samples: the
        // newest are found, and the first page makes no more than its calls.
        val records = List(30) { own("dense$it", t0 - day + hour + it * 2_001_000L, 20_001, stepMs = 100) } +
            listOf(own("reaching", t0 - 10 * minute, 30, minute), own("after", t0 + hour, 10))
        val all = FakeHeartRateSource(records, Counting.ANDROID_15)
        val read = readHeartRate(all, t0, t0 + day, 20000, sdkInt = 35)
        assertEverySampleOnce(records, read, t0, t0 + day)
        // The look-back's calls, and a histogram and a read of the first slice of the read.
        assertTrue("${read.calls}", read.calls.first() in MAX_LOOKBACK_CALLS..MAX_LOOKBACK_CALLS + 3)
        assertEquals(20, samplesOf(read.records, t0, t0 + day).count { it.first == "reaching" })
    }

    @Test
    fun everyPageMakesAFewCallsWhateverTheCounts() {
        val shapes = listOf(
            // A record of the app that began before the read, and one of another app.
            listOf(own("early", t0 - 2 * hour, 3 * 3600), other("watch", t0 - 30 * minute, 60, minute)) +
                List(12) { own("hour$it", t0 + it * hour, 5, minute) } +
                List(24) { other("spot$it", t0 + it * 30 * minute, 1) },
            // Records that start together, and a long one later.
            List(20) { own("tie$it", t0 + hour, 600) } + List(72) { other("spot$it", t0 + it * 10 * minute, 1) } +
                listOf(own("long", t0 + 5 * hour, 2 * 3600)),
        )
        val versions = listOf(
            Counting.ANDROID_15 to 35, Counting.ANDROID_15 to 33,
            Counting.SAMPLE_TIME to 35, Counting.SAMPLE_TIME to 37,
            Counting.ANDROID_16 to 36, Counting.ANDROID_16 to 37,
        )
        for (records in shapes) {
            for ((counting, sdkInt) in versions) {
                for (budget in listOf(3, 10, 1000, 20000)) {
                    val read = readHeartRate(FakeHeartRateSource(records, counting), t0, t0 + 12 * hour, budget, sdkInt)
                    assertEverySampleOnce(records, read, t0, t0 + 12 * hour)
                    assertTrue("$counting $sdkInt $budget: ${read.calls}", read.calls.all { it <= 12 })
                }
            }
        }
    }

    private companion object {
        const val OTHER = "com.example.other"
    }
}
