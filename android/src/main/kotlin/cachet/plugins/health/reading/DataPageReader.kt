package cachet.plugins.health.reading

import android.os.Build
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthErrors
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

/**
 * Reads, converts and replies the pages of getDataPage. An app that may write a type but not read
 * it reads the records it wrote itself ([ReadAccess.OWN]), from [packageName], its heart rate with a
 * reader of its own records ([HeartRatePageReader.ownRecordsOnly]).
 */
internal class DataPageReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val dataConverter: HealthDataConverter,
    private val converter: RecordConverter,
    private val routes: WorkoutRoutes,
    private val lookback: SeriesLookback,
    private val sleepLookback: SleepLookback,
    private val heartRate: HeartRatePageReader,
    private val packageName: String,
    private val sdkInt: Int = Build.VERSION.SDK_INT,
) {
    // At most two pages in memory at once, however many reads the app runs in parallel.
    private val pageReads = Semaphore(2)
    private val ownHeartRate = heartRate.ownRecordsOnly(packageName)

    fun getDataPage(call: MethodCall, result: Result) {
        val request =
            try {
                DataPageRequest.from(call)
            } catch (e: Exception) {
                HealthErrors.report(result, e, "getDataPage")
                return
            }
        if (!request.startTime.isBefore(request.endTime)) {
            // TimeRangeFilter.between rejects an empty range, and 13.3.2 returned no data for it.
            result.success(mapOf("data" to emptyList<Map<String, Any?>>(), "nextPageToken" to null))
            return
        }

        scope.launch(Dispatchers.Default) {
            pageReads.withPermit {
                try {
                    replyPage(request, result)
                } catch (e: Throwable) {
                    HealthErrors.report(result, e, "getDataPage(${request.dataType})")
                }
            }
        }
    }

    /**
     * Reads, converts and sends the page [sent] asks for. A page that turns out too large is
     * dropped before anything is sent and the same position is read again with fewer records;
     * every such retry costs one more Health Connect call. A request with a limit is read the same
     * way, newest first ([DataPageRequest.limit]).
     *
     * Without read permission but with write permission, reads asks for app's own records only ([DataPageRequest.ownOnly]), and when every page is flagged
     * 'permissionDenied': the points are this app's own records, as on iOS when read access is
     * denied. With neither permission the first page is empty, last and flagged. The Health Connect
     * APK (Android 13 and lower) is closed source: if it refuses a read of the app's own records, the
     * page is replied as with neither permission.
     */
    private suspend fun replyPage(sent: DataPageRequest, result: Result) {
        // Workouts need the grants on every page to know which totals they may read.
        val granted =
            if (sent.isFirstPage || sent.dataType == WORKOUT) {
                healthConnectClient.permissionController.getGrantedPermissions()
            } else {
                emptySet()
            }
        // The first page decides from the grants which records the read returns; later pages keep it.
        val access = if (sent.isFirstPage) ReadAccess.of(granted, sent.recordType) else null
        if (access == ReadAccess.NONE) {
            // Neither read nor write permission: no data, and the flag tells the app why.
            result.success(DENIED_PAGE)
            return
        }
        val request = if (access == ReadAccess.OWN) sent.ownRecordsOnly() else sent
        try {
            readAndReply(request, granted, result)
        } catch (e: SecurityException) {
            if (!request.ownOnly || !ReadAccess.isOwnReadRefused(e, sdkInt)) throw e
            Log.w("FLUTTER_HEALTH", "${request.dataType}: Health Connect refused to read this app's own records: $e")
            result.success(DENIED_PAGE)
        }
    }

    /**
     * Reads, converts and sends the page [request] asks for, as [replyPage] describes. The app's own heart
     * rate goes in slices too, counted with a data origin filter of this app; where Health Connect refuses
     * that count (before Android 14 QPR2, the Health Connect APK, or in the background without
     * READ_HEALTH_DATA_IN_BACKGROUND), the read goes by record from its first page on. A sliced read that
     * goes to the background later fails there with PERMISSION_DENIED ([HeartRatePageReader]).
     */
    private suspend fun readAndReply(request: DataPageRequest, granted: Set<String>, result: Result) {
        if (request.isSliced) {
            val page =
                try {
                    val reader = if (request.ownOnly) ownHeartRate else heartRate
                    reader.readPage(request.startTime, request.endTime, request.pageSize, request.sliceToken)
                } catch (e: SecurityException) {
                    if (!request.ownOnly || !request.isFirstPage) throw e
                    Log.w("FLUTTER_HEALTH", "HEART_RATE: Health Connect refused to count this app's samples: $e")
                    readAndReply(request.readByRecord(), granted, result)
                    return
                }
            result.success(reply(request, convert(request, page.records, granted), page.next?.encode()))
            return
        }

        var records = request.token?.records ?: request.firstRecords(sdkInt)
        var probeRecords = SeriesPageSizer.cap(request.pageSize)
        var retries = 0
        while (true) {
            try {
                val canShrink = retries < MAX_SHRINK_RETRIES
                val fewer = readAndReplyPage(request, granted, records, probeRecords, canShrink, result)
                    ?: return
                Log.i("FLUTTER_HEALTH", "${request.dataType}: re-reading a page of $records records with $fewer")
                records = fewer
            } catch (e: Throwable) {
                // Last resort: Health Connect cannot return the page, or it does not fit in memory.
                // A first series page starts at one record, but its lookback can still read fewer.
                val canReadLess =
                    records > 1 ||
                        (request.looksBack && request.isSeries && probeRecords > SERIES_PROBE_RECORDS_RETRY)
                if (!HealthErrors.isDataTooLarge(e) || !canReadLess || retries >= MAX_SHRINK_RETRIES) throw e
                Log.w("FLUTTER_HEALTH", "${request.dataType}: a page of $records records is too large, re-reading: $e")
                records = maxOf(1, records / 10)
                probeRecords = SERIES_PROBE_RECORDS_RETRY
            }
            retries++
        }
    }

    /**
     * Reads [records] records at the position of [request], and every further one of the start time
     * the page ends inside ([readPastTies]), converts them and replies, then returns null. An oversized
     * series page is dropped instead when [canShrink] and fewer records leave out those of its last start
     * time ([recordsBeforeLastStart]): nothing is sent, and the fewer records to read the same position
     * with are returned. The first page of a series or sleep stage read without a limit also converts
     * the records that began before the range and reach into it ([SeriesLookback], [SleepLookback]);
     * later pages cost no such read. A read with a
     * limit asks for the records that start last first, on every page: the Health Connect APK
     * (Android 13 and lower) takes the order from each request, not from the page token. A page of
     * exercise sessions that Android 14 or 15 had to read again with the rest of the range
     * ([readRecordsPage]) is cut to the [records] sessions asked for and the further ones of the last
     * one's start time ([RecordsPage.cut]); with a limit, only the sessions it needs are converted
     * ([convertNewest]).
     */
    private suspend fun readAndReplyPage(
        request: DataPageRequest,
        granted: Set<String>,
        records: Int,
        probeRecords: Int,
        canShrink: Boolean,
        result: Result,
    ): Int? {
        val origins = ReadAccess.origins(request.ownOnly, packageName)
        val read = healthConnectClient.readRecordsPage(
            ReadRecordsRequest(
                recordType = request.recordType,
                timeRangeFilter = TimeRangeFilter.between(request.startTime, request.endTime),
                dataOriginFilter = origins,
                ascendingOrder = !request.isNewestFirst,
                pageSize = records,
                pageToken = request.token?.healthConnectToken,
            ),
            sdkInt,
        )
        // Without a limit, the next page starts at the first session left out (each workout costs its totals).
        val response = if (read.reread && request.limit == null) read.cut(records, request.isNewestFirst) else read

        var nextRecords = records
        var earlier = emptyList<Record>()
        if (request.isSeries) {
            // Samples before the window and recording filters: what the page costs to convert.
            val samples = response.records.map { dataConverter.sampleCount(it) }
            if (canShrink && sdkInt >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Only fewer records that leave out those of the page's last start time, which come whole.
                SeriesPageSizer.shrinkForOversize(samples, request.pageSize)
                    ?.takeIf { it <= recordsBeforeLastStart(response.records) }
                    ?.let { return it }
            }
            nextRecords = SeriesPageSizer.nextRecords(records, request.pageSize, samples.maxOrNull() ?: 0, sdkInt)
            if (request.looksBack) {
                earlier = lookback.readLookbackRecords(
                    request.recordType,
                    request.startTime,
                    probeRecords,
                    response.records.mapTo(HashSet()) { it.metadata.id },
                    origins,
                )
            }
        } else if (request.looksBack && request.isSleepStage) {
            // The sessions that began before the range, for their stages that start inside it.
            earlier = sleepLookback.readLookbackSessions(
                request.startTime,
                response.records.mapTo(HashSet()) { it.metadata.id },
                origins,
            )
        }

        var next = response.pageToken?.let { DataPageToken(nextRecords, it, request.ownOnly).encode() }
        val data =
            if (response.reread && request.limit != null) {
                val (newest, all) = convertNewest(request, response.records, granted, request.limit)
                // The rest of the sessions are older than the 'limit' points the Dart side now has.
                if (!all) next = null
                newest
            } else {
                convert(request, earlier + response.records, granted)
            }
        result.success(reply(request, data, next))
        return null
    }

    /**
     * The points of the newest of [records], a page of a read with a [limit] that holds more sessions than
     * asked for ([RecordsPage.reread]), converted a few at a time until there are [limit] of them, so that
     * totals are read only for the workouts the Dart side keeps; and whether every record was converted.
     */
    private suspend fun convertNewest(
        request: DataPageRequest,
        records: List<Record>,
        granted: Set<String>,
        limit: Int,
    ): Pair<List<Map<String, Any?>>, Boolean> {
        val data = mutableListOf<Map<String, Any?>>()
        var converted = 0
        while (converted < records.size && data.size < limit) {
            val until = minOf(records.size, converted + limit - data.size)
            data += convert(request, records.subList(converted, until), granted)
            converted = until
        }
        return data to (converted == records.size)
    }

    /** The reply of a page of [request]; each page of a read of the app's own records is flagged 'permissionDenied'. */
    private fun reply(request: DataPageRequest, data: List<Map<String, Any?>>, next: String?): Map<String, Any?> =
        if (request.ownOnly) {
            mapOf("data" to data, "nextPageToken" to next, "permissionDenied" to true)
        } else {
            mapOf("data" to data, "nextPageToken" to next)
        }

    /** The data points of [records]: workout routes from their sessions, any other type by [converter]. */
    private suspend fun convert(
        request: DataPageRequest,
        records: List<Record>,
        granted: Set<String>,
    ): List<Map<String, Any?>> {
        val data = mutableListOf<Map<String, Any?>>()
        if (request.dataType == HealthConstants.WORKOUT_ROUTE) {
            routes.appendWorkoutRoutes(
                records.filterIsInstance<ExerciseSessionRecord>(),
                request.recordingMethodsToFilter,
                data
            )
        } else {
            converter.convertRecords(
                records,
                request.dataType,
                request.dataUnit,
                request.startTime,
                request.endTime,
                request.recordingMethodsToFilter,
                granted,
                data
            )
        }
        return data
    }
}

// The reply of a read without read or write permission: empty, last, and flagged.
private val DENIED_PAGE: Map<String, Any?> =
    mapOf("data" to emptyList<Map<String, Any?>>(), "nextPageToken" to null, "permissionDenied" to true)
