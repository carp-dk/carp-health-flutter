package cachet.plugins.health

import androidx.health.connect.client.records.NutritionRecord

private const val MEAL_UNKNOWN = "UNKNOWN"

/** The nutrients, name and meal type of [record], keyed as the Dart side reads them. */
internal fun nutritionFields(record: NutritionRecord): Map<String, Any?> = mapOf(
    "calories" to record.energy?.inKilocalories,
    "protein" to record.protein?.inGrams,
    "carbs" to record.totalCarbohydrate?.inGrams,
    "fat" to record.totalFat?.inGrams,
    "caffeine" to record.caffeine?.inGrams,
    "vitamin_a" to record.vitaminA?.inGrams,
    "b1_thiamine" to record.thiamin?.inGrams,
    "b2_riboflavin" to record.riboflavin?.inGrams,
    "b3_niacin" to record.niacin?.inGrams,
    "b5_pantothenic_acid" to record.pantothenicAcid?.inGrams,
    "b6_pyridoxine" to record.vitaminB6?.inGrams,
    "b7_biotin" to record.biotin?.inGrams,
    "b9_folate" to record.folate?.inGrams,
    "b12_cobalamin" to record.vitaminB12?.inGrams,
    "vitamin_c" to record.vitaminC?.inGrams,
    "vitamin_d" to record.vitaminD?.inGrams,
    "vitamin_e" to record.vitaminE?.inGrams,
    "vitamin_k" to record.vitaminK?.inGrams,
    "calcium" to record.calcium?.inGrams,
    "chloride" to record.chloride?.inGrams,
    "cholesterol" to record.cholesterol?.inGrams,
    "choline" to null, // Not supported by Health Connect
    "chromium" to record.chromium?.inGrams,
    "copper" to record.copper?.inGrams,
    "fat_unsaturated" to record.unsaturatedFat?.inGrams,
    "fat_monounsaturated" to record.monounsaturatedFat?.inGrams,
    "fat_polyunsaturated" to record.polyunsaturatedFat?.inGrams,
    "fat_saturated" to record.saturatedFat?.inGrams,
    "fat_trans_monoenoic" to record.transFat?.inGrams,
    "fiber" to record.dietaryFiber?.inGrams,
    "iodine" to record.iodine?.inGrams,
    "iron" to record.iron?.inGrams,
    "magnesium" to record.magnesium?.inGrams,
    "manganese" to record.manganese?.inGrams,
    "molybdenum" to record.molybdenum?.inGrams,
    "phosphorus" to record.phosphorus?.inGrams,
    "potassium" to record.potassium?.inGrams,
    "selenium" to record.selenium?.inGrams,
    "sodium" to record.sodium?.inGrams,
    "sugar" to record.sugar?.inGrams,
    "water" to null, // Not supported by Health Connect
    "zinc" to record.zinc?.inGrams,
    "name" to (record.name ?: ""),
    "meal_type" to (HealthConstants.mapTypeToMealType[record.mealType] ?: MEAL_UNKNOWN)
)
