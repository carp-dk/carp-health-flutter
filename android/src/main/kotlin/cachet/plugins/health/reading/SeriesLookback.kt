package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import kotlin.reflect.KClass

/** Finds the series records that began before the start of a read but have samples inside it. */
internal class SeriesLookback(private val healthConnectClient: HealthConnectClient) {
    /**
     * Health Connect matches series records by their start time (verified on Android 17), so a
     * record that began before [startTime] is not returned although some of its samples fall inside
     * the range. One small, newest-first read of the [SERIES_LOOKBACK] before [startTime] finds those
     * records; the converter keeps only their samples inside the range. Records that started earlier
     * than that, or behind [limit] newer ones, are missed. Used for speed and skin temperature, whose
     * records are few; heart rate scans the whole look-back range ([HeartRatePageReader]).
     *
     * @param pageRecordIds Ids of the records read for the range itself, which are left out
     */
    suspend fun readLookbackRecords(
        recordType: KClass<out Record>,
        startTime: Instant,
        limit: Int,
        pageRecordIds: Set<String>,
    ): List<Record> {
        // Nothing to look back at from a read that starts at the epoch, a common "everything" start.
        val lookbackStart = maxOf(startTime.minus(SERIES_LOOKBACK), Instant.EPOCH)
        if (!lookbackStart.isBefore(startTime)) return emptyList()
        val response = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = recordType,
                timeRangeFilter = TimeRangeFilter.between(lookbackStart, startTime),
                ascendingOrder = false,
                pageSize = limit,
            )
        )
        return keepLookbackRecords(response.records, startTime, pageRecordIds)
    }

    companion object {
        /**
         * The records of a newest-first lookback read that reach [startTime] and are not among
         * [pageRecordIds] (which makes the lookback harmless if Health Connect matched by overlap),
         * in ascending start order. A record that ends exactly at [startTime] is kept: it may hold a
         * sample at that instant, which the window before leaves out (it ends before [startTime]).
         */
        internal fun keepLookbackRecords(
            newestFirst: List<Record>,
            startTime: Instant,
            pageRecordIds: Set<String>,
        ): List<Record> =
            newestFirst
                .filter { reaches(it, startTime) && it.metadata.id !in pageRecordIds }
                .reversed()

        /** Whether series [record] ends at or after [startTime]. */
        internal fun reaches(record: Record, startTime: Instant): Boolean =
            seriesEndTime(record)?.isBefore(startTime) == false

        private fun seriesEndTime(record: Record): Instant? = when (record) {
            is HeartRateRecord -> record.endTime
            is SpeedRecord -> record.endTime
            is SkinTemperatureRecord -> record.endTime
            else -> null
        }
    }
}
