package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.request.AggregateGroupByDurationRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Volume
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.requireLong
import cachet.plugins.health.requireString
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant

/** Reads data aggregated over time intervals, for getAggregateData and getIntervalData. */
internal class AggregateReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun getAggregateData(call: MethodCall, result: Result) {
        scope.launch(Dispatchers.Default) {
            try {
                val dataType = call.requireString("dataTypeKey")
                val interval = call.requireLong("interval")
                val startTime = Instant.ofEpochMilli(call.requireLong("startTime"))
                val endTime = Instant.ofEpochMilli(call.requireLong("endTime"))
                val healthConnectData = mutableListOf<Map<String, Any?>>()

                HealthConstants.mapToAggregateMetric[dataType]?.let { metricClassType ->
                    val request = AggregateGroupByDurationRequest(
                        metrics = setOf(metricClassType),
                        timeRangeFilter = TimeRangeFilter.between(startTime, endTime),
                        timeRangeSlicer = Duration.ofSeconds(interval)
                    )
                    val response = healthConnectClient.aggregateGroupByDuration(request)

                    for (durationResult in response) {
                        val totalValue = aggregateValue(durationResult.result[metricClassType])
                        val packageNames = durationResult.result.dataOrigins
                            .joinToString { origin -> origin.packageName }

                        val data = mapOf<String, Any>(
                            "value" to totalValue,
                            "date_from" to durationResult.startTime.toEpochMilli(),
                            "date_to" to durationResult.endTime.toEpochMilli(),
                            "source_name" to packageNames,
                            "source_id" to "",
                            "is_manual_entry" to packageNames.contains("user_input")
                        )
                        healthConnectData.add(data)
                    }
                }
                result.success(healthConnectData)
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getAggregateData")
            }
        }
    }

    companion object {
        /**
         * [value] of an aggregate metric in the default unit of its data type on the Dart side, or 0
         * for an interval without data. Throws UnsupportedOperationException for a value type the
         * method channel cannot send.
         */
        internal fun aggregateValue(value: Any?): Any = when (value) {
            null -> 0
            is Number -> value
            is Length -> value.inMeters
            is Energy -> value.inKilocalories
            is TemperatureDelta -> value.inCelsius
            is Mass -> value.inKilograms
            is Volume -> value.inLiters
            is Duration -> value.toMillis() / 60_000.0
            else -> throw UnsupportedOperationException("Aggregate values of type ${value.javaClass.name} are not supported")
        }
    }
}
