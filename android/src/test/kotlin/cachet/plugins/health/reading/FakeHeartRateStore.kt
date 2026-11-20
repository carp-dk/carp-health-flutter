package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.aggregate.AggregationResult
import androidx.health.connect.client.aggregate.AggregationResultGroupedByDuration
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset

/** A Health Connect call of a heart rate read: its method, data origin filter, and what a read asked for and got. */
internal class HeartRateCall(
    val method: String,
    val origins: Set<DataOrigin>,
    val pageSize: Int = 0,
    val samples: Long = 0,
)

/**
 * A Health Connect client that holds heart rate [records] and grants [granted]. It reads them as
 * [fakeRecordStore] does, and counts their samples as [counting] says (HeartRateRecord.MEASUREMENTS_COUNT,
 * in all or per duration) of the request's data origins only. As since Android 14 QPR2, without the read
 * permission it counts only with a data origin filter of exactly [OWN_PACKAGE]; with [countsNeedRead] it
 * refuses that too, as Android 14 before QPR2 does. Each call that is not refused is added to [calls].
 */
internal fun fakeHeartRateStore(
    records: List<HeartRateRecord>,
    calls: MutableList<HeartRateCall> = mutableListOf(),
    granted: Set<String> = setOf(HealthPermission.getReadPermission(HeartRateRecord::class)),
    countsNeedRead: Boolean = false,
    counting: Counting = Counting.SAMPLE_TIME,
): HealthConnectClient {
    val permissions = fakePermissions(granted)
    val byStart = records.sortedBy { it.startTime }
    return fakeHealthConnect { method, args ->
        when (method) {
            "getPermissionController" -> permissions
            "readRecords" -> {
                val request = args.single() as ReadRecordsRequest<*>
                val response = readStored(byStart, request, granted)
                val samples = response.records.sumOf { (it as HeartRateRecord).samples.size.toLong() }
                calls += HeartRateCall(method, request.dataOriginFilter, request.pageSize, samples)
                response
            }
            "aggregate", "aggregateGroupByDuration" -> {
                val request = args.single()!!
                val origins = request.field<Set<DataOrigin>>("dataOriginFilter")
                checkCountAccess(origins, granted, countsNeedRead)
                calls += HeartRateCall(method, origins)
                val range = request.field<TimeRangeFilter>("timeRangeFilter")
                val from = range.startTime!!.toEpochMilli()
                val to = range.endTime!!.toEpochMilli()
                val visible = byStart.filter { origins.isEmpty() || it.metadata.dataOrigin in origins }
                val counted = countedSamples(visible, from, to, counting)
                if (method == "aggregate") {
                    count(counted.sumOf { it.second })
                } else {
                    val bucket = request.field<Duration>("timeRangeSlicer").toMillis()
                    val counts = LongArray(((to - from + bucket - 1) / bucket).toInt())
                    for ((time, samples) in counted) counts[((time - from) / bucket).toInt()] += samples
                    counts.mapIndexed { i, samples ->
                        val start = Instant.ofEpochMilli(from + i * bucket)
                        val end = Instant.ofEpochMilli(minOf(to, from + (i + 1) * bucket))
                        AggregationResultGroupedByDuration(count(samples), start, end, ZoneOffset.UTC)
                    }
                }
            }
            else -> throw UnsupportedOperationException(method)
        }
    }
}

// Health Connect leaves the value out where nothing was counted.
private fun count(samples: Long) = AggregationResult(
    if (samples == 0L) emptyMap() else mapOf(HeartRateRecord.MEASUREMENTS_COUNT.metricKey to samples),
    emptyMap(),
    emptySet(),
)

/** Throws as Health Connect does for a count of heart rate samples that [granted] do not allow. */
private fun checkCountAccess(origins: Set<DataOrigin>, granted: Set<String>, countsNeedRead: Boolean) {
    if (HealthPermission.getReadPermission(HeartRateRecord::class) in granted) return
    if (countsNeedRead || HealthPermission.getWritePermission(HeartRateRecord::class) !in granted) {
        throw SecurityException("Caller doesn't have android.permission.health.READ_HEART_RATE to read HeartRate")
    }
    if (origins != setOf(DataOrigin(OWN_PACKAGE))) {
        throw SecurityException(
            "Caller does not have permission to read data for the following (aggregationTypes: " +
                "[HeartRate_measurements_count]) from other applications."
        )
    }
}

// The requests of aggregates keep their fields internal to connect-client.
@Suppress("UNCHECKED_CAST")
private fun <T> Any.field(name: String): T =
    javaClass.getDeclaredField(name).apply { isAccessible = true }.get(this) as T
