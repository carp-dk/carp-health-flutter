package cachet.plugins.health.reading

import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthRecordingFilter
import java.time.Instant

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

/** Whether [dataType] is a sleep stage type: a sleep type other than SLEEP_SESSION. */
internal fun isSleepStageType(dataType: String): Boolean = dataType in sleepTypes && dataType != SLEEP_SESSION

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
     * @param from If set, the stages that start before this are dropped: a read of a range returns the
     * stages that start in it, whichever session they belong to. Sessions are kept whatever their times.
     * @param to If set, the stages that start at or after this are dropped
     */
    fun handleSleepData(
        records: List<Record>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        dataType: String,
        healthConnectData: MutableList<Map<String, Any?>>,
        from: Instant? = null,
        to: Instant? = null,
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
                for (point in sleepPoints(rec, dataType)) {
                    val stage = point.stage
                    if (stage != null && !startsIn(stage, from, to)) continue
                    healthConnectData.addAll(
                        if (stage == null) {
                            dataConverter.convertRecord(rec, dataType)
                        } else {
                            dataConverter.convertRecordStage(stage, dataType, rec.metadata)
                        }
                    )
                }
            }
        }
    }
}

/** Whether [stage] starts in [from, to); a bound that is not set does not limit it. */
private fun startsIn(stage: SleepSessionRecord.Stage, from: Instant?, to: Instant?): Boolean =
    (from == null || !stage.startTime.isBefore(from)) && (to == null || stage.startTime.isBefore(to))

/** A data point of a sleep type: a whole session, or one of its stages ([stage]). */
internal class SleepPoint(
    val startTime: Instant,
    val endTime: Instant,
    val stage: SleepSessionRecord.Stage? = null,
)

/**
 * The data points of the sleep type [dataType] in [session]: the session itself for SLEEP_SESSION,
 * otherwise its stages of that type (none for a session without stages). Reads convert these points,
 * and sleep intervals add up the time they cover ([SleepIntervalReader]).
 */
internal fun sleepPoints(session: SleepSessionRecord, dataType: String): List<SleepPoint> =
    if (dataType == SLEEP_SESSION) {
        listOf(SleepPoint(session.startTime, session.endTime))
    } else {
        session.stages
            .filter { HealthConstants.mapSleepStageToType[it.stage] == dataType }
            .map { SleepPoint(it.startTime, it.endTime, it) }
    }
