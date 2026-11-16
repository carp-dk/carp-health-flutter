package cachet.plugins.health.reading

import android.health.connect.HealthConnectException.ERROR_INTERNAL
import android.health.connect.TestHealthConnectException
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import java.time.Instant

/**
 * A Health Connect client of Android 14 or 15 that holds exercise [sessions], in the order they were
 * written, and grants [granted]. It pages them as those versions do: by start time (newest first if
 * asked, or if the page token says so: connect-client then leaves the order to it), ties in the order they
 * were written (row id), and a page token is PageTokenWrapper's: the start time of the next session and
 * how many of that time the page returned, which the next read skips. Like their
 * ExerciseSessionRecordHelper.readExtraData it fails when the request matches a session with a route (in
 * its data origins and range, at or after the token's time) that is not in the page. It holds no records
 * of other types, such as a workout's totals. Each read request is added to [requests].
 */
internal fun fakeSessionStore(
    sessions: List<ExerciseSessionRecord>,
    requests: MutableList<ReadRecordsRequest<*>> = mutableListOf(),
    granted: Set<String> = setOf(HealthPermission.getReadPermission(ExerciseSessionRecord::class)),
): HealthConnectClient {
    val permissions = fakePermissions(granted)
    return fakeHealthConnect { method, args ->
        when (method) {
            "getPermissionController" -> permissions
            "readRecords" -> {
                val request = args.single() as ReadRecordsRequest<*>
                requests.add(request)
                if (request.recordType == ExerciseSessionRecord::class) {
                    readSessions(sessions, request)
                } else {
                    ReadRecordsResponse(emptyList<Record>(), null)
                }
            }
            else -> throw UnsupportedOperationException(method)
        }
    }
}

private fun readSessions(written: List<ExerciseSessionRecord>, request: ReadRecordsRequest<*>): ReadRecordsResponse<*> {
    val token = request.pageToken?.let { HealthConnectPosition.decode(it)!! }
    val ascending = token?.let { !it.descending } ?: request.ascendingOrder
    val from = request.timeRangeFilter.startTime!!
    val to = request.timeRangeFilter.endTime!!
    val origins = request.dataOriginFilter
    // The where clause: data origins, range and token; ordered by start time, then by row id.
    fun afterToken(time: Long) = token == null || if (ascending) time >= token.timeMillis else time <= token.timeMillis
    val matched = written.withIndex()
        .filter { origins.isEmpty() || it.value.metadata.dataOrigin in origins }
        .filter { !it.value.startTime.isBefore(from) && it.value.startTime.isBefore(to) && afterToken(start(it.value)) }
        .sortedWith(compareBy({ if (ascending) start(it.value) else -start(it.value) }, { it.index }))
    var skipped = 0
    val skip = minOf(token?.offset ?: 0, matched.size)
    while (skipped < skip && start(matched[skipped].value) == token!!.timeMillis) skipped++
    val page = matched.drop(skipped).take(request.pageSize)
    val inPage = page.mapTo(HashSet()) { it.index }
    if (matched.any { it.value.exerciseRouteResult is ExerciseRouteResult.Data && it.index !in inPage }) {
        throw IllegalStateException(TestHealthConnectException(ERROR_INTERNAL, ROUTE_OUTSIDE_PAGE))
    }
    val rest = matched.drop(skipped + page.size)
    val next = rest.firstOrNull()?.let { (_, first) ->
        // The offset counts the sessions of the next one's start time that this page returned.
        val offset = page.takeLastWhile { start(it.value) == start(first) }.size.toLong()
        ((offset shl 45) or (start(first) shl 1) or (if (ascending) 0L else 1L)).toString()
    }
    return ReadRecordsResponse(page.map { it.value }, next)
}

private fun start(session: ExerciseSessionRecord): Long = session.startTime.toEpochMilli()

/** An hour's run from [start] that [packageName] wrote, with a route of one location 10 minutes in if [route]. */
internal fun runSession(
    id: String,
    start: Instant,
    route: Boolean,
    packageName: String = OWN_PACKAGE,
): ExerciseSessionRecord {
    val location = ExerciseRoute.Location(start.plusSeconds(600), 55.78, 12.52)
    return ExerciseSessionRecord(
        startTime = start, startZoneOffset = null, endTime = start.plusSeconds(3600), endZoneOffset = null,
        metadata = metadata(Metadata.RECORDING_METHOD_ACTIVELY_RECORDED, id, DataOrigin(packageName)),
        exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
        exerciseRoute = if (route) ExerciseRoute(listOf(location)) else null,
    )
}
