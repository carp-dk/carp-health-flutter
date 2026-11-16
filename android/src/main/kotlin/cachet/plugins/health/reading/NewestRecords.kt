package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.optionalLong
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlin.reflect.KClass

/*
 * Reads with a 'limit', for the newest data points of a type (such as the latest weight) without
 * reading every page of the range. getDataPage reads them page by page, newest first, until the Dart
 * side has 'limit' points ([DataPageRequest.limit]); the deprecated getData reads the records that
 * start last in one request ([readNewestRecords]). The Dart side sorts the points it gets newest
 * first and keeps 'limit' of them, so a series record may bring more samples than it needs.
 */

/**
 * The 'limit' argument of a read: how many data points the Dart side keeps, and the most records
 * the first request asks for, at most [HC_MAX_RECORDS] (Health Connect rejects larger pages). Null
 * when it is absent or not positive, which means no limit. Throws IllegalArgumentException if it
 * is not a number.
 */
internal fun MethodCall.recordLimit(): Int? =
    optionalLong("limit")?.takeIf { it > 0 }?.coerceAtMost(HC_MAX_RECORDS.toLong())?.toInt()

/**
 * The [limit] records of [recordType] that start last in [startTime, endTime), newest first, for the
 * deprecated getData, which replies in one go. Unlike the first page of a read without a limit, it
 * does not look for records that began before [startTime] ([SeriesLookback], [SleepLookback]), and
 * it reads heart rate by record, not in time slices ([HeartRatePageReader]). Only the records of
 * [origins] are read, if any are given ([ReadAccess.origins]). Exercise sessions that Android 14 or 15
 * ([sdkInt]) reads with the rest of the range ([readRecordsPage]) are cut to [limit].
 */
internal suspend fun HealthConnectClient.readNewestRecords(
    recordType: KClass<out Record>,
    startTime: Instant,
    endTime: Instant,
    limit: Int,
    origins: Set<DataOrigin>,
    sdkInt: Int,
): List<Record> =
    readRecordsPage(
        ReadRecordsRequest(
            recordType = recordType,
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
            dataOriginFilter = origins,
            ascendingOrder = false,
            pageSize = limit,
        ),
        sdkInt,
        // One page, whose token is not followed: its records of the start time it ends inside need not be whole.
        // An empty one (android14-release, where more records start at the newest time than 'limit') reads them all.
        wholeTies = false,
    ).records.take(limit)
