package cachet.plugins.health.write

import androidx.health.connect.client.records.MealType
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.units.Energy
import androidx.health.connect.client.units.Mass
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.requests.NutritionNutrients
import cachet.plugins.health.write.requests.NutritionWriteRequest
import io.flutter.plugin.common.MethodChannel.Result
import java.time.Instant

/**
 * Writes nutrition records to Health Connect.
 */
class NutritionWriter(
    private val executor: HealthConnectWriteExecutor,
    private val metadataFactory: HealthMetadataFactory,
) {
    /** Inserts a nutrition record. */
    fun write(request: NutritionWriteRequest, result: Result) {
        val metadata = metadataFactory.create(
            recordingMethod = request.metadata.recordingMethod,
            clientRecordId = request.metadata.clientRecordId,
            clientRecordVersion = request.metadata.clientRecordVersion,
            deviceType = request.metadata.deviceType,
        )
        val nutrients = request.nutrients
        val record = NutritionRecord(
            name = request.name,
            metadata = metadata,
            energy = nutrients.calories?.let(Energy::kilocalories),
            totalCarbohydrate = nutrients.carbs.grams(),
            protein = nutrients.protein.grams(),
            totalFat = nutrients.fat.grams(),
            caffeine = nutrients.caffeine.grams(),
            vitaminA = nutrients.vitaminA.grams(),
            thiamin = nutrients.b1Thiamin.grams(),
            riboflavin = nutrients.b2Riboflavin.grams(),
            niacin = nutrients.b3Niacin.grams(),
            pantothenicAcid = nutrients.b5PantothenicAcid.grams(),
            vitaminB6 = nutrients.b6Pyridoxine.grams(),
            biotin = nutrients.b7Biotin.grams(),
            folate = nutrients.b9Folate.grams(),
            vitaminB12 = nutrients.b12Cobalamin.grams(),
            vitaminC = nutrients.vitaminC.grams(),
            vitaminD = nutrients.vitaminD.grams(),
            vitaminE = nutrients.vitaminE.grams(),
            vitaminK = nutrients.vitaminK.grams(),
            calcium = nutrients.calcium.grams(),
            chloride = nutrients.chloride.grams(),
            cholesterol = nutrients.cholesterol.grams(),
            chromium = nutrients.chromium.grams(),
            copper = nutrients.copper.grams(),
            unsaturatedFat = nutrients.fatUnsaturated.grams(),
            monounsaturatedFat = nutrients.fatMonounsaturated.grams(),
            polyunsaturatedFat = nutrients.fatPolyunsaturated.grams(),
            saturatedFat = nutrients.fatSaturated.grams(),
            transFat = nutrients.fatTransMonoenoic.grams(),
            dietaryFiber = nutrients.fiber.grams(),
            iodine = nutrients.iodine.grams(),
            iron = nutrients.iron.grams(),
            magnesium = nutrients.magnesium.grams(),
            manganese = nutrients.manganese.grams(),
            molybdenum = nutrients.molybdenum.grams(),
            phosphorus = nutrients.phosphorus.grams(),
            potassium = nutrients.potassium.grams(),
            selenium = nutrients.selenium.grams(),
            sodium = nutrients.sodium.grams(),
            sugar = nutrients.sugar.grams(),
            zinc = nutrients.zinc.grams(),
            startTime = Instant.ofEpochMilli(request.startTime),
            startZoneOffset = null,
            endTime = Instant.ofEpochMilli(request.endTime),
            endZoneOffset = null,
            mealType = mealType(request.mealType),
        )
        executor.insert(
            records = listOf(record),
            result = result,
            failureCode = "WRITE_MEAL_ERROR",
            failureMessage = "[Health Connect] There was an error adding the meal",
        )
    }

    private fun mealType(type: String): Int =
        HealthConstants.mapMealTypeToType[type] ?: MealType.MEAL_TYPE_UNKNOWN

    private fun Double?.grams() = this?.let(Mass::grams)
}
