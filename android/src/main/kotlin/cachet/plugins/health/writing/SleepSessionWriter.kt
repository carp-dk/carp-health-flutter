package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import cachet.plugins.health.optionalString
import cachet.plugins.health.requireLong
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.time.Instant

/**
 * Writes a sleep session with its stages as one sleep session record, for writeSleepSession. Replies
 * true when it is inserted, and false if the record cannot be built ([sleepSessionRecord]), e.g. for a
 * stage whose type is not a sleep stage or a session Health Connect rejects, or the insert fails.
 */
internal class SleepSessionWriter(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
) {
    fun writeSleepSession(call: MethodCall, result: Result) {
        scope.launch {
            val added = try {
                // Built here: a session Health Connect rejects fails the write, not the call.
                healthConnectClient.insertRecords(listOf(sleepSessionRecord(call)))
                Log.i("FLUTTER_HEALTH::SUCCESS", "[Health Connect] Sleep session was successfully added!")
                true
            } catch (e: Exception) {
                logAddFailed("the sleep session", e)
                false
            }
            result.success(added)
        }
    }
}

/**
 * The sleep session of a writeSleepSession [call]: from 'startTime' to 'endTime' (epoch milliseconds),
 * with the optional 'title' and 'notes', the metadata of 'recordingMethod' ([buildMetadata]) and the
 * 'stages', maps with a sleep stage data type 'type' ([sleepStageTypes]), 'startTime' and 'endTime'.
 * Throws IllegalArgumentException if an argument is missing or not of its type, a stage has a type
 * that is not a sleep stage, the session does not end after it starts ([requireStartBeforeEnd]), or
 * Health Connect rejects it: stages that overlap, lie outside the session or do not end after they
 * start (on Android 14+ the platform checks the session while it is built).
 */
internal fun sleepSessionRecord(call: MethodCall): SleepSessionRecord {
    val startTime = Instant.ofEpochMilli(call.requireLong("startTime"))
    val endTime = Instant.ofEpochMilli(call.requireLong("endTime"))
    requireStartBeforeEnd(startTime, endTime)
    val stages = when (val rawStages = call.argument<Any>("stages")) {
        null -> emptyList()
        is List<*> -> rawStages.map(::sleepStage)
        else -> throw IllegalArgumentException("Argument 'stages' must be a list")
    }
    return SleepSessionRecord(
        startTime = startTime,
        startZoneOffset = null,
        endTime = endTime,
        endZoneOffset = null,
        metadata = buildMetadata(call.requireLong("recordingMethod").toInt()),
        title = call.optionalString("title"),
        notes = call.optionalString("notes"),
        stages = stages,
    )
}

/** The stage in [raw], a map with a sleep stage data type 'type', 'startTime' and 'endTime'. */
private fun sleepStage(raw: Any?): SleepSessionRecord.Stage {
    val stage = raw as? Map<*, *> ?: throw IllegalArgumentException("A sleep stage must be a map")
    val type = stage["type"] as? String
    val stageType = sleepStageTypes[type] ?: throw IllegalArgumentException("$type is not a sleep stage type")
    return SleepSessionRecord.Stage(
        startTime = Instant.ofEpochMilli(stage.requireTime("startTime")),
        endTime = Instant.ofEpochMilli(stage.requireTime("endTime")),
        stage = stageType,
    )
}

private fun Map<*, *>.requireTime(key: String): Long =
    (this[key] as? Number)?.toLong() ?: throw IllegalArgumentException("Sleep stage $key must be a number")
