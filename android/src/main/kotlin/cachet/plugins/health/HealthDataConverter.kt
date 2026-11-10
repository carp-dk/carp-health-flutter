package cachet.plugins.health

import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.reflect.KClass
import androidx.health.connect.client.records.*
import androidx.health.connect.client.records.metadata.Metadata

/**
 * Converts Health Connect records to Flutter-compatible data structures.
 * Handles the transformation of strongly-typed Health Connect data into generic maps
 * that can be serialized and passed to the Flutter layer.
 */
class HealthDataConverter {
    
    /**
     * Converts a Health Connect record to a list of Flutter-compatible maps.
     * Handles various record types including instant records, interval records, and complex types.
     *
     * @param record The Health Connect record to convert
     * @param dataType The string identifier for the data type being converted
     * @param from If set, the samples of series records ([seriesTypes]) before this are dropped
     * @param to If set, series samples at or after this are dropped
     * @return List<Map<String, Any?>> List of converted records (some records may split into multiple entries)
     * @throws IllegalArgumentException If the record type is not supported
     */
    fun convertRecord(
        record: Any,
        dataType: String,
        dataUnit: String? = null,
        from: Instant? = null,
        to: Instant? = null,
    ): List<Map<String, Any?>> {
        val metadata = (record as Record).metadata
        
        return when (record) {
            // Single-value instant records
            is WeightRecord -> listOf(createInstantRecord(metadata, record.time, when (dataUnit) {
                                "POUND" -> record.weight.inPounds
                                else -> record.weight.inKilograms
                            }))
            is HeightRecord -> listOf(createInstantRecord(metadata, record.time, when (dataUnit) {
                                "CENTIMETER" -> (record.height.inMeters * 100)
                                "INCH" -> record.height.inInches
                                else -> record.height.inMeters
                            }))
            is BodyFatRecord -> listOf(createInstantRecord(metadata, record.time, record.percentage.value))
            is LeanBodyMassRecord -> listOf(createInstantRecord(metadata, record.time, record.mass.inKilograms))
            is HeartRateVariabilityRmssdRecord -> listOf(createInstantRecord(metadata, record.time, record.heartRateVariabilityMillis))
            is BodyTemperatureRecord -> listOf(createInstantRecord(metadata, record.time, when (dataUnit) {
                                "DEGREE_FAHRENHEIT" -> record.temperature.inFahrenheit
                                "KELVIN" -> record.temperature.inCelsius + 273.15
                                else -> record.temperature.inCelsius
                            }))
            is SkinTemperatureRecord -> {
                val baselineCelsius = record.baseline?.inCelsius
                val baselineValue = when (dataUnit) {
                    "DEGREE_FAHRENHEIT" -> baselineCelsius?.let { (it * 9.0 / 5.0) + 32.0 }
                    "KELVIN" -> baselineCelsius?.let { it + 273.15 }
                    else -> baselineCelsius
                }

                record.deltas.filter { inWindow(it.time, from, to) }.map { skinDelta ->
                    val deltaCelsius = skinDelta.delta.inCelsius
                    val deltaValue = when (dataUnit) {
                        "DEGREE_FAHRENHEIT" -> deltaCelsius * 9.0 / 5.0
                        "KELVIN" -> deltaCelsius
                        else -> deltaCelsius
                    }

                    createInstantRecord(metadata, skinDelta.time, deltaValue).toMutableMap().apply {
                        put("temperature_delta", deltaValue)
                        put("baseline", baselineValue)
                        put("measurement_location", record.measurementLocation)
                        if (baselineValue != null) {
                            put("temperature", baselineValue + deltaValue)
                        }
                    }
                }
            }
            is BodyWaterMassRecord -> listOf(createInstantRecord(metadata, record.time, record.mass.inKilograms))
            is OxygenSaturationRecord -> listOf(createInstantRecord(metadata, record.time, record.percentage.value))
            is BloodGlucoseRecord -> listOf(createInstantRecord(metadata, record.time, when (dataUnit) {
                                "MILLIMOLES_PER_LITER" -> record.level.inMillimolesPerLiter
                                else -> record.level.inMilligramsPerDeciliter
                            }))
            is BasalMetabolicRateRecord -> listOf(createInstantRecord(metadata, record.time, record.basalMetabolicRate.inKilocaloriesPerDay))
            is RestingHeartRateRecord -> listOf(createInstantRecord(metadata, record.time, record.beatsPerMinute))
            is RespiratoryRateRecord -> listOf(createInstantRecord(metadata, record.time, record.rate))
            is Vo2MaxRecord -> listOf(createInstantRecord(metadata, record.time, record.vo2MillilitersPerMinuteKilogram))

            // Interval records
            is StepsRecord -> listOf(createIntervalRecord(metadata, record.startTime, record.endTime, record.count))
            is ActiveCaloriesBurnedRecord -> listOf(createIntervalRecord(metadata, record.startTime, record.endTime, record.energy.inKilocalories))
            is DistanceRecord -> listOf(createIntervalRecord(metadata, record.startTime, record.endTime, record.distance.inMeters))
            is HydrationRecord -> listOf(createIntervalRecord(metadata, record.startTime, record.endTime, record.volume.inLiters))
            is TotalCaloriesBurnedRecord -> listOf(createIntervalRecord(metadata, record.startTime, record.endTime, record.energy.inKilocalories))
            is FloorsClimbedRecord -> listOf(createIntervalRecord(metadata, record.startTime, record.endTime, record.floors))
            is ActivityIntensityRecord -> listOf(
                createIntervalRecord(
                    metadata,
                    record.startTime,
                    record.endTime,
                    ChronoUnit.MINUTES.between(record.startTime, record.endTime)
                ).toMutableMap().apply {
                    put("activityIntensityType", record.activityIntensityType)
                }
            )
            
            // Special cases
            is BloodPressureRecord -> listOf(
                createInstantRecord(
                    metadata, 
                    record.time, 
                    if (dataType == BLOOD_PRESSURE_DIASTOLIC) 
                        record.diastolic.inMillimetersOfMercury 
                    else 
                        record.systolic.inMillimetersOfMercury
                )
            )
            
            is HeartRateRecord -> record.samples.filter { inWindow(it.time, from, to) }.map { sample ->
                createInstantRecord(metadata, sample.time, sample.beatsPerMinute)
            }

            is SpeedRecord -> record.samples.filter { inWindow(it.time, from, to) }.map { sample ->
                createInstantRecord(metadata, sample.time, sample.speed.inMetersPerSecond)
            }

            is PowerRecord -> record.samples.filter { inWindow(it.time, from, to) }.map { sample ->
                createInstantRecord(metadata, sample.time, sample.power.inWatts)
            }

            is CyclingPedalingCadenceRecord -> record.samples.filter { inWindow(it.time, from, to) }.map { sample ->
                createInstantRecord(metadata, sample.time, sample.revolutionsPerMinute)
            }
            
            is SleepSessionRecord -> listOf(
                createIntervalRecord(
                    metadata,
                    record.startTime,
                    record.endTime,
                    ChronoUnit.MINUTES.between(record.startTime, record.endTime)
                )
            )
            
            is MenstruationFlowRecord -> listOf(
                createInstantRecord(metadata, record.time, record.flow)
            )
            
            is NutritionRecord -> listOf(createNutritionRecord(record, metadata))
            
            else -> throw IllegalArgumentException("Health data type not supported")
        }
    }

