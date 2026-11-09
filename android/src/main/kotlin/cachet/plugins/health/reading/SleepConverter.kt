package cachet.plugins.health.reading

import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthRecordingFilter

// Sleep-related constants
private const val SLEEP_SESSION = "SLEEP_SESSION"
private const val SLEEP_ASLEEP = "SLEEP_ASLEEP"
private const val SLEEP_AWAKE = "SLEEP_AWAKE"
private const val SLEEP_AWAKE_IN_BED = "SLEEP_AWAKE_IN_BED"
private const val SLEEP_LIGHT = "SLEEP_LIGHT"
private const val SLEEP_DEEP = "SLEEP_DEEP"
private const val SLEEP_REM = "SLEEP_REM"
private const val SLEEP_OUT_OF_BED = "SLEEP_OUT_OF_BED"
private const val SLEEP_UNKNOWN = "SLEEP_UNKNOWN"

internal val sleepTypes = setOf(
    SLEEP_SESSION, SLEEP_ASLEEP, SLEEP_AWAKE, SLEEP_AWAKE_IN_BED,
    SLEEP_LIGHT, SLEEP_DEEP, SLEEP_REM, SLEEP_OUT_OF_BED, SLEEP_UNKNOWN,
)

/** Converts sleep sessions to session or stage data points. */
internal class SleepConverter(
    private val dataConverter: HealthDataConverter,
    private val recordingFilter: HealthRecordingFilter,
) {
    /**
     * Handles special processing for sleep session and stage data.
     * Processes sleep sessions and individual sleep stages based on requested data type.
     * Converts sleep stage enumerations to meaningful duration and type information.
     *
     * @param records List of SleepSessionRecord objects
     * @param recordingMethodsToFilter Recording methods to exclude (empty list means no filtering)
     * @param dataType Specific sleep data type being requested
     * @param healthConnectData Mutable list to append processed sleep data
     */
    fun handleSleepData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        dataType: String,
        healthConnectData: MutableList<Map<String, Any?>>
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
            if (rec is SleepSessionRecord) {
                if (dataType == SLEEP_SESSION) {
                    healthConnectData.addAll(
                        dataConverter.convertRecord(rec, dataType)
                    )
                } else {
                    for (recStage in rec.stages) {
                        if (dataType == HealthConstants.mapSleepStageToType[recStage.stage]) {
                            healthConnectData.addAll(
                                dataConverter.convertRecordStage(
                                    recStage,
                                    dataType,
                                    rec.metadata
                                )
                            )
                        }
                    }
                }
            }
        }
    }
}
