package cachet.plugins.health

import androidx.health.connect.client.records.Record

/**
 * Utility class for filtering health records based on recording methods.
 * Provides functionality to exclude records based on how they were recorded
 * (manual entry, automatic detection, etc.).
 */
class HealthRecordingFilter {
    
    /**
     * Filters a list of health records by excluding specified recording methods.
     * Allows applications to filter out manually entered data, automatic readings,
     * or other recording method types based on user preferences.
     * 
     * @param recordingMethodsToFilter List of recording method integers to exclude from results
     * @param records List of Health Connect records to filter
     * @return List<Record> Filtered list containing only records with allowed recording methods
     */
    fun filterRecordsByRecordingMethods(
        recordingMethodsToFilter: List<Int>,
        records: List<Record>
    ): List<Record> {
        if (recordingMethodsToFilter.isEmpty()) {
            return records
        }

        // No per-record logging: large reads filter hundreds of thousands of records.
        return records.filter { record -> !recordingMethodsToFilter.contains(record.metadata.recordingMethod) }
    }
}