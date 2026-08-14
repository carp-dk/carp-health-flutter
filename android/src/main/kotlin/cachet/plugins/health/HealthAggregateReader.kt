package cachet.plugins.health

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateGroupByDurationRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.TemperatureDelta
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Aggregate Health Connect read operations exposed to Flutter.
 */
class HealthAggregateReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val recordingFilter: HealthRecordingFilter,
) {
    /** Aggregated data points sliced by the Flutter-requested interval. */
    fun getAggregateData(call: MethodCall, result: Result) {
        val dataType = call.argument<String>("dataTypeKey")!!
        val interval = call.argument<Long>("interval")!!
        val startTime = Instant.ofEpochMilli(call.argument<Long>("startTime")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("endTime")!!)
        val healthConnectData = mutableListOf<Map<String, Any?>>()
        scope.launch {
            try {
                HealthConstants.mapToAggregateMetric[dataType]?.let { metricClassType ->
                    val request = AggregateGroupByDurationRequest(
                        metrics = setOf(metricClassType),
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                        timeRangeSlicer = Duration.ofSeconds(interval),
                    )
                    for (durationResult in healthConnectClient.aggregateGroupByDuration(request)) {
                        var totalValue = durationResult.result[metricClassType]
                        if (totalValue is Length) totalValue = totalValue.inMeters
                        if (totalValue is Energy) totalValue = totalValue.inKilocalories
                        if (totalValue is TemperatureDelta) totalValue = totalValue.inCelsius
                        val packageNames = durationResult.result.dataOrigins
                            .joinToString { origin -> origin.packageName }
                        healthConnectData.add(
                            mapOf(
                                "value" to (totalValue ?: 0),
                                "date_from" to durationResult.startTime.toEpochMilli(),
                                "date_to" to durationResult.endTime.toEpochMilli(),
                                "source_name" to packageNames,
                                "source_id" to "",
                                "is_manual_entry" to packageNames.contains("user_input"),
                            )
                        )
                    }
                }
                result.success(healthConnectData)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(null)
            }
        }
    }

    /** Interval data points backed by aggregate reads. */
    fun getIntervalData(call: MethodCall, result: Result) = getAggregateData(call, result)

    /** Total step count, optionally filtered by recording method. */
    fun getTotalStepsInInterval(call: MethodCall, result: Result) {
        val start = call.argument<Long>("startTime")!!
        val end = call.argument<Long>("endTime")!!
        val filters = call.argument<List<Int>>("recordingMethodsToFilter")!!
        if (filters.isEmpty()) getAggregatedStepCount(start, end, result)
        else getStepCountFiltered(start, end, filters, result)
    }

    private fun getAggregatedStepCount(start: Long, end: Long, result: Result) {
        scope.launch {
            try {
                val response = healthConnectClient.aggregate(
                    AggregateRequest(
                        metrics = setOf(StepsRecord.COUNT_TOTAL),
                        timeRangeFilter = TimeRangeFilter.between(
                            Instant.ofEpochMilli(start),
                            Instant.ofEpochMilli(end),
                        ),
                    )
                )
                result.success(response[StepsRecord.COUNT_TOTAL] ?: 0L)
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(null)
            }
        }
    }

    private fun getStepCountFiltered(
        start: Long,
        end: Long,
        recordingMethodsToFilter: List<Int>,
        result: Result,
    ) {
        scope.launch {
            try {
                val response = healthConnectClient.readRecords(
                    ReadRecordsRequest(
                        recordType = StepsRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(
                            Instant.ofEpochMilli(start),
                            Instant.ofEpochMilli(end),
                        ),
                    )
                )
                val records = recordingFilter.filterRecordsByRecordingMethods(
                    recordingMethodsToFilter,
                    response.records,
                )
                result.success(records.sumOf { (it as StepsRecord).count.toInt() })
            } catch (e: Exception) {
                Log.e("FLUTTER_HEALTH::ERROR", Log.getStackTraceString(e))
                result.success(null)
            }
        }
    }
}