    /**
     * Number of data points [record] expands to before window filtering: the sample count for
     * series records, otherwise 1. Used to size pages so a page stays within its point budget.
     */
    fun sampleCount(record: Record): Int = when (record) {
        is HeartRateRecord -> record.samples.size
        is SpeedRecord -> record.samples.size
        is PowerRecord -> record.samples.size
        is CyclingPedalingCadenceRecord -> record.samples.size
        is SkinTemperatureRecord -> record.deltas.size
        else -> 1
    }

    /** Health Connect matches interval records by start time; series samples need their own filter. */
    private fun inWindow(time: Instant, from: Instant?, to: Instant?): Boolean =
        (from == null || !time.isBefore(from)) && (to == null || time.isBefore(to))

    /**
     * Creates a standardized instant record map for point-in-time health measurements.
     * Used for data that represents a single moment measurement (weight, height, etc.).
     * 
     * @param metadata Record metadata containing source and recording information
     * @param time The timestamp when the measurement was taken
     * @param value The measured value
     * @return Map<String, Any?> Standardized instant record structure
     */
    private fun createInstantRecord(
        metadata: Metadata,
        time: Instant,
        value: Any
    ): Map<String, Any?> = createBaseRecord(metadata).apply {
        put("value", value)
        put("date_from", time.toEpochMilli())
        put("date_to", time.toEpochMilli())
    }

