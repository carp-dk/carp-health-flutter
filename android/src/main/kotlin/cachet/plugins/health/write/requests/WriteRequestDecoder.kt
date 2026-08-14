package cachet.plugins.health.write.requests

import cachet.plugins.health.channel.MethodCallArgs
import cachet.plugins.health.metadata.HealthMetadataFactory
import io.flutter.plugin.common.MethodCall

/**
 * Decodes Flutter method calls into typed Health Connect write requests.
 */
class WriteRequestDecoder {
    /** Generic scalar write request from Flutter arguments. */
    fun generic(call: MethodCall): GenericWriteRequest {
        val args = MethodCallArgs.from(call)
        return GenericWriteRequest(
            dataTypeKey = args.requiredString("dataTypeKey"),
            startTime = args.requiredLong("startTime"),
            endTime = args.requiredLong("endTime"),
            value = args.requiredDouble("value"),
            metadata = metadata(args),
        )
    }

    /** Activity intensity write request from Flutter arguments. */
    fun activityIntensity(call: MethodCall): ActivityIntensityWriteRequest {
        val args = MethodCallArgs.from(call)
        return ActivityIntensityWriteRequest(
            intensityType = args.requiredInt("intensityType"),
            startTime = args.requiredLong("startTime"),
            endTime = args.requiredLong("endTime"),
            metadata = metadata(args),
        )
    }

    /** Workout write request from Flutter arguments. */
    fun workout(call: MethodCall): WorkoutWriteRequest {
        val args = MethodCallArgs.from(call)
        return WorkoutWriteRequest(
            activityType = args.requiredString("activityType"),
            startTime = args.requiredLong("startTime"),
            endTime = args.requiredLong("endTime"),
            totalEnergyBurned = args.optionalInt("totalEnergyBurned"),
            totalDistance = args.optionalInt("totalDistance"),
            title = args.optionalString("title"),
            metadata = metadata(args),
        )
    }

    /** Blood pressure write request from Flutter arguments. */
    fun bloodPressure(call: MethodCall): BloodPressureWriteRequest {
        val args = MethodCallArgs.from(call)
        return BloodPressureWriteRequest(
            systolic = args.requiredDouble("systolic"),
            diastolic = args.requiredDouble("diastolic"),
            startTime = args.requiredLong("startTime"),
            metadata = metadata(args),
        )
    }

    /** Nutrition write request from Flutter arguments. */
    fun nutrition(call: MethodCall): NutritionWriteRequest {
        val args = MethodCallArgs.from(call)
        return NutritionWriteRequest(
            startTime = args.requiredLong("start_time"),
            endTime = args.requiredLong("end_time"),
            mealType = args.requiredString("meal_type"),
            name = args.optionalString("name"),
            nutrients = nutritionNutrients(args),
            metadata = metadata(args, defaultRecordingMethod = HealthMetadataFactory.RECORDING_METHOD_MANUAL),
        )
    }

    /** Speed write request from Flutter arguments. */
    fun speed(call: MethodCall): SpeedWriteRequest {
        val args = MethodCallArgs.from(call)
        val rawSamples = args.optionalList<Map<String, Any?>>("samples") ?: throw missing("samples")
        return SpeedWriteRequest(
            startTime = args.requiredLong("startTime"),
            endTime = args.requiredLong("endTime"),
            samples = rawSamples.map(::speedSample),
            metadata = metadata(args),
        )
    }

    /** Workout route insert request from Flutter arguments. */
    fun routeInsert(call: MethodCall): WorkoutRouteInsertRequest {
        val args = MethodCallArgs.from(call)
        val rawLocations = args.optionalList<Map<String, Any?>>("locations") ?: emptyList()
        return WorkoutRouteInsertRequest(
            builderId = args.requiredString("builderId"),
            locations = rawLocations.map(::routeLocation),
        )
    }

    /** Workout route finish request from Flutter arguments. */
    fun routeFinish(call: MethodCall): WorkoutRouteFinishRequest {
        val args = MethodCallArgs.from(call)
        return WorkoutRouteFinishRequest(
            builderId = args.requiredString("builderId"),
            workoutUUID = args.requiredString("workoutUUID"),
        )
    }

    /** Workout route discard request from Flutter arguments. */
    fun routeDiscard(call: MethodCall): WorkoutRouteDiscardRequest =
        WorkoutRouteDiscardRequest(MethodCallArgs.from(call).requiredString("builderId"))

