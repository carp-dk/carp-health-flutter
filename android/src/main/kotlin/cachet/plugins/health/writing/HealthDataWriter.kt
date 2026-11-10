package cachet.plugins.health.writing

import androidx.health.connect.client.HealthConnectClient
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope

/**
 * Handles writing health data to Health Connect. Manages data insertion for various health metrics,
 * specialized records like workouts and nutrition, and proper data type conversion from Flutter to
 * Health Connect format.
 *
 * Writes run on the plugin's scope, on the main thread. A write that Health Connect rejects replies
 * false (an empty string where the reply is a UUID), not an error. Errors are replied by writeData
 * and writeDataUUID for a value of a type with a duration that does not end after it starts
 * (INVALID_ARGUMENT), and by the workout route methods (ARGUMENT_ERROR, ROUTE_ERROR, INVALID_ARGUMENT).
 */
class HealthDataWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    private val values = ValueWriter(healthConnectClient, scope)
    private val workouts = WorkoutWriter(healthConnectClient, scope)
    private val routes = WorkoutRouteWriter(healthConnectClient, scope)
    private val bloodPressure = BloodPressureWriter(healthConnectClient, scope)
    private val meals = MealWriter(healthConnectClient, scope)
    private val activityIntensity = ActivityIntensityWriter(healthConnectClient, scope)
    private val sleepSessions = SleepSessionWriter(healthConnectClient, scope)

    /**
     * Writes a single health data record to Health Connect. Supports most basic health metrics with
     * automatic type conversion and validation.
     *
     * @param call Method call containing 'dataTypeKey', 'startTime', 'endTime', 'value',
     * 'recordingMethod' and optionally 'clientRecordId', 'clientRecordVersion', 'deviceType', and for
     * MINDFULNESS 'mindfulnessSessionType', 'title', 'notes' (writeMindfulnessSession)
     * @param result Flutter result callback returning boolean success status, or an INVALID_ARGUMENT
     * error for a value of a type with a duration, such as steps or a sleep stage, that does not end
     * after it starts
     */
    fun writeData(call: MethodCall, result: Result) {
        values.writeData(call, result)
    }

    /**
     * Writes a single health data record to Health Connect, as [writeData] does.
     *
     * @param call Method call with the arguments of [writeData]
     * @param result Flutter result callback returning string inserted record UUID or empty string on
     * failure, or the INVALID_ARGUMENT error of [writeData]
     */
    fun writeDataUUID(call: MethodCall, result: Result) {
        values.writeDataUUID(call, result)
    }

    /**
     * Writes a workout session with optional distance and calorie data. Creates an
     * ExerciseSessionRecord, with a DistanceRecord and a TotalCaloriesBurnedRecord if those totals
     * are provided.
     *
     * @param call Method call containing 'activityType', 'startTime', 'endTime', 'totalEnergyBurned',
     * 'totalDistance', 'recordingMethod', 'title' and optionally 'deviceType'
     * @param result Flutter result callback returning boolean success status
     */
    fun writeWorkoutData(call: MethodCall, result: Result) {
        workouts.writeWorkoutData(call, result)
    }

    /**
     * Writes a workout session as [writeWorkoutData] does.
     *
     * @param call Method call with the arguments of [writeWorkoutData]
     * @param result Flutter result callback returning the UUID of the exercise session or empty
     * string on failure
     */
    fun writeWorkoutDataUUID(call: MethodCall, result: Result) {
        workouts.writeWorkoutDataUUID(call, result)
    }

    /**
     * Writes blood pressure measurement with both systolic and diastolic values. Creates a single
     * BloodPressureRecord containing both pressure readings taken at the same time point.
     *
     * @param call Method call containing 'systolic', 'diastolic', 'startTime', 'recordingMethod'
     * and optionally 'clientRecordId', 'clientRecordVersion', 'deviceType'
     * @param result Flutter result callback returning boolean success status
     */
    fun writeBloodPressure(call: MethodCall, result: Result) {
        bloodPressure.writeBloodPressure(call, result)
    }

    /**
     * Writes blood oxygen saturation measurement. Delegates to standard writeData method for
     * OxygenSaturationRecord handling.
     *
     * @param call Method call with blood oxygen data
     * @param result Flutter result callback returning success status
     */
    fun writeBloodOxygen(call: MethodCall, result: Result) {
        writeData(call, result)
    }

    /**
     * Writes menstrual flow data. Delegates to standard writeData method for MenstruationFlowRecord
     * handling.
     *
     * @param call Method call with menstruation flow data
     * @param result Flutter result callback returning success status
     */
    fun writeMenstruationFlow(call: MethodCall, result: Result) {
        writeData(call, result)
    }

    /**
     * Writes nutrition/meal data with detailed nutrient breakdown. Creates a NutritionRecord with
     * nutrient information including vitamins, minerals, macronutrients, and meal classification.
     *
     * @param call Method call containing 'start_time', 'end_time', 'meal_type', optionally 'name',
     * the nutrients ('calories', 'protein', ...), 'recordingMethod', 'clientRecordId',
     * 'clientRecordVersion' and 'deviceType'
     * @param result Flutter result callback returning boolean success status
     */
    fun writeMeal(call: MethodCall, result: Result) {
        meals.writeMeal(call, result)
    }

    /**
     * Writes a period of activity of a given intensity as an ActivityIntensityRecord.
     *
     * @param call Method call containing 'intensityType', 'startTime', 'endTime', 'recordingMethod'
     * and optionally 'clientRecordId', 'clientRecordVersion', 'deviceType'
     * @param result Flutter result callback returning boolean success status
     */
    fun writeActivityIntensity(call: MethodCall, result: Result) {
        activityIntensity.writeActivityIntensity(call, result)
    }

    /**
     * Writes a sleep session with its stages as one SleepSessionRecord.
     *
     * @param call Method call containing 'startTime', 'endTime', 'recordingMethod', 'stages' (maps
     * with a sleep stage type 'type', 'startTime' and 'endTime') and optionally 'title', 'notes'
     * @param result Flutter result callback returning boolean success status
     */
    fun writeSleepSession(call: MethodCall, result: Result) {
        sleepSessions.writeSleepSession(call, result)
    }

    /**
     * Starts collecting the locations of a workout route.
     *
     * @param result Flutter result callback returning the id of the route builder
     */
    fun startWorkoutRoute(result: Result) {
        routes.startWorkoutRoute(result)
    }

    /**
     * Adds locations to a workout route that was started and is not finished yet.
     *
     * @param call Method call containing 'builderId' and 'locations', each a map with the numbers
     * 'latitude', 'longitude', 'timestamp' and optionally 'altitude', 'horizontalAccuracy',
     * 'verticalAccuracy'
     * @param result Flutter result callback returning true, an ARGUMENT_ERROR or ROUTE_ERROR for the
     * builder, or INVALID_ARGUMENT for a location that lacks a value or has one that is not a number
     */
    fun insertWorkoutRouteData(call: MethodCall, result: Result) {
        routes.insertWorkoutRouteData(call, result)
    }

    /**
     * Attaches the locations of a workout route, in time order, to a workout that is already written.
     *
     * @param call Method call containing 'builderId' and 'workoutUUID'
     * @param result Flutter result callback returning {uuid: workoutUUID}, or an ARGUMENT_ERROR or
     * ROUTE_ERROR
     */
    fun finishWorkoutRoute(call: MethodCall, result: Result) {
        routes.finishWorkoutRoute(call, result)
    }

    /**
     * Drops a workout route without writing it.
     *
     * @param call Method call containing 'builderId'
     * @param result Flutter result callback returning true, or an ARGUMENT_ERROR
     */
    fun discardWorkoutRoute(call: MethodCall, result: Result) {
        routes.discardWorkoutRoute(call, result)
    }
}
