package cachet.plugins.health.reading

import android.os.Build
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.workoutTypeName
import kotlin.reflect.KClass

internal const val WORKOUT = "WORKOUT"

/**
 * Converts exercise sessions to workout data points, with totals read from Health Connect.
 *
 * @param packageName This app, whose own workouts' totals may be read with only the write
 * permission of their type
 * @param sdkInt The Android version, which decides whether a refused read of such a total leaves it
 * null or fails ([ReadAccess.isOwnReadRefused])
 */
internal class WorkoutConverter(
    private val healthConnectClient: HealthConnectClient,
    private val recordingFilter: HealthRecordingFilter,
    private val packageName: String,
    private val sdkInt: Int = Build.VERSION.SDK_INT,
) {
    /**
     * Handles special processing for workout/exercise session data.
     * Enriches workout records with associated distance, energy, and step data
     * by querying the related records that the workout's app wrote within the
     * workout time period. Pool and open water swims also get their laps
     * ([swimmingDetails]).
     *
     * @param records List of ExerciseSessionRecord objects
     * @param recordingMethodsToFilter Recording methods to exclude (empty list means no filtering)
     * @param healthConnectData Mutable list to append processed workout data
     * @param grantedPermissions Granted permissions; a total whose type may not be read stays null.
     * The totals of a workout this app wrote are also read with only the write permission of their
     * type: they are read from the workout's app only, which Health Connect allows for its own records.
     */
    suspend fun handleWorkoutData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        healthConnectData: MutableList<Map<String, Any?>>,
        grantedPermissions: Set<String>,
    ) {
        val filteredRecords = if (recordingMethodsToFilter.isEmpty()) {
            records
        } else {
            recordingFilter.filterRecordsByRecordingMethods(
                recordingMethodsToFilter,
                records
            )
        }

        for (rec in filteredRecords) {
            val record = rec as ExerciseSessionRecord
            val totalDistance = total(DistanceRecord::class, record, grantedPermissions) { it.distance.inMeters }
            val totalEnergyBurned =
                total(TotalCaloriesBurnedRecord::class, record, grantedPermissions) { it.energy.inKilocalories }
            val totalSteps = total(StepsRecord::class, record, grantedPermissions) { it.count.toDouble() }

            // Add final datapoint
            healthConnectData.add(
                mapOf<String, Any?>(
                    "uuid" to record.metadata.id,
                    "workoutActivityType" to workoutTypeName(record.exerciseType),
                    "totalDistance" to if (totalDistance == 0.0) null else totalDistance,
                    "totalDistanceUnit" to "METER",
                    "totalEnergyBurned" to if (totalEnergyBurned == 0.0) null else totalEnergyBurned,
                    "totalEnergyBurnedUnit" to "KILOCALORIE",
                    "totalSteps" to if (totalSteps == 0.0) null else totalSteps,
                    "totalStepsUnit" to "COUNT",
                    "unit" to "MINUTES",
                    "date_from" to record.startTime.toEpochMilli(),
                    "date_to" to record.endTime.toEpochMilli(),
                    "source_id" to "",
                    "source_name" to record.metadata.dataOrigin.packageName,
                    "device_model" to record.metadata.device?.model,
                    "swimming" to swimmingDetails(record),
                ),
            )
        }
    }

    /**
     * The sum of [value] over the records of [type] in the time of [session], every page of them, or
     * 0.0 without permission to read them ([granted]). Only the records of the app that wrote the
     * workout: other apps' records of the same activity, such as the phone's own step and distance
     * tracking, would count it twice. A read of this app's own records that the Health Connect APK
     * (Android 13 and lower) refuses also gives 0.0, as without permission.
     */
    private suspend fun <T : Record> total(
        type: KClass<T>,
        session: ExerciseSessionRecord,
        granted: Set<String>,
        value: (T) -> Double,
    ): Double {
        // Reading a type without permission throws, which used to drop every workout.
        val access = ReadAccess.of(granted, type)
        val mayRead = when (access) {
            ReadAccess.ALL -> true
            // Health Connect lets an app read its own records with the write permission.
            ReadAccess.OWN -> session.metadata.dataOrigin.packageName == packageName
            ReadAccess.NONE -> false
        }
        if (!mayRead) return 0.0
        var sum = 0.0
        var pageToken: String? = null
        try {
            do {
                val page = healthConnectClient.readPastTies(
                    ReadRecordsRequest(
                        recordType = type,
                        timeRangeFilter = TimeRangeFilter.between(session.startTime, session.endTime),
                        dataOriginFilter = setOf(session.metadata.dataOrigin),
                        pageSize = HC_MAX_RECORDS,
                        pageToken = pageToken,
                    ),
                )
                sum += page.records.sumOf(value)
                pageToken = page.pageToken
            } while (pageToken != null)
        } catch (e: SecurityException) {
            // Thrown on, the refusal would drop every workout of the page, not just this total.
            if (access != ReadAccess.OWN || !ReadAccess.isOwnReadRefused(e, sdkInt)) throw e
            Log.w("FLUTTER_HEALTH", "${type.simpleName}: Health Connect refused to read this app's own records: $e")
            return 0.0
        }
        return sum
    }
}
