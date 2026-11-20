package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.time.TimeRangeFilter
import java.lang.reflect.Proxy

// More reads than any test makes: a read that goes round fails the test instead of hanging it.
private const val MAX_READS = 500

/**
 * [inner] with its reads replaced by reads of [records] as Health Connect makes them from android14-qpr2-release
 * on (RecordHelper.getNextInternalRecordsPageAndToken), as measured on Android 15 (module 350820300): a record is
 * in a time range when its time ([pagingTimeMillis]) is, the records come by time (newest first if the request or
 * its token says so), ties in the order they were written (row id), and a page token is PageTokenWrapper's. A
 * read skips the token's offset of rows of the read's join of its time ([joinRows]), so a record may come
 * without some of its samples, stages or laps; the next token's offset counts only the records of its time on
 * this page. Every other call goes to [inner]. Each read request is added to [requests]; more than [MAX_READS]
 * throw AssertionError. With [reads] = [readByStartTime], the reads are those of android14-release instead.
 */
internal fun tiedTokenStore(
    records: List<Record>,
    inner: HealthConnectClient = fakeHealthConnect { method, _ -> throw UnsupportedOperationException(method) },
    requests: MutableList<ReadRecordsRequest<*>> = mutableListOf(),
    reads: (List<Record>, ReadRecordsRequest<*>) -> ReadRecordsResponse<Record> = ::readByPosition,
): HealthConnectClient =
    Proxy.newProxyInstance(HealthConnectClient::class.java.classLoader, arrayOf(HealthConnectClient::class.java)) {
            _, method, args ->
        if (method.name == "readRecords") {
            val request = args.first() as ReadRecordsRequest<*>
            requests.add(request)
            if (requests.size > MAX_READS) throw AssertionError("More than $MAX_READS reads, at ${request.pageToken}")
            reads(records, request)
        } else {
            Proxy.getInvocationHandler(inner).invoke(inner, method, args)
        }
    } as HealthConnectClient

/** The reply to [request] from [stored] (in the order written), as [tiedTokenStore] reads. */
internal fun readByPosition(stored: List<Record>, request: ReadRecordsRequest<*>): ReadRecordsResponse<Record> {
    val token = request.pageToken?.let { requireNotNull(HealthConnectPosition.decode(it)) { "Not a position: $it" } }
    val ascending = token?.let { !it.descending } ?: request.ascendingOrder
    val cursor = matching(stored, request, ascending, token?.timeMillis).toMutableList()
    // The token's offset of rows of the first record's time are skipped: the pages before returned them.
    val first = cursor.firstOrNull()?.let(::time)
    var skip = token?.offset ?: 0
    while (skip > 0 && cursor.isNotEmpty() && time(cursor[0]) == first) {
        val rows = joinRows(cursor[0])
        if (skip < rows) cursor[0] = withoutRows(cursor[0], skip) else cursor.removeAt(0)
        skip -= rows
    }
    val page = cursor.take(request.pageSize)
    val next = cursor.getOrNull(page.size) ?: return ReadRecordsResponse(page, null)
    // The offset counts the records of the next one's time on this page only, not those the token skipped.
    val offset = page.takeLastWhile { time(it) == time(next) }.size
    return ReadRecordsResponse(page, HealthConnectPosition(!ascending, time(next), offset).encode())
}

/** Whether no request of [requests] sent Health Connect a page token with an offset. */
internal fun noOffsets(requests: List<ReadRecordsRequest<*>>): Boolean =
    requests.mapNotNull { it.pageToken }.all { HealthConnectPosition.decode(it)?.offset == 0 }

/** The requests of [requests] that read every record of one start time ([pastTies]): no token, a range of 1 ms. */
internal fun tieReads(requests: List<ReadRecordsRequest<*>>): List<ReadRecordsRequest<*>> = requests.filter {
    val range = it.timeRangeFilter
    it.pageToken == null && range.endTime!!.toEpochMilli() - range.startTime!!.toEpochMilli() == 1L
}

/**
 * The reply to [request] from [stored] (in the order written) as android14-release and android14-qpr1-release
 * read (RecordHelper.getInternalRecords, TransactionManager.readRecordsAndGetNextToken): the where clause holds
 * the records from the token's time on, of which pageSize + 1 are read, and the records of one time come only
 * together: those of the first time where another time follows among them, any other where they fit in the
 * page. The token is the time of the first record left out, without an offset; so where more records start at
 * the first time than the page holds, the page is empty and its token that of the first time, the request's own.
 */
internal fun readByStartTime(stored: List<Record>, request: ReadRecordsRequest<*>): ReadRecordsResponse<Record> {
    val token = request.pageToken?.let { requireNotNull(HealthConnectPosition.decode(it)) { "Not a token: $it" } }
    require(token == null || token.offset == 0) { "An android14-release token has no offset: ${request.pageToken}" }
    val ascending = token?.let { !it.descending } ?: request.ascendingOrder
    val groups = matching(stored, request, ascending, token?.timeMillis).take(request.pageSize + 1).groupBy(::time)
    val times = groups.keys.toList()
    val page = mutableListOf<Record>()
    for ((index, at) in times.withIndex()) {
        val ties = groups.getValue(at)
        val last = index == times.lastIndex
        if ((index == 0 && !last) || page.size + ties.size <= request.pageSize) page += ties
        else return ReadRecordsResponse(page, HealthConnectPosition(!ascending, at, 0).encode())
        if (page.size >= request.pageSize && !last) {
            return ReadRecordsResponse(page, HealthConnectPosition(!ascending, times[index + 1], 0).encode())
        }
    }
    return ReadRecordsResponse(page, null)
}

/**
 * The records of [stored] that the where clause of [request] matches (type, data origins, range, and from
 * the token's time [fromTime] on, newest first: up to it), ordered by time, then in the order written.
 */
private fun matching(
    stored: List<Record>,
    request: ReadRecordsRequest<*>,
    ascending: Boolean,
    fromTime: Long?,
): List<Record> {
    val origins = request.dataOriginFilter
    fun fromToken(time: Long) = fromTime == null || if (ascending) time >= fromTime else time <= fromTime
    return stored.withIndex()
        .filter { (_, record) -> request.recordType.isInstance(record) }
        .filter { (_, record) -> origins.isEmpty() || record.metadata.dataOrigin in origins }
        .filter { (_, record) -> inRange(time(record), request.timeRangeFilter) && fromToken(time(record)) }
        .sortedWith(compareBy({ if (ascending) time(it.value) else -time(it.value) }, { it.index }))
        .map { it.value }
}

private fun inRange(time: Long, range: TimeRangeFilter): Boolean =
    range.startTime.let { it == null || time >= it.toEpochMilli() } &&
        range.endTime.let { it == null || time < it.toEpochMilli() }

private fun time(record: Record): Long = pagingTimeMillis(record)!!
