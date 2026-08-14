package cachet.plugins.health.write.requests

/**
 * Metadata fields shared by Health Connect write requests.
 *
 * @property recordingMethod Health Connect recording method value.
 * @property clientRecordId Optional client-provided record ID.
 * @property clientRecordVersion Optional client-provided record version.
 * @property deviceType Optional Health Connect device type.
 */
data class MetadataRequest(
    val recordingMethod: Int,
    val clientRecordId: String?,
    val clientRecordVersion: Long?,
    val deviceType: Int?,
)

/**
 * Generic scalar health data write request.
 *
 * @property dataTypeKey Flutter health data type key.
 * @property startTime Start timestamp in epoch milliseconds.
 * @property endTime End timestamp in epoch milliseconds.
 * @property value Scalar health value.
 * @property metadata Metadata applied to the created Health Connect record.
 */
data class GenericWriteRequest(
    val dataTypeKey: String,
    val startTime: Long,
    val endTime: Long,
    val value: Double,
    val metadata: MetadataRequest,
)

/**
 * Activity intensity write request.
 *
 * @property intensityType Health Connect activity intensity type.
 * @property startTime Start timestamp in epoch milliseconds.
 * @property endTime End timestamp in epoch milliseconds.
 * @property metadata Metadata applied to the created Health Connect record.
 */
data class ActivityIntensityWriteRequest(
    val intensityType: Int,
    val startTime: Long,
    val endTime: Long,
    val metadata: MetadataRequest,
)

/**
 * Workout session write request.
 *
 * @property activityType Flutter workout activity type key.
 * @property startTime Workout start timestamp in epoch milliseconds.
 * @property endTime Workout end timestamp in epoch milliseconds.
 * @property totalEnergyBurned Optional energy burned in kilocalories.
 * @property totalDistance Optional distance in meters.
 * @property title Optional workout title.
 * @property metadata Metadata applied to the created Health Connect records.
 */
data class WorkoutWriteRequest(
    val activityType: String,
    val startTime: Long,
    val endTime: Long,
    val totalEnergyBurned: Int?,
    val totalDistance: Int?,
    val title: String?,
    val metadata: MetadataRequest,
)

/**
 * Blood pressure write request.
 *
 * @property systolic Systolic pressure in millimeters of mercury.
 * @property diastolic Diastolic pressure in millimeters of mercury.
 * @property startTime Measurement timestamp in epoch milliseconds.
 * @property metadata Metadata applied to the created Health Connect record.
 */
data class BloodPressureWriteRequest(
    val systolic: Double,
    val diastolic: Double,
    val startTime: Long,
    val metadata: MetadataRequest,
)

/**
 * Nutrition write request.
 *
 * @property startTime Meal start timestamp in epoch milliseconds.
 * @property endTime Meal end timestamp in epoch milliseconds.
 * @property mealType Flutter meal type key.
 * @property name Optional food or meal name.
 * @property nutrients Optional nutrient quantities.
 * @property metadata Metadata applied to the created Health Connect record.
 */
data class NutritionWriteRequest(
    val startTime: Long,
    val endTime: Long,
    val mealType: String,
    val name: String?,
    val nutrients: NutritionNutrients,
    val metadata: MetadataRequest,
)

/**
 * Optional nutrient quantities supplied with a nutrition write request.
 *
 * @property calories Energy in kilocalories.
 * @property protein Protein in grams.
 * @property carbs Total carbohydrates in grams.
 * @property fat Total fat in grams.
 * @property caffeine Caffeine in grams.
 * @property vitaminA Vitamin A in grams.
 * @property b1Thiamin Thiamin in grams.
 * @property b2Riboflavin Riboflavin in grams.
 * @property b3Niacin Niacin in grams.
 * @property b5PantothenicAcid Pantothenic acid in grams.
 * @property b6Pyridoxine Vitamin B6 in grams.
 * @property b7Biotin Biotin in grams.
 * @property b9Folate Folate in grams.
 * @property b12Cobalamin Vitamin B12 in grams.
 * @property vitaminC Vitamin C in grams.
 * @property vitaminD Vitamin D in grams.
 * @property vitaminE Vitamin E in grams.
 * @property vitaminK Vitamin K in grams.
 * @property calcium Calcium in grams.
 * @property chloride Chloride in grams.
 * @property cholesterol Cholesterol in grams.
 * @property chromium Chromium in grams.
 * @property copper Copper in grams.
 * @property fatUnsaturated Unsaturated fat in grams.
 * @property fatMonounsaturated Monounsaturated fat in grams.
 * @property fatPolyunsaturated Polyunsaturated fat in grams.
 * @property fatSaturated Saturated fat in grams.
 * @property fatTransMonoenoic Trans fat in grams.
 * @property fiber Dietary fiber in grams.
 * @property iodine Iodine in grams.
 * @property iron Iron in grams.
 * @property magnesium Magnesium in grams.
 * @property manganese Manganese in grams.
 * @property molybdenum Molybdenum in grams.
 * @property phosphorus Phosphorus in grams.
 * @property potassium Potassium in grams.
 * @property selenium Selenium in grams.
 * @property sodium Sodium in grams.
 * @property sugar Sugar in grams.
 * @property zinc Zinc in grams.
 */
