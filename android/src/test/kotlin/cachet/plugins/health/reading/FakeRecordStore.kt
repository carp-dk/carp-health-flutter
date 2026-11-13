package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import cachet.plugins.health.fakeOf
import java.time.Instant
import kotlin.reflect.KClass

/**
 * A Health Connect client that holds [records] and grants reading [recordType], and reads them as
 * Health Connect does (verified on Android 17): a record is in a time range when it starts in it,
 * the records come in start order (newest first if asked), and a page token is a position. Each
 * read request is added to [requests]; one that [failure] gives an error for throws it instead.
 */
internal fun fakeRecordStore(
    recordType: KClass<out Record>,
    records: List<Record>,
    requests: MutableList<ReadRecordsRequest<*>> = mutableListOf(),
    failure: (ReadRecordsRequest<*>) -> RuntimeException? = { null },
): HealthConnectClient {
    val permissions = fakeOf<PermissionController> { method ->
        check(method == "getGrantedPermissions") { "Unexpected call of $method" }
        setOf(HealthPermission.getReadPermission(recordType))
    }
    val byStart = records.sortedBy(::startTime)
    return fakeHealthConnect { method, args ->
        when (method) {
            "getPermissionController" -> permissions
            "readRecords" -> {
                val request = args.single() as ReadRecordsRequest<*>
                requests.add(request)
                failure(request)?.let { throw it }
                val from = request.timeRangeFilter.startTime
                val to = request.timeRangeFilter.endTime
                val matching = byStart
                    .filter { from == null || !startTime(it).isBefore(from) }
                    .filter { to == null || startTime(it).isBefore(to) }
                    .let { if (request.ascendingOrder) it else it.reversed() }
                val position = request.pageToken?.toInt() ?: 0
                val next = minOf(position + request.pageSize, matching.size)
                ReadRecordsResponse(matching.subList(position, next), if (next < matching.size) "$next" else null)
            }
            else -> throw UnsupportedOperationException(method)
        }
    }
}

// connect-client keeps the interface of records with a start time internal.
private fun startTime(record: Record): Instant = when (record) {
    is SleepSessionRecord -> record.startTime
    is ExerciseSessionRecord -> record.startTime
    is SpeedRecord -> record.startTime
    is HeartRateRecord -> record.startTime
    else -> throw UnsupportedOperationException("No start time for ${record::class.simpleName}")
}