    private fun metadata(
        args: MethodCallArgs,
        defaultRecordingMethod: Int = HealthMetadataFactory.RECORDING_METHOD_UNKNOWN,
    ) = MetadataRequest(
        recordingMethod = args.optionalInt("recordingMethod") ?: defaultRecordingMethod,
        clientRecordId = args.optionalString("clientRecordId"),
        clientRecordVersion = args.optionalLong("clientRecordVersion"),
        deviceType = args.optionalInt("deviceType"),
    )

    private fun nutritionNutrients(args: MethodCallArgs) = NutritionNutrients(
        calories = args.optionalDouble("calories"),
        protein = args.optionalDouble("protein"),
        carbs = args.optionalDouble("carbs"),
        fat = args.optionalDouble("fat"),
        caffeine = args.optionalDouble("caffeine"),
        vitaminA = args.optionalDouble("vitamin_a"),
        b1Thiamin = args.optionalDouble("b1_thiamin") ?: args.optionalDouble("b1_thiamine"),
        b2Riboflavin = args.optionalDouble("b2_riboflavin"),
        b3Niacin = args.optionalDouble("b3_niacin"),
        b5PantothenicAcid = args.optionalDouble("b5_pantothenic_acid"),
        b6Pyridoxine = args.optionalDouble("b6_pyridoxine"),
        b7Biotin = args.optionalDouble("b7_biotin"),
        b9Folate = args.optionalDouble("b9_folate"),
        b12Cobalamin = args.optionalDouble("b12_cobalamin"),
        vitaminC = args.optionalDouble("vitamin_c"),
        vitaminD = args.optionalDouble("vitamin_d"),
        vitaminE = args.optionalDouble("vitamin_e"),
        vitaminK = args.optionalDouble("vitamin_k"),
        calcium = args.optionalDouble("calcium"),
        chloride = args.optionalDouble("chloride"),
        cholesterol = args.optionalDouble("cholesterol"),
        chromium = args.optionalDouble("chromium"),
        copper = args.optionalDouble("copper"),
        fatUnsaturated = args.optionalDouble("fat_unsaturated"),
        fatMonounsaturated = args.optionalDouble("fat_monounsaturated"),
        fatPolyunsaturated = args.optionalDouble("fat_polyunsaturated"),
        fatSaturated = args.optionalDouble("fat_saturated"),
        fatTransMonoenoic = args.optionalDouble("fat_trans_monoenoic"),
        fiber = args.optionalDouble("fiber"),
        iodine = args.optionalDouble("iodine"),
        iron = args.optionalDouble("iron"),
        magnesium = args.optionalDouble("magnesium"),
        manganese = args.optionalDouble("manganese"),
        molybdenum = args.optionalDouble("molybdenum"),
        phosphorus = args.optionalDouble("phosphorus"),
        potassium = args.optionalDouble("potassium"),
        selenium = args.optionalDouble("selenium"),
        sodium = args.optionalDouble("sodium"),
        sugar = args.optionalDouble("sugar"),
        zinc = args.optionalDouble("zinc"),
    )

    private fun speedSample(raw: Map<String, Any?>) = SpeedSampleRequest(
        time = raw["time"].toLongOrNull() ?: throw missing("samples.time"),
        speed = raw["speed"].toDoubleOrNull() ?: throw missing("samples.speed"),
    )

    private fun routeLocation(raw: Map<String, Any?>) = WorkoutRouteLocationRequest(
        latitude = raw["latitude"].toDoubleOrNull() ?: throw missing("locations.latitude"),
        longitude = raw["longitude"].toDoubleOrNull() ?: throw missing("locations.longitude"),
        timestamp = raw["timestamp"].toLongOrNull() ?: throw missing("locations.timestamp"),
        altitude = raw["altitude"].toDoubleOrNull(),
        horizontalAccuracy = raw["horizontalAccuracy"].toDoubleOrNull(),
        verticalAccuracy = raw["verticalAccuracy"].toDoubleOrNull(),
    )

    private fun Any?.toLongOrNull(): Long? =
        when (this) {
            is Number -> toLong()
            is String -> toLongOrNull()
            else -> null
        }

    private fun Any?.toDoubleOrNull(): Double? =
        when (this) {
            is Number -> toDouble()
            is String -> toDoubleOrNull()
            else -> null
        }

    private fun missing(name: String) =
        IllegalArgumentException("Missing or invalid argument: $name")
}
