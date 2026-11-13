package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.request.AggregateGroupByDurationRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant

/** One request's worth of heart rate records, and the token of the next request, if any. */
internal class HeartRateRecords(val records: List<HeartRateRecord>, val pageToken: String?)

/** The Health Connect calls that a heart rate read is made of. Times are epoch ms. */
internal interface HeartRateSource {
    /** The number of samples whose time is in [from, to). */
    suspend fun countSamples(from: Long, to: Long): Long

    /**
     * The number of samples in each [bucket] ms of [from, to), from [from] on; the last bucket ends
     * at [to]. One call, so much cheaper than a [countSamples] per bucket.
     */
    suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long>

    /** Up to [records] of the records that start in [from, to), oldest first. */
    suspend fun read(from: Long, to: Long, records: Int, pageToken: String?): HeartRateRecords

    /** The start of the oldest (or [newest]) record that starts in [from, to), or null if none does. */
    suspend fun firstStart(from: Long, to: Long, newest: Boolean): Long?
}

internal class HealthConnectHeartRateSource(private val healthConnectClient: HealthConnectClient) : HeartRateSource {
    override suspend fun countSamples(from: Long, to: Long): Long =
        healthConnectClient.aggregate(
            AggregateRequest(metrics = setOf(HeartRateRecord.MEASUREMENTS_COUNT), timeRangeFilter = between(from, to))
        )[HeartRateRecord.MEASUREMENTS_COUNT] ?: 0L

    override suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long> {
        val counts = LongArray(((to - from + bucket - 1) / bucket).toInt())
        val groups = healthConnectClient.aggregateGroupByDuration(
            AggregateGroupByDurationRequest(
                metrics = setOf(HeartRateRecord.MEASUREMENTS_COUNT),
                timeRangeFilter = between(from, to),
                timeRangeSlicer = Duration.ofMillis(bucket),
            )
        )
        // Every bucket comes back, an empty one without a value (verified on Android 17).
        for (group in groups) {
            val index = ((group.startTime.toEpochMilli() - from) / bucket).toInt()
            if (index in counts.indices) counts[index] = group.result[HeartRateRecord.MEASUREMENTS_COUNT] ?: 0L
        }
        return counts.asList()
    }

    override suspend fun read(from: Long, to: Long, records: Int, pageToken: String?): HeartRateRecords {
        val response = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = between(from, to),
                pageSize = records,
                pageToken = pageToken,
            )
        )
        return HeartRateRecords(response.records, response.pageToken?.takeIf { it.isNotEmpty() })
    }

    override suspend fun firstStart(from: Long, to: Long, newest: Boolean): Long? =
        healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = between(from, to),
                ascendingOrder = !newest,
                pageSize = 1,
            )
        ).records.firstOrNull()?.startTime?.toEpochMilli()

    private fun between(from: Long, to: Long): TimeRangeFilter =
        TimeRangeFilter.between(Instant.ofEpochMilli(from), Instant.ofEpochMilli(to))
}
