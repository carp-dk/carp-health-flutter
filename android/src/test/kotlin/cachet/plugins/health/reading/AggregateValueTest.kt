package cachet.plugins.health.reading

import androidx.health.connect.client.aggregate.AggregateMetric
import androidx.health.connect.client.aggregate.AggregationResult
import androidx.health.connect.client.aggregate.AggregationResultGroupedByDuration
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ActivityIntensityRecord
import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Volume
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.RecordingResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMessageCodec
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
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
        TotalCaloriesBurnedRecord.ENERGY_TOTAL to (Energy.kilocalories(2000.0) to 2000.0),
        PowerRecord.POWER_AVG to (Power.watts(215.0) to 215.0),
        CyclingPedalingCadenceRecord.RPM_AVG to (90.5 to 90.5),
        ActivityIntensityRecord.INTENSITY_MINUTES_TOTAL to (Duration.ofMinutes(30).plusSeconds(30) to 30.5),
        SkinTemperatureRecord.TEMPERATURE_DELTA_AVG to (TemperatureDelta.celsius(0.3) to 0.3),
    )

    private val start = Instant.parse("2026-11-08T00:00:00Z")

    /** Replies getIntervalData for three hourly buckets of [dataType] while Health Connect answers [answer]. */
    private fun getIntervalData(dataType: String, answer: (method: String, args: List<Any?>) -> Any?): Any? {
        val client = fakeHealthConnect(answer)
        val job = Job()
        val sleepIntervals = SleepIntervalReader(client, HealthRecordingFilter())
        val reader = AggregateReader(client, CoroutineScope(Dispatchers.Unconfined + job), sleepIntervals)
        val arguments = hashMapOf<String, Any>(
            "dataTypeKey" to dataType,
            "interval" to 3600,
            "startTime" to start.toEpochMilli(),
            "endTime" to start.plus(Duration.ofHours(3)).toEpochMilli(),
            "recordingMethodsToFilter" to emptyList<Int>(),
        )
        val reply = RecordingResult()
        reader.getAggregateData(MethodCall("getIntervalData", arguments), reply)
        // The reader replies from a coroutine on another thread: wait until that has ended.
        job.complete()
        runBlocking { withTimeout(30_000) { job.join() } }
        assertEquals("replies", 1, reply.replies)
        assertNull(reply.message, reply.code)
        return reply.value
    }

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
    fun cyclingIntervalsAreAveragePowerAndCadence() {
        assertEquals(PowerRecord.POWER_AVG, HealthConstants.mapToAggregateMetric["POWER"])
        assertEquals(CyclingPedalingCadenceRecord.RPM_AVG, HealthConstants.mapToAggregateMetric["CYCLING_CADENCE"])
    }

    @Test
    fun anIntervalWithoutDataIsNotSent() {
        // Health Connect returns every bucket of the range; one without data has no value (0 BPM would be wrong).
        fun bucket(hour: Long, bpm: Long?) = AggregationResultGroupedByDuration(
            AggregationResult(
                if (bpm == null) emptyMap() else mapOf(HeartRateRecord.BPM_AVG.metricKey to bpm),
                emptyMap(),
                if (bpm == null) emptySet() else setOf(DataOrigin("com.example.watch")),
            ),
            start.plus(Duration.ofHours(hour)),
            start.plus(Duration.ofHours(hour + 1)),
            ZoneOffset.UTC,
        )
        val reply = getIntervalData(HealthConstants.HEART_RATE) { method, _ ->
            check(method == "aggregateGroupByDuration") { "Unexpected call of $method" }
            listOf(bucket(0, null), bucket(1, 72), bucket(2, null))
        }
        val expected = mapOf(
            "value" to 72L,
            "date_from" to start.plus(Duration.ofHours(1)).toEpochMilli(),
            "date_to" to start.plus(Duration.ofHours(2)).toEpochMilli(),
            "source_name" to "com.example.watch",
            "source_id" to "",
            "is_manual_entry" to false,
        )
        assertEquals(listOf(expected), reply)
    }

    @Test
    fun sleepIntervalsAreTheMinutesOfTheirDataPoints() {
        // SleepSessionRecord.SLEEP_DURATION_TOTAL would be the whole session, whatever the stage.
        for (type in sleepTypes + HealthConstants.SLEEP_IN_BED) {
            assertNull(type, HealthConstants.mapToAggregateMetric[type])
        }
        // Asleep from an hour before the read until half an hour into it, then in deep sleep.
        val bedtime = start.minus(Duration.ofHours(1))
        val deep = start.plusSeconds(1800)
        val wakeUp = start.plus(Duration.ofHours(2))
        val night = sleepSession(
            bedtime, wakeUp,
            stages = listOf(
                SleepSessionRecord.Stage(bedtime, deep, SleepSessionRecord.STAGE_TYPE_SLEEPING),
                SleepSessionRecord.Stage(deep, wakeUp, SleepSessionRecord.STAGE_TYPE_DEEP),
            ),
        )
        val reply = getIntervalData(HealthConstants.SLEEP_ASLEEP) { method, _ ->
            check(method == "readRecords") { "Unexpected call of $method" }
            ReadRecordsResponse(listOf(night), null)
        }
        assertEquals(listOf(30.0), (reply as List<*>).map { (it as Map<*, *>)["value"] })
    }

    @Test
    fun sleepInBedIsNotAHealthConnectType() {
        val reply = getIntervalData(HealthConstants.SLEEP_IN_BED) { method, _ -> error("Unexpected call of $method") }
        assertEquals(emptyList<Any>(), reply)
    }

    @Test
    fun otherValueTypesAreNotSupported() {
        val error = assertThrows(UnsupportedOperationException::class.java) { AggregateReader.aggregateValue(Any()) }
        assertEquals(HealthErrors.NOT_SUPPORTED, HealthErrors.codeFor(error, null))
    }
}
