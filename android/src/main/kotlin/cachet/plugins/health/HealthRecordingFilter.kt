package cachet.plugins.health

import android.util.Log
import androidx.health.connect.client.records.Record

/**
 * Filters Health Connect records by recording method.
 */
class HealthRecordingFilter {

    /**
     * Records whose recording methods are not in the excluded method list.
     *
     * @param recordingMethodsToFilter Recording method values to exclude.
     * @param records Health Connect records to filter.
     * @return Records with allowed recording methods.
     */
    fun filterRecordsByRecordingMethods(
        recordingMethodsToFilter: List<Int>,
        records: List<Record>
    ): List<Record> {
        if (recordingMethodsToFilter.isEmpty()) {
            return records
        }

        return records.filter { record ->
            val shouldInclude = !recordingMethodsToFilter.contains(record.metadata.recordingMethod)

            Log.i(
                "FLUTTER_HEALTH",
                "Filtering record with recording method ${record.metadata.recordingMethod}, " +
                "filtering by $recordingMethodsToFilter. " +
                "Result: $shouldInclude"
            )

            shouldInclude
        }
    }
}
