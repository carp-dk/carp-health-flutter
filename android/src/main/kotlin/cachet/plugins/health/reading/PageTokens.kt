package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.ActivityIntensityRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.BodyTemperatureRecord
import androidx.health.connect.client.records.BodyWaterMassRecord
import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.LeanBodyMassRecord
import androidx.health.connect.client.records.MenstruationFlowRecord
import androidx.health.connect.client.records.MindfulnessSessionRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SexualActivityRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant

/*
 * Health Connect page tokens and records that share a start time. From android14-qpr2-release on (up to AOSP
 * main) a token is a position ([HealthConnectPosition]): a time, an offset and the order. A read with it matches
 * the records that start at or after the time (newest first: at or before), and skips the offset of those that
 * start at that very time, which the pages before returned (RecordHelper.getNextInternalRecordsPageAndToken).
 * But the next token's offset counts only the records of its time on the page that returns it, and Android 15
 * (module 350820300) skips rows of the read's join instead of records: a series record's samples, a sleep
 * session's stages, an exercise session's laps times its segments. So where the records of one start time cross
 * a page boundary, Health Connect's own tokens return some of them twice or in part, skip others, or return the
 * same page forever (measured on Android 15, 16 and 17), and an offset the plugin works out is no better.
 *
 * So the plugin never sends Health Connect an offset ([readPastTies]). Where a page ends inside the records of
 * one start time, one more request reads all of them, and the next page starts just after that time, with a
 * token of the plugin's own at offset 0 (accepted on Android 15 and 16). Within one start time Health Connect
 * returns records by row id in both orders, so those the page holds are the first ones of that request.
 *
 * android14-release and android14-qpr1-release tokens have no offset (time * 2, plus 1 newest first), which is
 * the same number as a position at offset 0. Those versions return the records of one start time only together
 * (RecordHelper.getInternalRecords over pageSize + 1 rows), so their pages never end inside them; but where more
 * of them start at the first time a request matches than it asks for, they return an empty page with the token
 * of that time, which is read the same way.
 */

/**
 * Reads [request], and where its page ends inside the records of one start time T, every record of T in one
 * more request ([pastTies]). A page may so hold up to all records of one start time more than [request] asks
 * for, and costs one more Health Connect call where it ends inside them.
 */
internal suspend fun <T : Record> HealthConnectClient.readPastTies(request: ReadRecordsRequest<T>): RecordsPage<T> =
    pastTies(request, readRecords(request))

/**
 * The page that [request] got as [response], and the token of the next request (null after the last page).
 * Where the page ends inside the records of one start time T (Health Connect's next token has the time of its
 * last record, [pagingTimeMillis]), one more request of the same type and data origins reads every record of
 * T, at most [HC_MAX_RECORDS]: those in [T, T + 1 ms), which the request's range holds. They come by row id, as
 * the page's records of T do, and take their place; the next token is the position just after T (newest
 * first: just before) at offset 0, or null where that is outside the request's range. An empty page that comes
 * with a token (android14-release, where more records start at its time than the request asks for) is read
 * the same way at the token's time.
 *
 * Throws IllegalStateException where Health Connect returns the token it was sent, or a token with an offset,
 * and the page cannot be moved past this way (a token of the Health Connect APK on Android 13 and lower, which
 * is no position, or a record type [pagingTimeMillis] does not know), or where more than [HC_MAX_RECORDS]
 * records start at T, which one request cannot hold: such a read fails instead of going round forever or
 * returning records twice.
 */
internal suspend fun <T : Record> HealthConnectClient.pastTies(
    request: ReadRecordsRequest<T>,
    response: ReadRecordsResponse<T>,
): RecordsPage<T> {
    val records = response.records
    val next = response.pageToken?.takeIf { it.isNotEmpty() } ?: return RecordsPage(records, null)
    val position = HealthConnectPosition.decode(next)
    val tie = position?.let { tieTime(request.pageToken, records, it) }
    if (position == null || tie == null) {
        check(next != request.pageToken) {
            "Health Connect returned the same page token twice ($next, after a page of ${records.size} records), " +
                "so the read cannot go on"
        }
        // Health Connect gives a token an offset only after a page that ends inside the records of its time, which
        // the plugin finds for every type it reads ([pagingTimeMillis]).
        check(position == null || position.offset == 0) {
            "Health Connect returned a page token with an offset ($next) for ${request.recordType.simpleName}, " +
                "which the plugin cannot follow"
        }
        return RecordsPage(records, next)
    }
    val group = readStartingAt(request, tie, position.descending)
    val before = records.dropLastWhile { pagingTimeMillis(it) == tie }
    return RecordsPage(before + group, pastTime(request.timeRangeFilter, tie, position.descending), group.size)
}

/**
 * The start time whose records the page [records] ends inside, as Health Connect's [next] position shows: the
 * time of its last record, if [next] has it. After an empty page the time of [next] itself, unless it is behind
 * the position [sent] in the read's order. Null if there is none.
 */
private fun tieTime(sent: String?, records: List<Record>, next: HealthConnectPosition): Long? {
    if (records.isNotEmpty()) return pagingTimeMillis(records.last())?.takeIf { it == next.timeMillis }
    val from = sent?.let { HealthConnectPosition.decode(it) ?: return null } ?: return next.timeMillis
    val ahead = if (next.descending) next.timeMillis <= from.timeMillis else next.timeMillis >= from.timeMillis
    return next.timeMillis.takeIf { ahead && next.descending == from.descending }
}

/**
 * Every record of [request]'s type and data origins that starts at [time] (epoch ms), in one request. Throws
 * IllegalStateException where they are more than it returns: Health Connect reads one record more than a
 * request asks for and sends a token only then, so [HC_MAX_RECORDS] of them still come whole.
 */
