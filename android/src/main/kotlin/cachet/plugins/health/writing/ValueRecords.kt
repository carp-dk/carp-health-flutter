package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.BodyWaterMassRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.LeanBodyMassRecord
import androidx.health.connect.client.records.MenstruationFlowRecord
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.BloodGlucose
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Percentage
import androidx.health.connect.client.units.Power
import androidx.health.connect.client.units.Temperature
import androidx.health.connect.client.units.TemperatureDelta
import androidx.health.connect.client.units.Velocity
import androidx.health.connect.client.units.Volume
import cachet.plugins.health.HealthConstants
import java.time.Instant

// The sleep stage data types and their Health Connect stage types: writeData writes one as a session
// with one stage of that type, writeSleepSession the stages of a session ([sleepSessionRecord]).
internal val sleepStageTypes = mapOf(
    HealthConstants.SLEEP_ASLEEP to SleepSessionRecord.STAGE_TYPE_SLEEPING,
    HealthConstants.SLEEP_LIGHT to SleepSessionRecord.STAGE_TYPE_LIGHT,
    HealthConstants.SLEEP_DEEP to SleepSessionRecord.STAGE_TYPE_DEEP,
    HealthConstants.SLEEP_REM to SleepSessionRecord.STAGE_TYPE_REM,
    HealthConstants.SLEEP_OUT_OF_BED to SleepSessionRecord.STAGE_TYPE_OUT_OF_BED,
    HealthConstants.SLEEP_AWAKE to SleepSessionRecord.STAGE_TYPE_AWAKE,
    HealthConstants.SLEEP_AWAKE_IN_BED to SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED,
    HealthConstants.SLEEP_UNKNOWN to SleepSessionRecord.STAGE_TYPE_UNKNOWN,
)

// The data types that have their own write method instead of writeData, and that method.
private val dedicatedWriteMethods = mapOf(
    HealthConstants.BLOOD_PRESSURE_SYSTOLIC to "writeBloodPressure",
    HealthConstants.BLOOD_PRESSURE_DIASTOLIC to "writeBloodPressure",
    HealthConstants.WORKOUT to "writeWorkoutData",
    HealthConstants.NUTRITION to "writeMeal",
    HealthConstants.ACTIVITY_INTENSITY to "writeActivityIntensity",
)

// The data types written as records that must end after they start ([requireStartBeforeEnd]). Heart
// rate and speed are series, which may end when they start.
private val typesWithDuration = setOf(
    HealthConstants.STEPS,
    HealthConstants.ACTIVE_ENERGY_BURNED,
    HealthConstants.TOTAL_CALORIES_BURNED,
    HealthConstants.DISTANCE_DELTA,
    HealthConstants.WATER,
    HealthConstants.FLIGHTS_CLIMBED,
    HealthConstants.SKIN_TEMPERATURE,
    HealthConstants.SLEEP_SESSION,
    HealthConstants.MINDFULNESS,
) + sleepStageTypes.keys

/**
 * Throws IllegalArgumentException unless [start] is before [end], for a record that must end after
 * it starts. connect-client checked this on every Android version until 1.2.0-alpha03; since then
 * Android 14+ leaves it to the platform, which stores records that end when they start, and such
 * records make whole reads fail in apps on older connect-client versions (#513). The writers check it
 * themselves, so such a write fails on every Android version, as before.
 */
internal fun requireStartBeforeEnd(start: Instant, end: Instant) {
    require(start.isBefore(end)) { "startTime must be before endTime." }
}

/** [requireStartBeforeEnd] for a value of [type] from [startTime] to [endTime] (epoch milliseconds). */
internal fun requireStartBeforeEnd(type: String, startTime: Long, endTime: Long) {
    if (type in typesWithDuration) requireStartBeforeEnd(Instant.ofEpochMilli(startTime), Instant.ofEpochMilli(endTime))
}

/**
 * The record of one [value] of the data type [type], or null (with an error in the log) for a type
 * that writeData does not write. Instantaneous types are recorded at [startTime] (epoch
 * milliseconds); series types hold one sample at [startTime]. Throws IllegalArgumentException for a
 * value Health Connect rejects while the record is built (on Android 14+ the platform checks it);
 * check the times with [requireStartBeforeEnd] first.
 */
