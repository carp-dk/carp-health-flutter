package cachet.plugins.health.reading

import android.os.Build
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
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

/** Reads, converts and replies the pages of getDataPage. */
internal class DataPageReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val dataConverter: HealthDataConverter,
    private val converter: RecordConverter,
    private val routes: WorkoutRoutes,
    private val lookback: SeriesLookback,
    private val sleepLookback: SleepLookback,
    private val heartRate: HeartRatePageReader,
) {
    // At most two pages in memory at once, however many reads the app runs in parallel.
    private val pageReads = Semaphore(2)

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
     * Reads, converts and sends the page [request] asks for. A page that turns out too large is
     * dropped before anything is sent and the same position is read again with fewer records;
     * every such retry costs one more Health Connect call.
     */
    private suspend fun replyPage(request: DataPageRequest, result: Result) {
        val firstPage = request.isFirstPage
        // Workouts need the grants on every page to know which totals they may read.
        val granted =
            if (firstPage || request.dataType == WORKOUT) {
                healthConnectClient.permissionController.getGrantedPermissions()
            } else {
                emptySet()
            }
        if (firstPage && !granted.contains(HealthPermission.getReadPermission(request.recordType))) {
            // Without read permission there is no data, as on iOS; the flag tells the app why.
            result.success(
                mapOf("data" to emptyList<Map<String, Any?>>(), "nextPageToken" to null, "permissionDenied" to true)
            )
            return
        }
        if (request.isSliced) {
            val page = heartRate.readPage(request.startTime, request.endTime, request.pageSize, request.sliceToken)
            val data = mutableListOf<Map<String, Any?>>()
            converter.convertRecords(
                page.records,
                request.dataType,
                request.dataUnit,
                request.startTime,
                request.endTime,
                request.recordingMethodsToFilter,
                granted,
                data
            )
            result.success(mapOf("data" to data, "nextPageToken" to page.next?.encode()))
            return
        }

        val sdkInt = Build.VERSION.SDK_INT
        var records = request.token?.records ?: request.firstRecords(sdkInt)
        var probeRecords = SeriesPageSizer.cap(request.pageSize)
        var retries = 0
        while (true) {
            try {
                val canShrink = retries < MAX_SHRINK_RETRIES
                val fewer = readAndReplyPage(request, granted, records, probeRecords, canShrink, sdkInt, result)
                    ?: return
                Log.i("FLUTTER_HEALTH", "${request.dataType}: re-reading a page of $records records with $fewer")
                records = fewer
            } catch (e: Throwable) {
                // Last resort: Health Connect cannot return the page, or it does not fit in memory.
                // A first series page starts at one record, but its lookback can still read fewer.
                val canReadLess =
                    records > 1 || (firstPage && request.isSeries && probeRecords > SERIES_PROBE_RECORDS_RETRY)
                if (!HealthErrors.isDataTooLarge(e) || !canReadLess || retries >= MAX_SHRINK_RETRIES) throw e
                Log.w("FLUTTER_HEALTH", "${request.dataType}: a page of $records records is too large, re-reading: $e")
                records = maxOf(1, records / 10)
                probeRecords = SERIES_PROBE_RECORDS_RETRY
            }
            retries++
        }
    }

    /**
     * Reads [records] records at the position of [request], converts them and replies, then returns
     * null. An oversized series page is dropped instead when [canShrink]: nothing is sent, and the
     * fewer records to read the same position with are returned. The first page of a series or sleep
     * stage read also converts the records that began before the range and reach into it
     * ([SeriesLookback], [SleepLookback]); later pages cost no such read.
     */
    private suspend fun readAndReplyPage(
        request: DataPageRequest,
        granted: Set<String>,
        records: Int,
        probeRecords: Int,
        canShrink: Boolean,
        sdkInt: Int,
        result: Result,
    ): Int? {
        val response = healthConnectClient.readRecords(
            ReadRecordsRequest(
                recordType = request.recordType,
                timeRangeFilter = TimeRangeFilter.between(request.startTime, request.endTime),
                pageSize = records,
                pageToken = request.token?.healthConnectToken,
            )
        )

        var nextRecords = records
        var earlier = emptyList<Record>()
        if (request.isSeries) {
            // Samples before the window and recording filters: what the page costs to convert.
            var rawSamples = 0L
            var maxSamples = 0
            for (record in response.records) {
                val samples = dataConverter.sampleCount(record)
                rawSamples += samples
                maxSamples = maxOf(maxSamples, samples)
            }
            if (canShrink && sdkInt >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val raw = rawSamples.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
                SeriesPageSizer.shrinkForOversize(records, request.pageSize, raw)?.let { return it }
            }
            nextRecords = SeriesPageSizer.nextRecords(records, request.pageSize, maxSamples, sdkInt)
            if (request.isFirstPage) {
                earlier = lookback.readLookbackRecords(
                    request.recordType,
                    request.startTime,
                    probeRecords,
                    response.records.mapTo(HashSet()) { it.metadata.id }
                )
            }
        } else if (request.isFirstPage && request.isSleepStage) {
            // The sessions that began before the range, for their stages that start inside it.
            earlier = sleepLookback.readLookbackSessions(
                request.startTime,
                response.records.mapTo(HashSet()) { it.metadata.id }
            )
        }

        val data = mutableListOf<Map<String, Any?>>()
        if (request.dataType == HealthConstants.WORKOUT_ROUTE) {
            routes.appendWorkoutRoutes(
                response.records.filterIsInstance<ExerciseSessionRecord>(),
                request.recordingMethodsToFilter,
                data
            )
        } else {
            converter.convertRecords(
                earlier + response.records,
                request.dataType,
                request.dataUnit,
                request.startTime,
                request.endTime,
                request.recordingMethodsToFilter,
                granted,
                data
            )
        }
        val next = response.pageToken?.takeIf { it.isNotEmpty() }?.let { DataPageToken(nextRecords, it).encode() }
        result.success(mapOf("data" to data, "nextPageToken" to next))
        return null
    }
}