private suspend fun <T : Record> HealthConnectClient.readStartingAt(
    request: ReadRecordsRequest<T>,
    time: Long,
    descending: Boolean,
): List<T> {
    val at = Instant.ofEpochMilli(time)
    val response = readRecords(
        ReadRecordsRequest(
            recordType = request.recordType,
            timeRangeFilter = TimeRangeFilter.between(at, at.plusMillis(1)),
            dataOriginFilter = request.dataOriginFilter,
            ascendingOrder = !descending,
            pageSize = HC_MAX_RECORDS,
        )
    )
    check(response.pageToken.isNullOrEmpty()) {
        "More than $HC_MAX_RECORDS ${request.recordType.simpleName} records start at $at, which Health Connect " +
            "cannot page past, so the read cannot go on"
    }
    return response.records
}

/**
 * How many of [records], one page in Health Connect's order, start before the last one does (newest first:
 * after it): the most records worth reading the same position again with to get a smaller page. The records of
 * one start time come only whole ([pastTies]), so a read again with more gets all those of the last one's start
 * time again, whether or not the page ended inside them (android14-release: none of them, as with this many).
 * All of [records] for a type [pagingTimeMillis] does not know.
 */
internal fun recordsBeforeLastStart(records: List<Record>): Int {
    val last = records.lastOrNull()?.let(::pagingTimeMillis) ?: return records.size
    return records.dropLastWhile { pagingTimeMillis(it) == last }.size
}

/**
 * The token of the position just after [time] (newest first: just before) at offset 0, or null where that is
 * outside [range]. Health Connect then matches the records that start after [time] (before it); so does
 * android14-release, whose token is the same number ([HealthConnectPosition.encode]).
 */
private fun pastTime(range: TimeRangeFilter, time: Long, descending: Boolean): String? {
    val next = if (descending) time - 1 else time + 1
    val inRange =
        if (descending) next >= maxOf(0L, range.startTime?.toEpochMilli() ?: 0L)
        else range.endTime.let { it == null || next < it.toEpochMilli() }
    return if (inRange) HealthConnectPosition(descending, next, 0).encode() else null
}

/**
 * The position a Health Connect page token stands for on Android 14 and later: the start time of the next
 * record, how many records of that start time the pages before returned ([offset]), and the order. The
 * token is a decimal long, PageTokenWrapper.encode(): bit 0 is set when [descending], bits 1 to 44 hold
 * [timeMillis] and bits 45 to 62 [offset] (android14-release has no offset: time * 2, plus 1 if descending).
 * The plugin sends Health Connect only positions at offset 0 ([readPastTies]).
 */
internal class HealthConnectPosition(val descending: Boolean, val timeMillis: Long, val offset: Int) {
    /**
     * The token of this position, as PageTokenWrapper.encode() makes it. With [offset] 0 it is also the
     * token of android14-release and android14-qpr1-release, which carry the order in bit 0 too: a read
     * with it matches the records that start at or after [timeMillis] (newest first: at or before).
     */
    fun encode(): String {
        require(timeMillis in 0..MAX_TIME_MILLIS && offset in 0..MAX_OFFSET) { "No page token for $timeMillis+$offset" }
        return ((offset.toLong() shl 45) or (timeMillis shl 1) or (if (descending) 1L else 0L)).toString()
    }

    companion object {
        private const val MAX_TIME_MILLIS = (1L shl 44) - 1
        private const val MAX_OFFSET = (1 shl 18) - 1

        /** The position of [token], or null if it is not such a token. */
        fun decode(token: String): HealthConnectPosition? {
            val value = token.toLongOrNull()?.takeIf { it >= 0 } ?: return null
            val timeMillis = (value shr 1) and MAX_TIME_MILLIS
            return HealthConnectPosition(value and 1L == 1L, timeMillis, (value ushr 45).toInt())
        }
    }
}

/**
 * The time Health Connect orders and pages [record] by (epoch ms): its start time, or its time if it is a
 * measurement at an instant. Null for a type the plugin does not read (connect-client keeps the interfaces
 * of both kinds internal), whose ties are then not moved past.
 */
internal fun pagingTimeMillis(record: Record): Long? = when (record) {
    is ActiveCaloriesBurnedRecord -> record.startTime
    is ActivityIntensityRecord -> record.startTime
    is CyclingPedalingCadenceRecord -> record.startTime
    is DistanceRecord -> record.startTime
    is ExerciseSessionRecord -> record.startTime
    is FloorsClimbedRecord -> record.startTime
    is HeartRateRecord -> record.startTime
    is HydrationRecord -> record.startTime
    is MindfulnessSessionRecord -> record.startTime
    is NutritionRecord -> record.startTime
    is PowerRecord -> record.startTime
    is SkinTemperatureRecord -> record.startTime
    is SleepSessionRecord -> record.startTime
    is SpeedRecord -> record.startTime
    is StepsRecord -> record.startTime
    is TotalCaloriesBurnedRecord -> record.startTime
    is BasalMetabolicRateRecord -> record.time
    is BloodGlucoseRecord -> record.time
    is BloodPressureRecord -> record.time
    is BodyFatRecord -> record.time
    is BodyTemperatureRecord -> record.time
    is BodyWaterMassRecord -> record.time
    is HeartRateVariabilityRmssdRecord -> record.time
    is HeightRecord -> record.time
    is LeanBodyMassRecord -> record.time
    is MenstruationFlowRecord -> record.time
    is OxygenSaturationRecord -> record.time
    is RespiratoryRateRecord -> record.time
    is RestingHeartRateRecord -> record.time
    is SexualActivityRecord -> record.time
    is Vo2MaxRecord -> record.time
    is WeightRecord -> record.time
    else -> null
}?.toEpochMilli()