internal fun valueRecord(type: String, startTime: Long, endTime: Long, value: Double, metadata: Metadata): Record? {
    val start = Instant.ofEpochMilli(startTime)
    val end = Instant.ofEpochMilli(endTime)
    return when (type) {
        HealthConstants.BODY_FAT_PERCENTAGE ->
            BodyFatRecord(time = start, zoneOffset = null, percentage = Percentage(value), metadata = metadata)
        HealthConstants.LEAN_BODY_MASS ->
            LeanBodyMassRecord(time = start, zoneOffset = null, mass = Mass.kilograms(value), metadata = metadata)
        HealthConstants.HEIGHT ->
            HeightRecord(time = start, zoneOffset = null, height = Length.meters(value), metadata = metadata)
        HealthConstants.WEIGHT ->
            WeightRecord(time = start, zoneOffset = null, weight = Mass.kilograms(value), metadata = metadata)
        HealthConstants.BODY_TEMPERATURE -> BodyTemperatureRecord(
            time = start, zoneOffset = null, temperature = Temperature.celsius(value), metadata = metadata,
        )
        HealthConstants.BODY_WATER_MASS ->
            BodyWaterMassRecord(time = start, zoneOffset = null, mass = Mass.kilograms(value), metadata = metadata)
        HealthConstants.BLOOD_OXYGEN ->
            OxygenSaturationRecord(time = start, zoneOffset = null, percentage = Percentage(value), metadata = metadata)
        HealthConstants.BLOOD_GLUCOSE -> BloodGlucoseRecord(
            time = start, zoneOffset = null, level = BloodGlucose.milligramsPerDeciliter(value), metadata = metadata,
        )
        HealthConstants.HEART_RATE_VARIABILITY_RMSSD -> HeartRateVariabilityRmssdRecord(
            time = start, zoneOffset = null, heartRateVariabilityMillis = value, metadata = metadata,
        )
        HealthConstants.RESTING_HEART_RATE -> RestingHeartRateRecord(
            time = start, zoneOffset = null, beatsPerMinute = value.toLong(), metadata = metadata,
        )
        HealthConstants.BASAL_ENERGY_BURNED -> BasalMetabolicRateRecord(
            time = start, zoneOffset = null, basalMetabolicRate = Power.kilocaloriesPerDay(value), metadata = metadata,
        )
        HealthConstants.RESPIRATORY_RATE ->
            RespiratoryRateRecord(time = start, zoneOffset = null, rate = value, metadata = metadata)
        HealthConstants.MENSTRUATION_FLOW ->
            MenstruationFlowRecord(time = start, zoneOffset = null, flow = value.toInt(), metadata = metadata)
        HealthConstants.STEPS -> StepsRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            count = value.toLong(), metadata = metadata,
        )
        HealthConstants.ACTIVE_ENERGY_BURNED -> ActiveCaloriesBurnedRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            energy = Energy.kilocalories(value), metadata = metadata,
        )
        HealthConstants.TOTAL_CALORIES_BURNED -> TotalCaloriesBurnedRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            energy = Energy.kilocalories(value), metadata = metadata,
        )
        HealthConstants.DISTANCE_DELTA -> DistanceRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            distance = Length.meters(value), metadata = metadata,
        )
        HealthConstants.WATER -> HydrationRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            volume = Volume.liters(value), metadata = metadata,
        )
        HealthConstants.FLIGHTS_CLIMBED -> FloorsClimbedRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            floors = value, metadata = metadata,
        )
        HealthConstants.HEART_RATE -> HeartRateRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            samples = listOf(HeartRateRecord.Sample(time = start, beatsPerMinute = value.toLong())),
            metadata = metadata,
        )
        HealthConstants.SPEED -> SpeedRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            samples = listOf(SpeedRecord.Sample(time = start, speed = Velocity.metersPerSecond(value))),
            metadata = metadata,
        )
        HealthConstants.SKIN_TEMPERATURE -> SkinTemperatureRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            baseline = Temperature.celsius(value),
            measurementLocation = SkinTemperatureRecord.MEASUREMENT_LOCATION_UNKNOWN,
            deltas = listOf(SkinTemperatureRecord.Delta(time = start, delta = TemperatureDelta.celsius(0.0))),
            metadata = metadata,
        )
        HealthConstants.SLEEP_SESSION -> SleepSessionRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            metadata = metadata,
        )
        in sleepStageTypes -> SleepSessionRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null,
            stages = listOf(SleepSessionRecord.Stage(start, end, sleepStageTypes.getValue(type))),
            metadata = metadata,
        )
        // A session is its time span, as HealthKit's mindful session, and writeData has no session type.
        HealthConstants.MINDFULNESS -> MindfulnessSessionRecord(
            startTime = start, startZoneOffset = null, endTime = end, endZoneOffset = null, metadata = metadata,
            mindfulnessSessionType = MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_UNKNOWN,
        )
        in dedicatedWriteMethods -> {
            Log.e("FLUTTER_HEALTH::ERROR", "You must use the [${dedicatedWriteMethods.getValue(type)}] API")
            null
        }
        else -> {
            Log.e(
                "FLUTTER_HEALTH::ERROR",
                "The type $type was not supported by the Health plugin or you must use another API"
            )
            null
        }
    }
}
