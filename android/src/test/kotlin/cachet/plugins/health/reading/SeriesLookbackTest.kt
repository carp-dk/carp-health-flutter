package cachet.plugins.health.reading

import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Velocity
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class SeriesLookbackTest {
    private val start = Instant.parse("2026-11-08T10:00:00Z")

    private fun heartRate(id: String, from: Instant, to: Instant) =
        HeartRateRecord(from, null, to, null, listOf(HeartRateRecord.Sample(from, 60)), Metadata.manualEntryWithId(id))

    @Test
    fun lookbackKeepsRecordsReachingIntoTheRangeInStartOrder() {
        // Newest first, as the lookback reads them.
        val onPage = heartRate("onPage", start.minusSeconds(100), start.plusSeconds(100))
        val reaching = heartRate("reaching", start.minusSeconds(300), start.plusSeconds(300))
        val endsAtStart = heartRate("endsAtStart", start.minusSeconds(600), start)
        val endsBefore = heartRate("endsBefore", start.minusSeconds(900), start.minusMillis(1))
        val older = heartRate("older", start.minusSeconds(3600), start.plusSeconds(60))

        val kept = SeriesLookback.keepLookbackRecords(
            listOf(onPage, reaching, endsAtStart, endsBefore, older),
            start,
            setOf("onPage"),
        )
        // A record that ends exactly at the start may hold a sample there, which the window before leaves out.
        assertEquals(listOf("older", "endsAtStart", "reaching"), kept.map { it.metadata.id })
    }

    @Test
    fun lookbackHandlesEverySeriesType() {
        val speed = SpeedRecord(
            start.minusSeconds(60), null, start.plusSeconds(60), null,
            listOf(SpeedRecord.Sample(start, Velocity.metersPerSecond(1.0))), Metadata.manualEntryWithId("speed"),
        )
        val skinTemperature = SkinTemperatureRecord(
            start.minusSeconds(120), null, start.plusSeconds(60), null, Metadata.manualEntryWithId("skin"),
            listOf(SkinTemperatureRecord.Delta(start, TemperatureDelta.celsius(0.1))), null,
            SkinTemperatureRecord.MEASUREMENT_LOCATION_FINGER,
        )
        val power = PowerRecord(
            start.minusSeconds(180), null, start.plusSeconds(60), null,
            listOf(PowerRecord.Sample(start, Power.watts(200.0))), Metadata.manualEntryWithId("power"),
        )
        val cadence = CyclingPedalingCadenceRecord(
            start.minusSeconds(240), null, start.plusSeconds(60), null,
            listOf(CyclingPedalingCadenceRecord.Sample(start, 85.0)), Metadata.manualEntryWithId("cadence"),
        )
        val kept = SeriesLookback.keepLookbackRecords(
            listOf<Record>(speed, skinTemperature, power, cadence),
            start,
            emptySet(),
        )
        assertEquals(listOf("cadence", "power", "skin", "speed"), kept.map { it.metadata.id })
    }
}
