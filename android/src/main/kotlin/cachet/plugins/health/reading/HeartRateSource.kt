package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.AggregateGroupByDurationRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant

/**
 * One request's worth of heart rate records and the token of the next request, if any. The last [tied] of
 * them are those of one start time that one more request read whole ([pastTies]).
 */
internal class HeartRateRecords(val records: List<HeartRateRecord>, val pageToken: String?, val tied: Int = 0)

/**
 * The Health Connect calls that a heart rate read is made of. Times are epoch ms.
 *
 * Health Connect counts heart rate samples (HeartRateRecord.MEASUREMENTS_COUNT) by their own time on
 * Android 16 and 17, but where the app holds READ_HEALTH_DATA_HISTORY another app's record only if it
 * starts at or after the start of the request (of a histogram's whole range): Health Connect then gives
 * access from the request's start on, and exempts only the app's own records. Measured on Android 16
 * (module 361153320) and 17 (module 372042540): another app's [T, T+1h) with a sample a minute counts
 * 30 in [T-1h, T+30m) and none in [T+30m, T+2h); the app's own record 30 in both, and so does another
 * app's without that permission, if it began at most 30 days before the first grant (Android 16 only;
 * older ones are neither counted nor read then).
 *
 * Android 15 (module 350820300) counts records whole instead: the records of the calling app that
 * overlap a range (with its end), each in full, in the range's first bucket if they began before it;
 * other apps' records in the range or bucket that holds their start. Android 14 is assumed to count as
 * 15. Records are read by their start time on every version.
 */
internal interface HeartRateSource {
    /** The number of samples in [from, to): those whose time is in it on Android 16 and later (see above). */
    suspend fun countSamples(from: Long, to: Long): Long

    /**
     * The number of samples in each [bucket] ms of [from, to), from [from] on; the last bucket ends
     * at [to]. One call, so much cheaper than a [countSamples] per bucket. On Android 16 and later
     * they are the samples whose time is in the bucket (another app's, with READ_HEALTH_DATA_HISTORY,
     * only of records that start in the range asked for); on Android 14 and 15 those of the records
     * that start in it, each in full, and none of the records that began before [from].
     */
    suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long>

    /**
     * Up to [records] of the records that start in [from, to), oldest first, and every further one of the
     * start time the last one has, which one more request reads ([readPastTies]).
     */
    suspend fun read(from: Long, to: Long, records: Int, pageToken: String?): HeartRateRecords

    /** The start of the oldest (or [newest]) record that starts in [from, to), or null if none does. */
    suspend fun firstStart(from: Long, to: Long, newest: Boolean): Long?

    /** The same calls, of the records that the app [packageName] wrote only. */
    fun ownRecordsOnly(packageName: String): HeartRateSource
}

/**
 * The calls of [HeartRateSource] to Health Connect, for the records of [origins] (every app if empty).
 * Since Android 14 QPR2 Health Connect also counts the samples of an app that may write heart rate but
 * not read it, when every call asks for its own records only ([ReadAccess.origins]); Android 14 before
 * QPR2 refuses such a count with SecurityException, and so may the Health Connect APK (closed source).
 */
internal class HealthConnectHeartRateSource(
    private val healthConnectClient: HealthConnectClient,
    private val origins: Set<DataOrigin> = emptySet(),
) : HeartRateSource {
    override suspend fun countSamples(from: Long, to: Long): Long =
        healthConnectClient.aggregate(
            AggregateRequest(
                metrics = setOf(HeartRateRecord.MEASUREMENTS_COUNT),
                timeRangeFilter = between(from, to),
                dataOriginFilter = origins,
            )
        )[HeartRateRecord.MEASUREMENTS_COUNT] ?: 0L

    override suspend fun histogram(from: Long, to: Long, bucket: Long): List<Long> {
        val counts = LongArray(((to - from + bucket - 1) / bucket).toInt())
        // Android 14 and 15 count the app's own records that began before a range whole, in its first
        // bucket: one more bucket is asked for before [from] and left out. None before the epoch.
        val lead = if (from >= bucket) bucket else 0L
        val groups = healthConnectClient.aggregateGroupByDuration(
            AggregateGroupByDurationRequest(
                metrics = setOf(HeartRateRecord.MEASUREMENTS_COUNT),
                timeRangeFilter = between(from - lead, to),
                timeRangeSlicer = Duration.ofMillis(bucket),
                dataOriginFilter = origins,
            )
        )
        // Every bucket comes back, an empty one without a value (verified on Android 15 and 17).
        for (group in groups) {
            val index = Math.floorDiv(group.startTime.toEpochMilli() - from, bucket).toInt()
            if (index in counts.indices) counts[index] = group.result[HeartRateRecord.MEASUREMENTS_COUNT] ?: 0L
        }
        return counts.asList()
    }

    override suspend fun read(from: Long, to: Long, records: Int, pageToken: String?): HeartRateRecords {
        val page = healthConnectClient.readPastTies(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = between(from, to),
                dataOriginFilter = origins,
                pageSize = records,
                pageToken = pageToken,
            )
        )
        return HeartRateRecords(page.records, page.pageToken, page.tied)
    }

    override suspend fun firstStart(from: Long, to: Long, newest: Boolean): Long? =
        healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = between(from, to),
                dataOriginFilter = origins,
                ascendingOrder = !newest,
                pageSize = 1,
            )
        ).records.firstOrNull()?.startTime?.toEpochMilli()

    override fun ownRecordsOnly(packageName: String): HeartRateSource =
        HealthConnectHeartRateSource(healthConnectClient, ReadAccess.origins(true, packageName))

    private fun between(from: Long, to: Long): TimeRangeFilter =
        TimeRangeFilter.between(Instant.ofEpochMilli(from), Instant.ofEpochMilli(to))
}
