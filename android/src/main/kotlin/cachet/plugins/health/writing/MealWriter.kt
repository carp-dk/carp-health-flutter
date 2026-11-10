package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.MealType
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.units.grams
import androidx.health.connect.client.units.kilocalories
import cachet.plugins.health.HealthConstants
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Writes a meal as a nutrition record, for writeMeal. Nutrients are in grams, energy in kcal. Replies
 * false if the meal does not end after it starts ([requireStartBeforeEnd]) or Health Connect rejects
 * it.
 */
internal class MealWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeMeal(call: MethodCall, result: Result) {
        val startTime = Instant.ofEpochMilli(call.argument<Long>("start_time")!!)
        val endTime = Instant.ofEpochMilli(call.argument<Long>("end_time")!!)
        val calories = call.argument<Double>("calories")
        val protein = call.argument<Double>("protein")
        val carbs = call.argument<Double>("carbs")
        val fat = call.argument<Double>("fat")
        val caffeine = call.argument<Double>("caffeine")
        val vitaminA = call.argument<Double>("vitamin_a")
        val b1Thiamine = call.argument<Double>("b1_thiamine")
        val b2Riboflavin = call.argument<Double>("b2_riboflavin")
        val b3Niacin = call.argument<Double>("b3_niacin")
        val b5PantothenicAcid = call.argument<Double>("b5_pantothenic_acid")
        val b6Pyridoxine = call.argument<Double>("b6_pyridoxine")
        val b7Biotin = call.argument<Double>("b7_biotin")
        val b9Folate = call.argument<Double>("b9_folate")
        val b12Cobalamin = call.argument<Double>("b12_cobalamin")
        val vitaminC = call.argument<Double>("vitamin_c")
        val vitaminD = call.argument<Double>("vitamin_d")
        val vitaminE = call.argument<Double>("vitamin_e")
        val vitaminK = call.argument<Double>("vitamin_k")
        val calcium = call.argument<Double>("calcium")
        val chloride = call.argument<Double>("chloride")
        val cholesterol = call.argument<Double>("cholesterol")
        val chromium = call.argument<Double>("chromium")
        val copper = call.argument<Double>("copper")
        val fatUnsaturated = call.argument<Double>("fat_unsaturated")
        val fatMonounsaturated = call.argument<Double>("fat_monounsaturated")
        val fatPolyunsaturated = call.argument<Double>("fat_polyunsaturated")
        val fatSaturated = call.argument<Double>("fat_saturated")
        val fatTransMonoenoic = call.argument<Double>("fat_trans_monoenoic")
        val fiber = call.argument<Double>("fiber")
        val iodine = call.argument<Double>("iodine")
        val iron = call.argument<Double>("iron")
        val magnesium = call.argument<Double>("magnesium")
        val manganese = call.argument<Double>("manganese")
        val molybdenum = call.argument<Double>("molybdenum")
        val phosphorus = call.argument<Double>("phosphorus")
        val potassium = call.argument<Double>("potassium")
        val selenium = call.argument<Double>("selenium")
        val sodium = call.argument<Double>("sodium")
        val sugar = call.argument<Double>("sugar")
        val zinc = call.argument<Double>("zinc")

        val name = call.argument<String>("name")
        val mealType = call.argument<String>("meal_type")!!
        val recordingMethod = call.argument<Int>("recordingMethod") ?: RECORDING_METHOD_MANUAL_ENTRY
        val metadata = call.recordMetadata(recordingMethod)

        scope.launch {
            try {
                requireStartBeforeEnd(startTime, endTime)
                // Built here: a value out of Health Connect's range fails the write, not the call.
                val record = NutritionRecord(
                    name = name,
                    metadata = metadata,
                    energy = calories?.kilocalories,
                    totalCarbohydrate = carbs?.grams,
                    protein = protein?.grams,
                    totalFat = fat?.grams,
                    caffeine = caffeine?.grams,
                    vitaminA = vitaminA?.grams,
                    thiamin = b1Thiamine?.grams,
                    riboflavin = b2Riboflavin?.grams,
                    niacin = b3Niacin?.grams,
                    pantothenicAcid = b5PantothenicAcid?.grams,
                    vitaminB6 = b6Pyridoxine?.grams,
                    biotin = b7Biotin?.grams,
                    folate = b9Folate?.grams,
                    vitaminB12 = b12Cobalamin?.grams,
                    vitaminC = vitaminC?.grams,
                    vitaminD = vitaminD?.grams,
                    vitaminE = vitaminE?.grams,
                    vitaminK = vitaminK?.grams,
                    calcium = calcium?.grams,
                    chloride = chloride?.grams,
                    cholesterol = cholesterol?.grams,
                    chromium = chromium?.grams,
                    copper = copper?.grams,
                    unsaturatedFat = fatUnsaturated?.grams,
                    monounsaturatedFat = fatMonounsaturated?.grams,
                    polyunsaturatedFat = fatPolyunsaturated?.grams,
                    saturatedFat = fatSaturated?.grams,
                    transFat = fatTransMonoenoic?.grams,
                    dietaryFiber = fiber?.grams,
                    iodine = iodine?.grams,
                    iron = iron?.grams,
                    magnesium = magnesium?.grams,
                    manganese = manganese?.grams,
                    molybdenum = molybdenum?.grams,
                    phosphorus = phosphorus?.grams,
                    potassium = potassium?.grams,
                    selenium = selenium?.grams,
                    sodium = sodium?.grams,
                    sugar = sugar?.grams,
                    zinc = zinc?.grams,
                    startTime = startTime,
                    startZoneOffset = null,
                    endTime = endTime,
                    endZoneOffset = null,
                    mealType = HealthConstants.mapMealTypeToType[mealType] ?: MealType.MEAL_TYPE_UNKNOWN
                )
                healthConnectClient.insertRecords(listOf(record))
                result.success(true)
                Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Meal was successfully added!")
            } catch (e: Exception) {
                logAddFailed("the meal", e)
                result.success(false)
            }
        }
    }
}
