package cachet.plugins.health.reading

import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ActivityIntensityRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Volume
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import io.flutter.plugin.common.StandardMessageCodec
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class AggregateValueTest {
    // A value of the type each metric returns, and that value in the Dart default unit of its data type.
    private val samples: Map<AggregateMetric<*>, Pair<Any, Number>> = mapOf(
        HeightRecord.HEIGHT_AVG to (Length.meters(1.8) to 1.8),
        WeightRecord.WEIGHT_AVG to (Mass.kilograms(70.5) to 70.5),
        StepsRecord.COUNT_TOTAL to (1234L to 1234L),
        ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL to (Energy.kilocalories(250.0) to 250.0),
        HeartRateRecord.BPM_AVG to (72L to 72L),
        DistanceRecord.DISTANCE_TOTAL to (Length.meters(5000.0) to 5000.0),
        HydrationRecord.VOLUME_TOTAL to (Volume.liters(1.5) to 1.5),
        SleepSessionRecord.SLEEP_DURATION_TOTAL to (Duration.ofMinutes(420).plusSeconds(30) to 420.5),
        TotalCaloriesBurnedRecord.ENERGY_TOTAL to (Energy.kilocalories(2000.0) to 2000.0),
        ActivityIntensityRecord.INTENSITY_MINUTES_TOTAL to (Duration.ofMinutes(30) to 30.0),
        SkinTemperatureRecord.TEMPERATURE_DELTA_AVG to (TemperatureDelta.celsius(0.3) to 0.3),
    )

    @Test
    fun everyMetricIsSentInTheDefaultUnitOfItsType() {
        // A metric added to mapToAggregateMetric needs a sample here.
        assertEquals(HealthConstants.mapToAggregateMetric.values.toSet(), samples.keys)
        for ((metric, sample) in samples) {
            val (value, expected) = sample
            val sent = AggregateReader.aggregateValue(value)
            assertEquals("$metric", expected.toDouble(), (sent as Number).toDouble(), 1e-9)
            // The method channel's codec throws for anything it cannot send.
            StandardMessageCodec.INSTANCE.encodeMessage(mapOf("value" to sent))
        }
    }

    @Test
    fun heartRateIntervalsAreAverageBeatsPerMinute() {
        assertEquals(HeartRateRecord.BPM_AVG, HealthConstants.mapToAggregateMetric["HEART_RATE"])
    }

    @Test
    fun anIntervalWithoutDataIsZero() {
        assertEquals(0, AggregateReader.aggregateValue(null))
    }

    @Test
    fun otherValueTypesAreNotSupported() {
        val error = assertThrows(UnsupportedOperationException::class.java) { AggregateReader.aggregateValue(Any()) }
        assertEquals(HealthErrors.NOT_SUPPORTED, HealthErrors.codeFor(error, null))
    }
}
