package cachet.plugins.health

import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Pressure
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

class BloodPressureConverterTest {
    private val record = BloodPressureRecord(
        time = Instant.parse("2026-11-08T10:00:00Z"),
        zoneOffset = null,
        metadata = Metadata.manualEntry(),
        systolic = Pressure.millimetersOfMercury(120.0),
        diastolic = Pressure.millimetersOfMercury(80.0),
        bodyPosition = BloodPressureRecord.BODY_POSITION_SITTING_DOWN,
        measurementLocation = BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_UPPER_ARM,
    )

    @Test
    fun bothPressuresHaveTheBodyPositionAndMeasurementLocation() {
        for (type in listOf(HealthConstants.BLOOD_PRESSURE_SYSTOLIC, HealthConstants.BLOOD_PRESSURE_DIASTOLIC)) {
            val point = HealthDataConverter().convertRecord(record, type).single()

            assertEquals(BloodPressureRecord.BODY_POSITION_SITTING_DOWN, point["body_position"])
            assertEquals(BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_UPPER_ARM, point["measurement_location"])
        }
    }
}
