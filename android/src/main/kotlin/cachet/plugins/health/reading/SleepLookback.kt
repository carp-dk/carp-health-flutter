package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant

/** Finds the sleep sessions that began before the start of a read but have stages that start inside it. */
internal class SleepLookback(private val healthConnectClient: HealthConnectClient) {
    /**
     * Health Connect matches sleep sessions by their start time (verified on Android 17: a read from
     * 00:15 returned no stage of a night that began at 22:00), so a session that began before
     * [startTime] is not returned although some of its stages start inside the range. Reading every
     * page of the [SLEEP_LOOKBACK] before [startTime] finds those sessions; the converter keeps only
     * their stages that start inside the range. A session that began earlier than that is missed, as
     * for series ([SeriesLookback]). Sleep stage reads only: a SLEEP_SESSION read returns the sessions
     * that start in the range.
     *
     * @param pageSessionIds Ids of the sessions read for the range itself, which are left out
     * @return The sessions found, oldest first
     */
    suspend fun readLookbackSessions(startTime: Instant, pageSessionIds: Set<String>): List<Record> {
        // Nothing to look back at from a read that starts at the epoch, a common "everything" start.
        val lookbackStart = maxOf(startTime.minus(SLEEP_LOOKBACK), Instant.EPOCH)
        if (!lookbackStart.isBefore(startTime)) return emptyList()
        val sessions = mutableListOf<Record>()
        var pageToken: String? = null
        do {
            val response = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = SleepSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(lookbackStart, startTime),
                    pageSize = SLEEP_MAX_RECORDS,
                    pageToken = pageToken,
                )
            )
            sessions.addAll(keepLookbackSessions(response.records, startTime, pageSessionIds))
            pageToken = response.pageToken?.takeIf { it.isNotEmpty() }
        } while (pageToken != null)
        return sessions
    }

    companion object {
        /**
         * The sessions of a lookback read that end after [startTime] and are not among
         * [pageSessionIds] (which makes the lookback harmless if Health Connect matched by overlap),
         * in the order read. A session that ends at [startTime] is left out: a stage ends after it
         * starts, so none of its stages starts at or after [startTime].
         */
        internal fun keepLookbackSessions(
            sessions: List<Record>,
            startTime: Instant,
            pageSessionIds: Set<String>,
        ): List<Record> =
            sessions.filter {
                it is SleepSessionRecord && it.endTime.isAfter(startTime) && it.metadata.id !in pageSessionIds
            }
    }
}
