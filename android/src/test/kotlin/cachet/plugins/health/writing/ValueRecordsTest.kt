package cachet.plugins.health.writing

import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import cachet.plugins.health.HealthConstants
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class ValueRecordsTest {
    private val start = 1_700_000_000_000L
    private val end = start + 600_000
    private val metadata = Metadata.manualEntry()

    // Written with writeBloodPressure, writeWorkoutData, writeMeal and writeActivityIntensity.
    private val ownWriteMethod = setOf(
        HealthConstants.BLOOD_PRESSURE_SYSTOLIC,
        HealthConstants.BLOOD_PRESSURE_DIASTOLIC,
        HealthConstants.WORKOUT,
        HealthConstants.NUTRITION,
        HealthConstants.ACTIVITY_INTENSITY,
    )

    // Read only: the plugin reads these from Health Connect but does not write them.
    private val readOnly = setOf(HealthConstants.POWER, HealthConstants.CYCLING_CADENCE)

    @Test
    fun everyOtherTypeIsWrittenAsTheRecordItIsReadFrom() {
        for ((type, recordClass) in HealthConstants.mapToType) {
            // An aggregate only, read from step records.
            if (type in ownWriteMethod || type in readOnly || type == HealthConstants.AGGREGATE_STEP_COUNT) continue
            assertEquals(type, recordClass, valueRecord(type, start, end, 1.0, metadata)?.let { it::class })
        }
    }

    @Test
    fun typesWithTheirOwnWriteMethodAreNotWritten() {
        for (type in ownWriteMethod + listOf(HealthConstants.SLEEP_IN_BED, "AUDIOGRAM")) {
            assertNull(type, valueRecord(type, start, end, 1.0, metadata))
        }
    }

    @Test
    fun readOnlyTypesAreNotWritten() {
        for (type in readOnly) {
            assertNull(type, valueRecord(type, start, end, 1.0, metadata))
        }
    }

    @Test
    fun valuesAreInTheDefaultUnitOfTheirType() {
        val weight = valueRecord(HealthConstants.WEIGHT, start, end, 72.5, metadata) as WeightRecord
        assertEquals(72.5, weight.weight.inKilograms, 1e-9)
        val water = valueRecord(HealthConstants.WATER, start, end, 1.5, metadata) as HydrationRecord
        assertEquals(1.5, water.volume.inLiters, 1e-9)
        val basal = valueRecord(HealthConstants.BASAL_ENERGY_BURNED, start, end, 1800.0, metadata) as BasalMetabolicRateRecord
        assertEquals(1800.0, basal.basalMetabolicRate.inKilocaloriesPerDay, 1e-9)
        // Series hold one sample at the start.
        val heartRate = valueRecord(HealthConstants.HEART_RATE, start, end, 72.0, metadata) as HeartRateRecord
        assertEquals(listOf(HeartRateRecord.Sample(Instant.ofEpochMilli(start), 72)), heartRate.samples)
    }

    @Test
    fun sleepStagesAreReadBackAsTheTypeTheyWereWrittenAs() {
        for (type in HealthConstants.mapSleepStageToType.values) {
            val session = valueRecord(type, start, end, 0.0, metadata) as SleepSessionRecord
            val stage = session.stages.single()
            assertEquals(type, HealthConstants.mapSleepStageToType[stage.stage])
            assertEquals(Instant.ofEpochMilli(start) to Instant.ofEpochMilli(end), stage.startTime to stage.endTime)
        }
        val session = valueRecord(HealthConstants.SLEEP_SESSION, start, end, 0.0, metadata) as SleepSessionRecord
        assertEquals(emptyList<SleepSessionRecord.Stage>(), session.stages)
    }

    @Test
    fun aRecordWithADurationMustEndAfterItStarts() {
        val time = Instant.ofEpochMilli(start)
        requireStartBeforeEnd(time, time.plusMillis(1))
        for (endTime in listOf(time, time.minusMillis(1))) {
            val error = assertThrows(IllegalArgumentException::class.java) { requireStartBeforeEnd(time, endTime) }
            assertEquals("startTime must be before endTime.", error.message)
        }
    }

    @Test
    fun valuesMustEndAfterTheyStartForTheTypesConnectClientRequiredItFor() {
        // connect-client checks this itself before Android 14, as in these tests, and before 1.2.0-alpha03
        // it did on every version. The plugin's own check keeps that rule on Android 14+.
        for (type in HealthConstants.mapToType.keys) {
            val required = runCatching { valueRecord(type, start, start, 1.0, metadata) }.exceptionOrNull()
            val checked = runCatching { requireStartBeforeEnd(type, start, start) }.exceptionOrNull()
            assertEquals(type, required?.message, checked?.message)
            requireStartBeforeEnd(type, start, end)
        }
    }
}
