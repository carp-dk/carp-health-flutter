package cachet.plugins.health.reading

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.intList
import cachet.plugins.health.requireLong
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant

/** Reads the total step count of an interval, for getTotalStepsInInterval. */
internal class TotalStepsReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val recordingFilter: HealthRecordingFilter,
) {
    fun getTotalStepsInInterval(call: MethodCall, result: Result) {
        scope.launch(Dispatchers.Default) {
            try {
                val start = Instant.ofEpochMilli(call.requireLong("startTime"))
                val end = Instant.ofEpochMilli(call.requireLong("endTime"))
                val recordingMethodsToFilter = call.intList("recordingMethodsToFilter")

                val steps =
                    if (recordingMethodsToFilter.isEmpty()) {
                        getAggregatedStepCount(start, end)
                    } else {
                        getStepCountFiltered(start, end, recordingMethodsToFilter)
                    }
                result.success(steps)
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getTotalStepsInInterval")
            }
        }
    }

    // --------- Private Methods ---------

    /**
     * Retrieves aggregated step count using Health Connect's built-in aggregation.
     * Provides optimized step counting when no filtering is required.
     *
     * @param start Start of the interval
     * @param end End of the interval
     * @return Step count
     */
    private suspend fun getAggregatedStepCount(start: Instant, end: Instant): Long {
        val response = healthConnectClient.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(start, end),
            ),
        )
        val stepsInInterval = response[StepsRecord.COUNT_TOTAL] ?: 0L

        Log.i("FLUTTER_HEALTH::SUCCESS", "returning $stepsInInterval steps")
        return stepsInInterval
    }

    /**
     * Retrieves step count with recording method filtering applied.
     * Manually sums individual step records after applying specified filters.
     *
     * @param start Start of the interval
     * @param end End of the interval
     * @param recordingMethodsToFilter List of recording methods to exclude
     * @return Filtered step count
     */
    private suspend fun getStepCountFiltered(
        start: Instant,
        end: Instant,
        recordingMethodsToFilter: List<Int>,
    ): Long {
        // Every page counts: a day of per-minute step records is already more than one page.
        // Each page is dropped once it is summed.
        var totalSteps = 0L
        var pageToken: String? = null
        do {
            val response = healthConnectClient.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                    pageSize = HC_MAX_RECORDS,
                    pageToken = pageToken,
                )
            )
            totalSteps += recordingFilter
                .filterRecordsByRecordingMethods(recordingMethodsToFilter, response.records)
                .sumOf { (it as StepsRecord).count }
            pageToken = response.pageToken?.takeIf { it.isNotEmpty() }
        } while (pageToken != null)

        Log.i(
            "FLUTTER_HEALTH::SUCCESS",
            "returning $totalSteps steps (excluding $recordingMethodsToFilter)"
        )
        return totalSteps
    }
}
