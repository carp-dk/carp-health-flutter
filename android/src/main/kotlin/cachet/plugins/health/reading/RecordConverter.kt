package cachet.plugins.health.reading

import androidx.health.connect.client.records.Record
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthRecordingFilter
import java.time.Instant

/**
 * Converts the records of a read to the data points of its data type: workouts and sleep through
 * their own converters, any other type through [HealthDataConverter] after the recording filter.
 */
internal class RecordConverter(
    private val dataConverter: HealthDataConverter,
    private val recordingFilter: HealthRecordingFilter,
    private val workouts: WorkoutConverter,
    private val sleep: SleepConverter,
) {
    suspend fun convertRecords(
        records: List<Record>,
        dataType: String,
        dataUnit: String?,
        startTime: Instant,
        endTime: Instant,
        recordingMethodsToFilter: List<Int>,
        grantedPermissions: Set<String>,
        out: MutableList<Map<String, Any?>>,
    ) {
        when (dataType) {
            WORKOUT -> workouts.handleWorkoutData(records, recordingMethodsToFilter, out, grantedPermissions)
            in sleepTypes -> sleep.handleSleepData(records, recordingMethodsToFilter, dataType, out)
            else -> {
                for (rec in recordingFilter.filterRecordsByRecordingMethods(recordingMethodsToFilter, records)) {
                    out.addAll(dataConverter.convertRecord(rec, dataType, dataUnit, startTime, endTime))
                }
            }
        }
    }
}