data class NutritionNutrients(
    val calories: Double?,
    val protein: Double?,
    val carbs: Double?,
    val fat: Double?,
    val caffeine: Double?,
    val vitaminA: Double?,
    val b1Thiamin: Double?,
    val b2Riboflavin: Double?,
    val b3Niacin: Double?,
    val b5PantothenicAcid: Double?,
    val b6Pyridoxine: Double?,
    val b7Biotin: Double?,
    val b9Folate: Double?,
    val b12Cobalamin: Double?,
    val vitaminC: Double?,
    val vitaminD: Double?,
    val vitaminE: Double?,
    val vitaminK: Double?,
    val calcium: Double?,
    val chloride: Double?,
    val cholesterol: Double?,
    val chromium: Double?,
    val copper: Double?,
    val fatUnsaturated: Double?,
    val fatMonounsaturated: Double?,
    val fatPolyunsaturated: Double?,
    val fatSaturated: Double?,
    val fatTransMonoenoic: Double?,
    val fiber: Double?,
    val iodine: Double?,
    val iron: Double?,
    val magnesium: Double?,
    val manganese: Double?,
    val molybdenum: Double?,
    val phosphorus: Double?,
    val potassium: Double?,
    val selenium: Double?,
    val sodium: Double?,
    val sugar: Double?,
    val zinc: Double?,
)

/**
 * Speed sample write request.
 *
 * @property time Sample timestamp in epoch milliseconds.
 * @property speed Speed in meters per second.
 */
data class SpeedSampleRequest(val time: Long, val speed: Double)

/**
 * Speed series write request.
 *
 * @property startTime Series start timestamp in epoch milliseconds.
 * @property endTime Series end timestamp in epoch milliseconds.
 * @property samples Speed samples in the series.
 * @property metadata Metadata applied to the created Health Connect record.
 */
data class SpeedWriteRequest(
    val startTime: Long,
    val endTime: Long,
    val samples: List<SpeedSampleRequest>,
    val metadata: MetadataRequest,
)

/**
 * Workout route location write request.
 *
 * @property latitude Latitude in degrees.
 * @property longitude Longitude in degrees.
 * @property timestamp Location timestamp in epoch milliseconds.
 * @property altitude Optional altitude in meters.
 * @property horizontalAccuracy Optional horizontal accuracy in meters.
 * @property verticalAccuracy Optional vertical accuracy in meters.
 */
data class WorkoutRouteLocationRequest(
    val latitude: Double,
    val longitude: Double,
    val timestamp: Long,
    val altitude: Double?,
    val horizontalAccuracy: Double?,
    val verticalAccuracy: Double?,
)

/**
 * Workout route insertion request for a pending route builder.
 *
 * @property builderId Pending route builder ID.
 * @property locations Route locations to append.
 */
data class WorkoutRouteInsertRequest(
    val builderId: String,
    val locations: List<WorkoutRouteLocationRequest>,
)

/**
 * Workout route finish request for an existing workout UUID.
 *
 * @property builderId Pending route builder ID.
 * @property workoutUUID Health Connect workout UUID to update.
 */
data class WorkoutRouteFinishRequest(
    val builderId: String,
    val workoutUUID: String,
)

/**
 * Workout route discard request.
 *
 * @property builderId Pending route builder ID.
 */
data class WorkoutRouteDiscardRequest(val builderId: String)
