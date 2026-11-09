package cachet.plugins.health

import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Temperature
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Velocity
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class ConverterWindowTest {
    private val converter = HealthDataConverter()
    private val start = Instant.parse("2026-11-08T10:00:00Z")
    private val end = start.plusSeconds(600)

    // One sample just before the window, one at its start, one just before its end and one at its end.
    private val times = listOf(start.minusMillis(1), start, end.minusMillis(1), end)
    private val inWindow = listOf(start.toEpochMilli(), end.toEpochMilli() - 1)

    private val heartRate = HeartRateRecord(
        startTime = start.minusSeconds(300),
        startZoneOffset = null,
        endTime = end.plusSeconds(300),
        endZoneOffset = null,
        samples = times.map { HeartRateRecord.Sample(it, 60) },
        metadata = Metadata.manualEntry(),
    )
    private val speed = SpeedRecord(
        startTime = start.minusSeconds(300),
        startZoneOffset = null,
        endTime = end.plusSeconds(300),
        endZoneOffset = null,
        samples = times.map { SpeedRecord.Sample(it, Velocity.metersPerSecond(1.5)) },
        metadata = Metadata.manualEntry(),
    )
    private val skinTemperature = SkinTemperatureRecord(
        startTime = start.minusSeconds(300),
        startZoneOffset = null,
        endTime = end.plusSeconds(300),
        endZoneOffset = null,
        metadata = Metadata.manualEntry(),
        deltas = times.map { SkinTemperatureRecord.Delta(it, TemperatureDelta.celsius(0.5)) },
        baseline = Temperature.celsius(33.0),
        measurementLocation = SkinTemperatureRecord.MEASUREMENT_LOCATION_WRIST,
    )

    private fun dates(points: List<Map<String, Any?>>) = points.map { it["date_from"] }

    @Test
    fun heartRateKeepsSamplesFromStartUntilBeforeEnd() {
        assertEquals(inWindow, dates(converter.convertRecord(heartRate, "HEART_RATE", null, start, end)))
    }

    @Test
    fun speedKeepsSamplesFromStartUntilBeforeEnd() {
        assertEquals(inWindow, dates(converter.convertRecord(speed, "SPEED", null, start, end)))
    }

    @Test
    fun skinTemperatureKeepsDeltasFromStartUntilBeforeEnd() {
        val points = converter.convertRecord(skinTemperature, "SKIN_TEMPERATURE", null, start, end)
        assertEquals(inWindow, dates(points))
        assertEquals(33.5, points[0]["temperature"])
    }

    @Test
    fun withoutWindowEverySampleIsKept() {
        // getChanges and getDataByUUID convert whole records.
        val all = times.map { it.toEpochMilli() }
        assertEquals(all, dates(converter.convertRecord(heartRate, "HEART_RATE")))
        assertEquals(all, dates(converter.convertRecord(speed, "SPEED")))
        assertEquals(all, dates(converter.convertRecord(skinTemperature, "SKIN_TEMPERATURE")))
    }

    @Test
    fun eachBoundAppliesOnItsOwn() {
        assertEquals(3, converter.convertRecord(heartRate, "HEART_RATE", null, from = start).size)
        assertEquals(3, converter.convertRecord(heartRate, "HEART_RATE", null, to = end).size)
    }

    @Test
    fun otherRecordsIgnoreTheWindow() {
        // Health Connect matches interval records itself; they are not clipped.
        val steps = StepsRecord(start.minusSeconds(60), null, start.plusSeconds(60), null, 100, Metadata.manualEntry())
        val points = converter.convertRecord(steps, "STEPS", null, start, end)
        assertEquals(listOf(start.minusSeconds(60).toEpochMilli()), dates(points))
    }

    @Test
    fun sampleCountIsTakenBeforeTheWindow() {
        assertEquals(4, converter.sampleCount(heartRate))
        assertEquals(4, converter.sampleCount(speed))
        assertEquals(4, converter.sampleCount(skinTemperature))
        assertEquals(1, converter.sampleCount(StepsRecord(start, null, end, null, 100, Metadata.manualEntry())))
    }

    @Test
    fun seriesTypesAreTheRecordsWithSamples() {
        assertEquals(
            setOf(HeartRateRecord::class, SpeedRecord::class, SkinTemperatureRecord::class),
            HealthDataConverter.seriesTypes,
        )
    }
}