    /**
     * Creates a standardized interval record map for time-range health measurements.
     * Used for data that spans a time period (steps, distance, calories burned, etc.).
     * 
     * @param metadata Record metadata containing source and recording information
     * @param startTime Beginning of the measurement period
     * @param endTime End of the measurement period
     * @param value The measured value over the time period
     * @return Map<String, Any?> Standardized interval record structure
     */
    private fun createIntervalRecord(
        metadata: Metadata,
        startTime: Instant,
        endTime: Instant,
        value: Any
    ): Map<String, Any?> = createBaseRecord(metadata).apply {
        put("value", value)
        put("date_from", startTime.toEpochMilli())
        put("date_to", endTime.toEpochMilli())
    }

    /**
     * Creates the base record structure with common fields shared by all health records.
     * Includes metadata like UUID, source information, and recording method.
     * 
     * @param metadata Record metadata from Health Connect
     * @return MutableMap<String, Any?> Base record structure with common fields
     */
    private fun createBaseRecord(metadata: Metadata): MutableMap<String, Any?> = mutableMapOf(
        "uuid" to metadata.id,
        "source_id" to "",
        "source_name" to metadata.dataOrigin.packageName,
        "recording_method" to metadata.recordingMethod
    )

    /**
     * Creates a specialized nutrition record with comprehensive nutrient information.
     * Handles the complex nutrition data structure with multiple nutrient fields,
     * meal type classification, and optional food name.
     * 
     * @param record The NutritionRecord from Health Connect
     * @param metadata Record metadata
     * @return Map<String, Any?> Comprehensive nutrition record with all nutrient fields
     */
    private fun createNutritionRecord(
        record: NutritionRecord,
        metadata: Metadata
    ): Map<String, Any?> = createIntervalRecord(
        metadata,
        record.startTime,
        record.endTime,
        0 // Placeholder value since nutrition doesn't have a single value
    ).toMutableMap().apply {
        remove("value") // Remove the placeholder
        
        // Add all nutrition-specific fields
        putAll(nutritionFields(record))
    }

    /**
     * Converts a sleep stage to a Flutter-compatible map structure.
     * Transforms individual sleep stage data including duration and stage type
     * into a standardized format for Flutter consumption.
     * 
     * @param stage The sleep stage record from Health Connect
     * @param dataType The specific sleep data type being requested
     * @param metadata Parent sleep session metadata
     * @return List<Map<String, Any>> Sleep stage data in Flutter format
     */
    fun convertRecordStage(
        stage: SleepSessionRecord.Stage,
        dataType: String,
        metadata: Metadata
    ): List<Map<String, Any>> {
        return listOf(
            mapOf(
                "uuid" to metadata.id,
                "stage" to stage.stage,
                "value" to ChronoUnit.MINUTES.between(stage.startTime, stage.endTime),
                "date_from" to stage.startTime.toEpochMilli(),
                "date_to" to stage.endTime.toEpochMilli(),
                "source_id" to "",
                "source_name" to metadata.dataOrigin.packageName,
            )
        )
    }

    companion object {
        private const val BLOOD_PRESSURE_DIASTOLIC = "BLOOD_PRESSURE_DIASTOLIC"

        /** Record types that hold a series of timestamped samples, each converted to a data point. */
        val seriesTypes: Set<KClass<out Record>> = setOf(
            HeartRateRecord::class,
            SpeedRecord::class,
            PowerRecord::class,
            CyclingPedalingCadenceRecord::class,
            SkinTemperatureRecord::class,
        )
    }
}
