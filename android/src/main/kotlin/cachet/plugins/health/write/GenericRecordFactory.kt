package cachet.plugins.health.write

import androidx.health.connect.client.records.*
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.*
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.write.requests.GenericWriteRequest
import java.time.Instant

/**
 * Builds Health Connect records from generic Flutter write requests.
 */
class GenericRecordFactory {
    /** Health Connect record represented by a generic Flutter write request. */
    fun create(request: GenericWriteRequest, metadata: Metadata): Record? =
        when (request.dataTypeKey) {
            HealthConstants.BODY_FAT_PERCENTAGE -> BodyFatRecord(
                time = request.startInstant,
                percentage = Percentage(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.LEAN_BODY_MASS -> LeanBodyMassRecord(
                time = request.startInstant,
                mass = Mass.kilograms(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.HEIGHT -> HeightRecord(
                time = request.startInstant,
                height = Length.meters(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.WEIGHT -> WeightRecord(
                time = request.startInstant,
                weight = Mass.kilograms(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.STEPS -> StepsRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                count = request.value.toLong(),
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.ACTIVE_ENERGY_BURNED -> ActiveCaloriesBurnedRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                energy = Energy.kilocalories(request.value),
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.HEART_RATE -> HeartRateRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                samples = listOf(
                    HeartRateRecord.Sample(
                        time = request.startInstant,
                        beatsPerMinute = request.value.toLong(),
                    )
                ),
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.BODY_TEMPERATURE -> BodyTemperatureRecord(
                time = request.startInstant,
                temperature = Temperature.celsius(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.SKIN_TEMPERATURE -> SkinTemperatureRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                startZoneOffset = null,
                endZoneOffset = null,
                baseline = Temperature.celsius(request.value),
                measurementLocation = SkinTemperatureRecord.MEASUREMENT_LOCATION_UNKNOWN,
                deltas = listOf(
                    SkinTemperatureRecord.Delta(
                        time = request.startInstant,
                        delta = TemperatureDelta.celsius(0.0),
                    )
                ),
                metadata = metadata,
            )
            HealthConstants.BODY_WATER_MASS -> BodyWaterMassRecord(
                time = request.startInstant,
                mass = Mass.kilograms(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.BLOOD_OXYGEN -> OxygenSaturationRecord(
                time = request.startInstant,
                percentage = Percentage(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.BLOOD_GLUCOSE -> BloodGlucoseRecord(
                time = request.startInstant,
                level = BloodGlucose.milligramsPerDeciliter(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.HEART_RATE_VARIABILITY_RMSSD -> HeartRateVariabilityRmssdRecord(
                time = request.startInstant,
                heartRateVariabilityMillis = request.value,
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.DISTANCE_DELTA -> DistanceRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                distance = Length.meters(request.value),
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.WATER -> HydrationRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                volume = Volume.liters(request.value),
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            else -> createAdditionalRecord(request, metadata)
        }

    private fun createAdditionalRecord(request: GenericWriteRequest, metadata: Metadata): Record? =
        when (request.dataTypeKey) {
            HealthConstants.SLEEP_ASLEEP ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_SLEEPING, metadata)
            HealthConstants.SLEEP_LIGHT ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_LIGHT, metadata)
            HealthConstants.SLEEP_DEEP ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_DEEP, metadata)
            HealthConstants.SLEEP_REM ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_REM, metadata)
            HealthConstants.SLEEP_OUT_OF_BED ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_OUT_OF_BED, metadata)
            HealthConstants.SLEEP_AWAKE ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_AWAKE, metadata)
            HealthConstants.SLEEP_AWAKE_IN_BED ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED, metadata)
            HealthConstants.SLEEP_UNKNOWN ->
                createSleepRecord(request, SleepSessionRecord.STAGE_TYPE_UNKNOWN, metadata)
            HealthConstants.SLEEP_SESSION -> SleepSessionRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.RESTING_HEART_RATE -> RestingHeartRateRecord(
                time = request.startInstant,
                beatsPerMinute = request.value.toLong(),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.BASAL_ENERGY_BURNED -> BasalMetabolicRateRecord(
                time = request.startInstant,
                basalMetabolicRate = Power.kilocaloriesPerDay(request.value),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.FLIGHTS_CLIMBED -> FloorsClimbedRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                floors = request.value,
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.RESPIRATORY_RATE -> RespiratoryRateRecord(
                time = request.startInstant,
                rate = request.value,
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.TOTAL_CALORIES_BURNED -> TotalCaloriesBurnedRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                energy = Energy.kilocalories(request.value),
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.MENSTRUATION_FLOW -> MenstruationFlowRecord(
                time = request.startInstant,
                flow = request.value.toInt(),
                zoneOffset = null,
                metadata = metadata,
            )
            HealthConstants.SPEED -> SpeedRecord(
                startTime = request.startInstant,
                endTime = request.endInstant,
                samples = listOf(
                    SpeedRecord.Sample(
                        time = request.startInstant,
                        speed = Velocity.metersPerSecond(request.value),
                    )
                ),
                startZoneOffset = null,
                endZoneOffset = null,
                metadata = metadata,
            )
            else -> null
        }

    private fun createSleepRecord(
        request: GenericWriteRequest,
        stageType: Int,
        metadata: Metadata,
    ) = SleepSessionRecord(
        startTime = request.startInstant,
        endTime = request.endInstant,
        startZoneOffset = null,
        endZoneOffset = null,
        stages = listOf(SleepSessionRecord.Stage(request.startInstant, request.endInstant, stageType)),
        metadata = metadata,
    )

    private val GenericWriteRequest.startInstant: Instant
        get() = Instant.ofEpochMilli(startTime)

    private val GenericWriteRequest.endInstant: Instant
        get() = Instant.ofEpochMilli(endTime)
}
