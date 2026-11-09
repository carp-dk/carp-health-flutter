package cachet.plugins.health.reading

import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.Metadata
import java.time.Instant

/**
 * Health Connect's heart rate calls over a list of records, as verified on Android 17: samples
 * are counted by their own time, records are returned by their start time (ties in the order they
 * were written), and page tokens are positions.
 */
internal class FakeHeartRateSource(records: List<HeartRateRecord>) : HeartRateSource {
    data class Read(val from: Long, val to: Long, val records: Int, val pageToken: String?, val samples: Long)

    private val byStart = records.sortedBy { it.startTime }
    var counts = 0
    var histograms = 0
    var probes = 0
    val reads = mutableListOf<Read>()
    val calls get() = counts + histograms + probes + reads.size

    override suspend fun countSamples(from: Long, to: Long): Long {
        counts++
        return byStart.sumOf { record -> record.samples.count { it.time.toEpochMilli() in from until to }.toLong() }
    }

    override suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long> {
        histograms++
        val counts = LongArray(((to - from + bucket - 1) / bucket).toInt())
        for (record in byStart) {
            for (sample in record.samples) {
                val time = sample.time.toEpochMilli()
                if (time in from until to) counts[((time - from) / bucket).toInt()]++
            }
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
}

/** A heart rate record with [samples] samples, one every [stepMs] ms from [start] (epoch ms). */
internal fun heartRate(id: String, start: Long, samples: Int, stepMs: Long = 1000, end: Long? = null) =
    HeartRateRecord(
        Instant.ofEpochMilli(start),
        null,
        Instant.ofEpochMilli(end ?: (start + maxOf(1, samples) * stepMs)),
        null,
        List(samples) { HeartRateRecord.Sample(Instant.ofEpochMilli(start + it * stepMs), 60L + it % 60) },
        Metadata.manualEntryWithId(id),
    )
