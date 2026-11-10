package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.optionalLong
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlin.reflect.KClass

/*
 * Reads with a 'limit', for the newest data points of a type (such as the latest weight) without
 * reading every page of the range. The Dart side sorts the points it gets newest first and keeps
 * 'limit' of them, so a series record may bring more samples than it needs.
 */

/**
 * The 'limit' argument of a read: how many of the records that start last to read, at most
 * [HC_MAX_RECORDS] (Health Connect rejects larger pages). Null when it is absent or not positive,
 * which means no limit. Throws IllegalArgumentException if it is not a number.
 */
internal fun MethodCall.recordLimit(): Int? =
    optionalLong("limit")?.takeIf { it > 0 }?.coerceAtMost(HC_MAX_RECORDS.toLong())?.toInt()

/**
 * The [limit] records of [recordType] that start last in [startTime, endTime), newest first, in one
 * request. Unlike the first page of a read without a limit, it does not look for records that began
 * before [startTime] ([SeriesLookback], [SleepLookback]), and it reads heart rate by record, not in
 * time slices ([HeartRatePageReader]).
 */
internal suspend fun HealthConnectClient.readNewestRecords(
    recordType: KClass<out Record>,
    startTime: Instant,
    endTime: Instant,
    limit: Int,
): List<Record> =
    readRecords(
        ReadRecordsRequest(
            recordType = recordType,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
            ascendingOrder = false,
            pageSize = limit,
        )
    ).records
