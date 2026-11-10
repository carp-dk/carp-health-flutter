package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthRecordingFilter
import java.time.Duration
import java.time.Instant

/**
 * Reads the interval data of sleep types: per bucket, the minutes covered by the data points that
 * reads return for the type ([sleepPoints]), overlapping points counted once. Health Connect has no
 * aggregate for sleep stages, and its sleep duration total is the whole session for every type.
 */
internal class SleepIntervalReader(
    private val healthConnectClient: HealthConnectClient,
    private val recordingFilter: HealthRecordingFilter,
) {
    /**
     * The buckets of [dataType] from [startTime] to [endTime], each [interval] long and the last one
     * ending at [endTime], as getIntervalData replies them; buckets without data are left out.
     * Sessions are read from [SLEEP_LOOKBACK] before [startTime] on: Health Connect matches them by
     * start time, and a session that began before the range counts with its part inside it.
     */
    suspend fun readIntervals(
        dataType: String,
        startTime: Instant,
        endTime: Instant,
        interval: Duration,
        recordingMethodsToFilter: List<Int>,
    ): List<Map<String, Any>> {
        require(!interval.isNegative && !interval.isZero) { "Argument 'interval' must be positive, not $interval" }
        if (!startTime.isBefore(endTime)) return emptyList()
        // Not before the epoch, a common "everything" start, unless the range itself starts earlier.
        val readStart = minOf(startTime, maxOf(startTime.minus(SLEEP_LOOKBACK), Instant.EPOCH))

        // All pages, kept as the time each point covers: buckets may combine points of any page.
        val covered = mutableListOf<CoveredInterval>()
        var pageToken: String? = null
        do {
            val response = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(readStart, endTime),
                    pageSize = SLEEP_MAX_RECORDS,
                    pageToken = pageToken,
                )
            )
            val sessions = recordingFilter.filterRecordsByRecordingMethods(recordingMethodsToFilter, response.records)
            for (session in sessions.filterIsInstance<SleepSessionRecord>()) {
                val source = session.metadata.dataOrigin.packageName
                sleepPoints(session, dataType).mapTo(covered) { CoveredInterval(it.startTime, it.endTime, source) }
            }
            pageToken = response.pageToken?.takeIf { it.isNotEmpty() }
        } while (pageToken != null)

        return minutesPerBucket(covered, startTime, endTime, interval).map { bucket ->
            AggregateReader.bucketData(bucket.minutes, bucket.startTime, bucket.endTime, bucket.sources)
        }
    }
}
