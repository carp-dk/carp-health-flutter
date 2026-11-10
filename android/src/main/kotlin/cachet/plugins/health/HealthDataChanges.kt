package cachet.plugins.health

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.DeletionChange
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ChangesTokenRequest
import androidx.health.connect.client.response.ChangesResponse
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlin.reflect.KClass

/**
 * Handles Health Connect change token workflows (token creation + change polling).
 * Converts change records into Flutter-friendly maps for consumption on the Dart side.
 */
class HealthDataChanges(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val context: Context,
    private val dataConverter: HealthDataConverter
) {
    /**
     * Creates a changes token for the requested record types.
     *
     * @param call Method call containing 'types' (list of dataTypeKey strings)
     * @param result Flutter result callback returning a token string
     */
    fun getChangesToken(call: MethodCall, result: Result) {
        val args = call.arguments as? HashMap<*, *>
        val types = (args?.get("types") as? ArrayList<*>)?.filterIsInstance<String>() ?: emptyList()

        if (types.isEmpty()) {
            result.success(null)
            return
        }

        val recordTypes = mutableSetOf<KClass<out Record>>()
        for (type in types) {
            if (type == HealthConstants.WORKOUT_ROUTE) {
                // Workout routes are embedded in ExerciseSessionRecord.
                recordTypes.add(ExerciseSessionRecord::class)
                continue
            }
            val classType = HealthConstants.mapToType[type]
            if (classType == null) {
                Log.w("FLUTTER_HEALTH::ERROR", "Datatype $type not found in HC")
                result.success(null)
                return
            }
            recordTypes.add(classType)
        }

        scope.launch(Dispatchers.Default) {
            try {
                val token = healthConnectClient.getChangesToken(
                    ChangesTokenRequest(recordTypes = recordTypes)
                )
                result.success(token)
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getChangesToken")
            }
        }
    }

    /**
     * Fetches the next page of changes for a previously created token.
     *
     * A page of more than 100,000 data points (e.g. thousands of changed heart rate series) is read
     * again from the same token with at most half as many changes ([ChangesPageSizer]) until it fits.
     * A page that cannot get small enough (a single change over the limit, or Health Connect does not
     * return fewer changes), that does not fit in memory (OutOfMemoryError) or that Health Connect
     * cannot return ("Too many records in the cursor") is reported as DATA_TOO_LARGE; the Dart side
     * then reports the token as expired.
     *
     * @param call Method call containing 'changesToken' and optional 'includeSelf'
     * @param result Flutter result callback returning changes payload
     */
    fun getChanges(call: MethodCall, result: Result) {
        // Off the main thread: a page of changes can expand to tens of thousands of data points.
        scope.launch(Dispatchers.Default) {
            try {
                val changesToken = call.optionalString("changesToken")
                val includeSelf = call.argument<Boolean>("includeSelf") ?: false

                if (changesToken.isNullOrEmpty()) {
                    result.success(null)
                    return@launch
                }

                // In its own call, so nothing of a page that did not fit is held while reporting.
                replyChanges(changesToken, includeSelf, result)
            } catch (e: Throwable) {
                HealthErrors.report(result, e, "getChanges")
            }
        }
    }

    /** Reads the page of changes after [changesToken], converts it and replies. */
    private suspend fun replyChanges(changesToken: String, includeSelf: Boolean, result: Result) {
        var response = healthConnectClient.getChanges(changesToken)
        // Health Connect returns a page of changed records whatever their size, and one heart rate record
        // can hold thousands of samples. Converting and sending millions of points at once would run out
        // of memory, so such a page is read again with fewer changes. A page that stays too large is
        // reported; the Dart side reports this as an expired token, so the app reads the range again.
        var points = pointCount(response, includeSelf)
        while (points > MAX_CHANGE_POINTS) {
            val changeCount = response.changes.size
            val pageSize = ChangesPageSizer.smallerPageSize(changeCount, points) ?: break
            Log.i("FLUTTER_HEALTH", "Reading $pageSize changes again: $changeCount held $points data points")
            response = healthConnectClient.getChanges(changesToken, pageSize)
            points = pointCount(response, includeSelf)
            // The page size is only a hint (an older Health Connect may ignore it): stop when the page
            // did not get smaller.
            if (response.changes.size >= changeCount) break
        }
        if (points > MAX_CHANGE_POINTS) {
            result.error(
                HealthErrors.DATA_TOO_LARGE,
                "The page of changes holds $points data points, more than $MAX_CHANGE_POINTS",
                null,
            )
            return
        }
        val changes = mutableListOf<Map<String, Any?>>()

        for (change in response.changes) {
            when (change) {
                is UpsertionChange -> {
                    val record = change.record
                    val originPackage = record.metadata.dataOrigin.packageName
                    if (!includeSelf && originPackage == context.packageName) {
                        continue
                    }

                    if (record is ExerciseSessionRecord) {
                        changes.add(
                            mapOf(
                                "type" to "upsert",
                                "dataTypeKey" to HealthConstants.WORKOUT,
                                "dataPoint" to convertWorkoutRecord(record)
                            )
                        )
                        continue
                    }

                    for (dataType in dataTypesForRecord(record)) {
                        val dataPoints = dataConverter.convertRecord(record, dataType)
                        for (dataPoint in dataPoints) {
                            changes.add(
                                mapOf(
                                    "type" to "upsert",
                                    "dataTypeKey" to dataType,
                                    "dataPoint" to dataPoint
                                )
                            )
                        }
                    }
                }
                is DeletionChange -> {
                    changes.add(
                        mapOf(
                            "type" to "delete",
                            "recordId" to change.recordId
                        )
                    )
                }
            }
        }

        val payload = mapOf(
            "changes" to changes,
            "nextChangesToken" to response.nextChangesToken,
            "hasMore" to response.hasMore,
            "changesTokenExpired" to response.changesTokenExpired,
        )
        result.success(payload)
    }

    /** The data points the changes in [response] convert to; this app's records count only with [includeSelf]. */
    private fun pointCount(response: ChangesResponse, includeSelf: Boolean): Long =
        response.changes.sumOf { change ->
            val record = (change as? UpsertionChange)?.record
            if (record == null || (!includeSelf && record.metadata.dataOrigin.packageName == context.packageName)) 0L
            else dataConverter.sampleCount(record).toLong() * maxOf(1, dataTypesForRecord(record).size)
        }

    private fun dataTypesForRecord(record: Record): List<String> = when (record) {
        is WeightRecord -> listOf(HealthConstants.WEIGHT)
        is HeightRecord -> listOf(HealthConstants.HEIGHT)
        is BodyFatRecord -> listOf(HealthConstants.BODY_FAT_PERCENTAGE)
        is LeanBodyMassRecord -> listOf(HealthConstants.LEAN_BODY_MASS)
        is StepsRecord -> listOf(HealthConstants.STEPS)
        is ActiveCaloriesBurnedRecord -> listOf(HealthConstants.ACTIVE_ENERGY_BURNED)
        is HeartRateRecord -> listOf(HealthConstants.HEART_RATE)
        is BodyTemperatureRecord -> listOf(HealthConstants.BODY_TEMPERATURE)
        is SkinTemperatureRecord -> listOf(HealthConstants.SKIN_TEMPERATURE)
        is BodyWaterMassRecord -> listOf(HealthConstants.BODY_WATER_MASS)
        is BloodPressureRecord ->
            listOf(
                HealthConstants.BLOOD_PRESSURE_SYSTOLIC,
                HealthConstants.BLOOD_PRESSURE_DIASTOLIC
            )
        is OxygenSaturationRecord -> listOf(HealthConstants.BLOOD_OXYGEN)
        is BloodGlucoseRecord -> listOf(HealthConstants.BLOOD_GLUCOSE)
        is HeartRateVariabilityRmssdRecord -> listOf(HealthConstants.HEART_RATE_VARIABILITY_RMSSD)
        is DistanceRecord -> listOf(HealthConstants.DISTANCE_DELTA)
        is HydrationRecord -> listOf(HealthConstants.WATER)
        is SleepSessionRecord -> listOf(HealthConstants.SLEEP_SESSION)
        is NutritionRecord -> listOf(HealthConstants.NUTRITION)
        is RestingHeartRateRecord -> listOf(HealthConstants.RESTING_HEART_RATE)
        is BasalMetabolicRateRecord -> listOf(HealthConstants.BASAL_ENERGY_BURNED)
        is FloorsClimbedRecord -> listOf(HealthConstants.FLIGHTS_CLIMBED)
        is RespiratoryRateRecord -> listOf(HealthConstants.RESPIRATORY_RATE)
        is TotalCaloriesBurnedRecord -> listOf(HealthConstants.TOTAL_CALORIES_BURNED)
        is MenstruationFlowRecord -> listOf(HealthConstants.MENSTRUATION_FLOW)
        is SpeedRecord -> listOf(HealthConstants.SPEED)
        is PowerRecord -> listOf(HealthConstants.POWER)
        is CyclingPedalingCadenceRecord -> listOf(HealthConstants.CYCLING_CADENCE)
        is ActivityIntensityRecord -> listOf(HealthConstants.ACTIVITY_INTENSITY)
        is Vo2MaxRecord -> listOf(HealthConstants.VO2_MAX)
        else -> emptyList()
    }

    private fun convertWorkoutRecord(record: ExerciseSessionRecord): Map<String, Any?> {
        val workoutType = workoutTypeName(record.exerciseType)

        return mapOf(
            "uuid" to record.metadata.id,
            "workoutActivityType" to workoutType,
            "totalDistance" to null,
            "totalDistanceUnit" to null,
            "totalEnergyBurned" to null,
            "totalEnergyBurnedUnit" to null,
            "totalSteps" to null,
            "totalStepsUnit" to null,
            "unit" to "MINUTES",
            "date_from" to record.startTime.toEpochMilli(),
            "date_to" to record.endTime.toEpochMilli(),
            "source_id" to "",
            "source_name" to record.metadata.dataOrigin.packageName,
            "recording_method" to record.metadata.recordingMethod,
        )
    }
}
