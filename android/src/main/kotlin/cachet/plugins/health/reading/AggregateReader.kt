package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.request.AggregateGroupByDurationRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Volume
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.intList
import cachet.plugins.health.requireLong
import cachet.plugins.health.requireString
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant

/**
 * Reads data aggregated over time intervals, for getAggregateData and getIntervalData. Sleep types
 * are bucketed from their data points ([SleepIntervalReader]), every other type with the aggregate
 * metric of [HealthConstants.mapToAggregateMetric]; a type without either has no intervals.
 */
internal class AggregateReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val sleepIntervals: SleepIntervalReader,
) {
    fun getAggregateData(call: MethodCall, result: Result) {
        scope.launch(Dispatchers.Default) {
            try {
                val dataType = call.requireString("dataTypeKey")
                val interval = Duration.ofSeconds(call.requireLong("interval"))
                val startTime = Instant.ofEpochMilli(call.requireLong("startTime"))
                val endTime = Instant.ofEpochMilli(call.requireLong("endTime"))
                val metric = HealthConstants.mapToAggregateMetric[dataType]

                val healthConnectData = when {
                    dataType in sleepTypes -> sleepIntervals.readIntervals(
                        dataType, startTime, endTime, interval, call.intList("recordingMethodsToFilter")
                    )
                    metric != null -> readBuckets(metric, startTime, endTime, interval)
                    else -> emptyList()
                }
                result.success(healthConnectData)
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getAggregateData")
            }
        }
    }

    private suspend fun readBuckets(
        metric: AggregateMetric<Any>,
        startTime: Instant,
        endTime: Instant,
        interval: Duration,
    ): List<Map<String, Any>> {
        val request = AggregateGroupByDurationRequest(
            metrics = setOf(metric),
            timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
            timeRangeSlicer = interval
        )
        // Health Connect returns every bucket of the range, one without data with a null value: it is
        // left out, as 0 would be a wrong value for averages such as heart rate.
        return healthConnectClient.aggregateGroupByDuration(request).mapNotNull { bucket ->
            bucket.result[metric]?.let { value ->
                bucketData(
                    aggregateValue(value),
                    bucket.startTime,
                    bucket.endTime,
                    bucket.result.dataOrigins.map { origin -> origin.packageName },
                )
            }
        }
    }

    companion object {
        /**
         * [value] of an aggregate metric in the default unit of its data type on the Dart side.
         * Throws UnsupportedOperationException for a value type the method channel cannot send.
         */
        internal fun aggregateValue(value: Any): Any = when (value) {
            is Number -> value
            is Length -> value.inMeters
            is Energy -> value.inKilocalories
            is TemperatureDelta -> value.inCelsius
            is Mass -> value.inKilograms
            is Volume -> value.inLiters
            is Power -> value.inWatts
            is Duration -> value.toMillis() / 60_000.0
            else -> throw UnsupportedOperationException("Aggregate values of type ${value.javaClass.name} are not supported")
        }

        /** The reply map of a bucket [startTime, endTime) holding [value], from the apps [packageNames]. */
        internal fun bucketData(
            value: Any,
            startTime: Instant,
            endTime: Instant,
            packageNames: List<String>,
        ): Map<String, Any> {
            val sourceName = packageNames.joinToString()
            return mapOf(
                "value" to value,
                "date_from" to startTime.toEpochMilli(),
                "date_to" to endTime.toEpochMilli(),
                "source_name" to sourceName,
                "source_id" to "",
                "is_manual_entry" to sourceName.contains("user_input")
            )
        }
    }
}
