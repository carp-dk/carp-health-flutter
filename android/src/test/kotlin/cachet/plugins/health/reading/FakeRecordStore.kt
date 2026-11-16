package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import cachet.plugins.health.fakeOf
import java.time.Instant
import kotlin.reflect.KClass

/** The package of the app that reads in the tests, whose own records it may read with only write permission. */
internal const val OWN_PACKAGE = "com.example.reader"

/**
 * A Health Connect client that holds [records] and grants [granted] (by default reading [recordType]),
 * and reads them as Health Connect does (verified on Android 17): a record is in a time range when it
 * starts in it, the records come in start order (newest first if asked), a page token is a position,
 * and only records of the request's type and data origins come back. As since Android 14 QPR2, a type
 * that may be written but not read is read only with a data origin filter of exactly [OWN_PACKAGE],
 * and without either permission not at all: other reads throw SecurityException. Each read request is
 * added to [requests]; one that [failure] gives an error for throws it instead.
 */
internal fun fakeRecordStore(
    recordType: KClass<out Record>,
    records: List<Record>,
    requests: MutableList<ReadRecordsRequest<*>> = mutableListOf(),
    granted: Set<String> = setOf(HealthPermission.getReadPermission(recordType)),
    failure: (ReadRecordsRequest<*>) -> RuntimeException? = { null },
): HealthConnectClient {
    val permissions = fakePermissions(granted)
    val byStart = records.sortedBy(::startTime)
    return fakeHealthConnect { method, args ->
        when (method) {
            "getPermissionController" -> permissions
            "readRecords" -> {
                val request = args.single() as ReadRecordsRequest<*>
                requests.add(request)
                failure(request)?.let { throw it }
                readStored(byStart, request, granted)
            }
            else -> throw UnsupportedOperationException(method)
        }
    }
}

/** A permission controller that grants [granted]. */
internal fun fakePermissions(granted: Set<String>): PermissionController = fakeOf { method ->
    check(method == "getGrantedPermissions") { "Unexpected call of $method" }
    granted
}

/** The reply to [request] from the records [byStart] (in start order) with [granted], as [fakeRecordStore] reads. */
internal fun readStored(
    byStart: List<Record>,
    request: ReadRecordsRequest<*>,
    granted: Set<String>,
): ReadRecordsResponse<*> {
    checkReadAccess(request, granted)
    val from = request.timeRangeFilter.startTime
    val to = request.timeRangeFilter.endTime
    val origins = request.dataOriginFilter
    val matching = byStart
        .filter { request.recordType.isInstance(it) }
        .filter { origins.isEmpty() || it.metadata.dataOrigin in origins }
        .filter { from == null || !startTime(it).isBefore(from) }
        .filter { to == null || startTime(it).isBefore(to) }
        .let { if (request.ascendingOrder) it else it.reversed() }
    val position = request.pageToken?.toInt() ?: 0
    val next = minOf(position + request.pageSize, matching.size)
    return ReadRecordsResponse(matching.subList(position, next), if (next < matching.size) "$next" else null)
}

/** Throws as Health Connect does (Android 14 QPR2 and later) for a read that [granted] do not allow. */
private fun checkReadAccess(request: ReadRecordsRequest<*>, granted: Set<String>) {
    val type = request.recordType
    if (HealthPermission.getReadPermission(type) in granted) return
    if (HealthPermission.getWritePermission(type) !in granted) {
        throw SecurityException("Caller doesn't have permission to read or write ${type.simpleName}")
    }
    if (request.dataOriginFilter != setOf(DataOrigin(OWN_PACKAGE))) {
        throw SecurityException(
            "Caller does not have permission to read data for the following (recordType: ${type.java.name}) " +
                "from other applications."
        )
    }
}

// connect-client keeps the interface of records with a start time internal.
private fun startTime(record: Record): Instant = when (record) {
    is SleepSessionRecord -> record.startTime
    is ExerciseSessionRecord -> record.startTime
    is SpeedRecord -> record.startTime
    is HeartRateRecord -> record.startTime
    is StepsRecord -> record.startTime
    is DistanceRecord -> record.startTime
    is TotalCaloriesBurnedRecord -> record.startTime
    else -> throw UnsupportedOperationException("No start time for ${record::class.simpleName}")
}
