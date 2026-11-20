package cachet.plugins.health.reading

import android.annotation.SuppressLint
import android.health.connect.HealthConnectException
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.request.ReadRecordsRequest
import kotlin.reflect.KClass

/*
 * Android 14 and 15 Health Connect (AOSP android14-release to android15-qpr2-release) fail a read of
 * exercise sessions when the app may read routes (READ_EXERCISE_ROUTES, or WRITE_EXERCISE_ROUTE for its
 * own) and the request's where clause matches a session with such a route that is not in the page:
 * ExerciseSessionRecordHelper.readExtraData reads the route rows of every session that clause matches,
 * without the page's limit, and maps each to a session of the page, which throws NullPointerException for
 * one outside it (android16-release checks for null). The app gets IllegalStateException(
 * HealthConnectException(ERROR_INTERNAL, "java.lang.NullPointerException: ...")). Health Connect is a
 * mainline module, so an updated Android 14 or 15 device may not have the bug.
 *
 * The where clause (RecordHelper.getReadTableWhereClause) holds the request's data origins and time range
 * and, with a page token, the sessions that start at or after the token's time (newest first: at or
 * before). The plugin sends only tokens at offset 0 ([readPastTies]), which skip none of those, so the where
 * clause matches the rest of the range, and the same position read again with [HC_MAX_RECORDS] sessions
 * leaves none out while at most that many remain.
 *
 * getDataPage without a limit then replies only the sessions it asked for and starts the next page at the
 * first one it left out ([RecordsPage.cut]), so a workout page reads the totals of no more workouts than
 * usual. That page may fail and be read again in turn: each such page costs two reads, the second of which
 * returns every session left in the range, with its route.
 */

/**
 * One request's records and the token of the next request (null after the last). The last [tied] of them are
 * the records of one start time that one more request read whole ([pastTies]); [reread] tells whether Health
 * Connect failed on a route outside the page and the page was read again ([readRecordsPage]).
 */
internal class RecordsPage<T : Record>(
    val records: List<T>,
    val pageToken: String?,
    val tied: Int = 0,
    val reread: Boolean = false,
) {
    /**
     * This page of exercise sessions in start order (newest first if [descending]) cut to its first [count]
     * and every further one of the last one's start time. The sessions left out start after all of those
     * (newest first: before), so the next page's token is the first one's start time with no offset: Health
     * Connect reads from it exactly them and the rest of the range ([HealthConnectPosition.encode]). The page
     * itself if it holds no more, or if the first one left out starts before 1970, which no token can hold.
     */
    fun cut(count: Int, descending: Boolean): RecordsPage<T> {
        var end = maxOf(1, count)
        if (records.size <= end) return this
        val last = startTime(records[end - 1])
        while (end < records.size && startTime(records[end]) == last) end++
        val next = records.getOrNull(end)?.let(::startTime)?.takeIf { it >= 0 } ?: return this
        val token = HealthConnectPosition(descending, next, 0).encode()
        return RecordsPage(records.subList(0, end), token, reread = reread)
    }
}

/**
 * The records [request] asks for, and where the page ends inside the records of one start time, every
 * further one of them ([pastTies]), unless [wholeTies] is false: the read of one page whose token is not
 * followed. An empty page with a token, which holds none of the records of the first start time it matches
 * (android14-release, where they are more than it asks for), reads them in either case: else it would hold
 * nothing. Exercise sessions that Health Connect fails to read on Android 14 and 15 for a route outside the
 * page ([isRouteOutsidePage]) are read again in one request with every session left in the range, up to
 * [HC_MAX_RECORDS], so such a page holds more records than asked for ([RecordsPage.reread],
 * [RecordsPage.cut]). If no such request can help, the error is thrown as it came; so is an error of the
 * read again.
 */
internal suspend fun <T : Record> HealthConnectClient.readRecordsPage(
    request: ReadRecordsRequest<T>,
    sdkInt: Int,
    wholeTies: Boolean = true,
): RecordsPage<T> {
    val (read, response) = try {
        request to readRecords(request)
    } catch (e: IllegalStateException) {
        if (!isRouteOutsidePage(e, request.recordType, sdkInt)) throw e
        val reread = rereadOf(request) ?: throw e
        Log.w("FLUTTER_HEALTH", "Health Connect failed on a route outside the page, reading on: $e")
        reread to readRecords(reread)
    }
    val page =
        if (wholeTies || response.records.isEmpty()) pastTies(read, response)
        else RecordsPage(response.records, response.pageToken)
    return if (read === request) page else RecordsPage(page.records, page.pageToken, page.tied, reread = true)
}

/**
 * [failed] read again at the same position with every session left in its range, or null if that cannot leave
 * out fewer sessions: it asked for that many, or its token is not a position in its order at offset 0. The
 * plugin sends no other ([readPastTies]); the where clause of one with an offset matches sessions that the
 * pages before returned, whose routes would fail the read again.
 */
private fun <T : Record> rereadOf(failed: ReadRecordsRequest<T>): ReadRecordsRequest<T>? {
    val position = failed.pageToken?.let { HealthConnectPosition.decode(it) ?: return null }
    if (position != null && (position.offset != 0 || position.descending == failed.ascendingOrder)) return null
    if (failed.pageSize >= HC_MAX_RECORDS) return null
    return ReadRecordsRequest(
        failed.recordType, failed.timeRangeFilter, failed.dataOriginFilter, failed.ascendingOrder, HC_MAX_RECORDS,
        failed.pageToken,
    )
}

/**
 * Whether [error], from a read of [recordType] on Android [sdkInt], is Health Connect's failure on a route
 * outside the page: an exercise session read on Android 14 or 15 that failed with exactly
 * IllegalStateException(HealthConnectException(ERROR_INTERNAL, "java.lang.NullPointerException: Attempt to
 * invoke virtual method 'int java.lang.Integer.intValue()' on a null object reference")).
 */
// sdkInt is Build.VERSION.SDK_INT (a parameter for the tests), so HealthConnectException exists.
@SuppressLint("NewApi")
internal fun isRouteOutsidePage(error: Throwable, recordType: KClass<out Record>, sdkInt: Int): Boolean {
    if (recordType != ExerciseSessionRecord::class) return false
    if (sdkInt != Build.VERSION_CODES.UPSIDE_DOWN_CAKE && sdkInt != Build.VERSION_CODES.VANILLA_ICE_CREAM) return false
    val cause = (error as? IllegalStateException)?.cause ?: return false
    return cause.message == ROUTE_OUTSIDE_PAGE && isInternalError(cause)
}

@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
private fun isInternalError(error: Throwable): Boolean =
    error is HealthConnectException && error.errorCode == HealthConnectException.ERROR_INTERNAL

/** Health Connect's message for the NullPointerException of ExerciseSessionRecordHelper.readExtraData. */
internal const val ROUTE_OUTSIDE_PAGE =
    "java.lang.NullPointerException: Attempt to invoke virtual method 'int java.lang.Integer.intValue()' " +
        "on a null object reference"

// Only exercise sessions are read again ([isRouteOutsidePage]) and cut ([RecordsPage.cut]).
private fun startTime(record: Record): Long = (record as ExerciseSessionRecord).startTime.toEpochMilli()
