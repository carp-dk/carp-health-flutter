package cachet.plugins.health.reading

import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.Metadata
import java.time.Instant

/** How Health Connect counts heart rate samples (HeartRateRecord.MEASUREMENTS_COUNT). */
internal enum class Counting {
    /**
     * By their own time: on Android 16 and 17 the app's own records, and other apps' where the app does not
     * hold READ_HEALTH_DATA_HISTORY (measured on Android 16).
     */
    SAMPLE_TIME,

    /**
     * As measured on Android 16 (module 361153320) and 17 (module 372042540) where the app holds
     * READ_HEALTH_DATA_HISTORY: by their own time, but another app's record only if it starts at or after the
     * start of the range (of a histogram's whole range, with the bucket the plugin asks for before it).
     */
    ANDROID_16,

    /**
     * As measured on Android 15 (module 350820300): the records of the calling app ([OWN_PACKAGE]) that
     * overlap a range (with its end) whole, in the bucket of the later of their start and the range's;
     * other apps' records whole, in the range or bucket that holds their start.
     */
    ANDROID_15,
}

/**
 * Health Connect's heart rate calls over a list of records, as [HealthConnectHeartRateSource] makes
 * them: samples are counted as [counting] says, records are returned by their start time (ties in the
 * order they were written), and page tokens are positions.
 */
internal class FakeHeartRateSource(
    private val records: List<HeartRateRecord>,
    private val counting: Counting = Counting.SAMPLE_TIME,
) : HeartRateSource {
    data class Read(val from: Long, val to: Long, val records: Int, val pageToken: String?, val samples: Long)

    private val byStart = records.sortedBy { it.startTime }
    var counts = 0
    var histograms = 0
    var probes = 0
    val reads = mutableListOf<Read>()
    val calls get() = counts + histograms + probes + reads.size

    override suspend fun countSamples(from: Long, to: Long): Long {
        counts++
        return counted(from, to).sumOf { it.second }
    }

    override suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long> {
        histograms++
        // As the plugin asks for it: one more bucket before [from], left out.
        val lead = if (from >= bucket) bucket else 0L
        val counts = LongArray(((to - from + bucket - 1) / bucket).toInt())
        for ((time, samples) in counted(from - lead, to)) {
            if (time >= from) counts[((time - from) / bucket).toInt()] += samples
        }
        return counts.asList()
    }

    override suspend fun read(from: Long, to: Long, records: Int, pageToken: String?): HeartRateRecords {
        val matching = byStart.filter { it.startTime.toEpochMilli() in from until to }
        val offset = pageToken?.toInt() ?: 0
        val page = matching.drop(offset).take(records)
        reads += Read(from, to, records, pageToken, page.sumOf { it.samples.size.toLong() })
        val next = offset + page.size
        return HeartRateRecords(page, if (next < matching.size) next.toString() else null)
    }

    override suspend fun firstStart(from: Long, to: Long, newest: Boolean): Long? {
        probes++
        val starts = byStart.map { it.startTime.toEpochMilli() }.filter { it in from until to }
        return if (newest) starts.maxOrNull() else starts.minOrNull()
    }

    override fun ownRecordsOnly(packageName: String): HeartRateSource =
        FakeHeartRateSource(records.filter { it.metadata.dataOrigin.packageName == packageName }, counting)

    private fun counted(from: Long, to: Long) = countedSamples(byStart, from, to, counting)
}

/** What Health Connect counts of [records] in [from, to) as [counting] says: (the time it counts at, samples). */
internal fun countedSamples(
    records: List<HeartRateRecord>,
    from: Long,
    to: Long,
    counting: Counting,
): List<Pair<Long, Long>> =
    records.flatMap { record ->
        val start = record.startTime.toEpochMilli()
        val own = record.metadata.dataOrigin.packageName == OWN_PACKAGE
        when (counting) {
            Counting.SAMPLE_TIME -> sampleTimes(record, from, to)
            Counting.ANDROID_16 -> if (own || start >= from) sampleTimes(record, from, to) else emptyList()
            Counting.ANDROID_15 -> {
                val counts = if (own) start < to && record.endTime.toEpochMilli() >= from else start in from until to
                if (counts) listOf(maxOf(start, from) to record.samples.size.toLong()) else emptyList()
            }
        }
    }

/** (the time, 1) of each sample of [record] in [from, to). */
private fun sampleTimes(record: HeartRateRecord, from: Long, to: Long): List<Pair<Long, Long>> =
    record.samples.map { it.time.toEpochMilli() }.filter { it in from until to }.map { it to 1L }

/**
 * A heart rate record with [samples] samples, one every [stepMs] ms from [start] (epoch ms), written
 * by [packageName] (by default entered by hand in no app).
 */
internal fun heartRate(
    id: String,
    start: Long,
    samples: Int,
    stepMs: Long = 1000,
    end: Long? = null,
    packageName: String? = null,
) = HeartRateRecord(
    Instant.ofEpochMilli(start),
    null,
    Instant.ofEpochMilli(end ?: (start + maxOf(1, samples) * stepMs)),
    null,
    List(samples) { HeartRateRecord.Sample(Instant.ofEpochMilli(start + it * stepMs), 60L + it % 60) },
    if (packageName == null) Metadata.manualEntryWithId(id) else writtenBy(packageName, id),
)
