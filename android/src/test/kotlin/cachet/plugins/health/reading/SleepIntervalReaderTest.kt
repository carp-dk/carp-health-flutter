package cachet.plugins.health.reading

import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord.Stage
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthRecordingFilter
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SleepIntervalReaderTest {
    private val start = Instant.parse("2026-11-08T00:00:00Z")
    private val end = start.plus(Duration.ofHours(12))
    private val requests = mutableListOf<ReadRecordsRequest<*>>()

    private fun time(hhmm: String, day: Int = 8): Instant = Instant.parse("2026-11-0${day}T$hhmm:00Z")

    // A night that began the evening before the read, with a stage of each type.
    private val night = sleepSession(
        time("22:30", day = 7), time("06:30"),
        stages = listOf(
            Stage(time("22:30", day = 7), time("23:00", day = 7), SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED),
            Stage(time("23:00", day = 7), time("01:00"), SleepSessionRecord.STAGE_TYPE_LIGHT),
            Stage(time("01:00"), time("02:00"), SleepSessionRecord.STAGE_TYPE_DEEP),
            Stage(time("02:00"), time("02:20"), SleepSessionRecord.STAGE_TYPE_AWAKE),
            Stage(time("02:20"), time("03:00"), SleepSessionRecord.STAGE_TYPE_SLEEPING),
            Stage(time("03:00"), time("04:30"), SleepSessionRecord.STAGE_TYPE_REM),
            Stage(time("04:30"), time("04:40"), SleepSessionRecord.STAGE_TYPE_OUT_OF_BED),
            Stage(time("04:40"), time("05:00"), SleepSessionRecord.STAGE_TYPE_UNKNOWN),
            Stage(time("05:00"), time("06:30"), SleepSessionRecord.STAGE_TYPE_SLEEPING),
        ),
        packageName = "com.example.watch",
    )

    // A manual entry of another app, without stages, that overlaps the end of the night.
    private val morning = sleepSession(
        time("05:30"), time("07:00"),
        packageName = "com.example.diary",
        recordingMethod = Metadata.RECORDING_METHOD_MANUAL_ENTRY,
    )

    /** Reads [dataType] in buckets of [interval] while Health Connect holds [pages] of sessions. */
    private fun read(
        dataType: String,
        vararg pages: List<SleepSessionRecord>,
        recordingMethodsToFilter: List<Int> = emptyList(),
        interval: Duration = Duration.ofHours(1),
        endTime: Instant = end,
    ): List<Map<String, Any>> {
        val client = fakeHealthConnect { method, args ->
            check(method == "readRecords") { "Unexpected call of $method" }
            val request = args.single() as ReadRecordsRequest<*>
            requests.add(request)
            val page = request.pageToken?.toInt() ?: 0
            ReadRecordsResponse(pages[page], if (page < pages.lastIndex) "${page + 1}" else null)
        }
        val reader = SleepIntervalReader(client, HealthRecordingFilter())
        return runBlocking { reader.readIntervals(dataType, start, endTime, interval, recordingMethodsToFilter) }
    }

    // Each bucket as (start, minutes).
    private fun List<Map<String, Any>>.minutes() = map { Instant.ofEpochMilli(it["date_from"] as Long) to it["value"] }

    private fun minutes(vararg buckets: Pair<String, Double>) = buckets.map { (from, minutes) -> time(from) to minutes }

    @Test
    fun aSessionCountsWithItsPartInsideTheRange() {
        val data = read(HealthConstants.SLEEP_SESSION, listOf(night))
        // The six hours from midnight, and the half hour until 06:30.
        val hours = (0..5).map { "0$it:00" to 60.0 } + ("06:00" to 30.0)
        assertEquals(minutes(*hours.toTypedArray()), data.minutes())
        assertEquals(
            mapOf(
                "value" to 30.0,
                "date_from" to time("06:00").toEpochMilli(),
                "date_to" to time("07:00").toEpochMilli(),
                "source_name" to "com.example.watch",
                "source_id" to "",
                "is_manual_entry" to false,
            ),
            data.last(),
        )
        // Health Connect matches sessions by start time: the read starts a day early.
        val request = requests.single()
        assertEquals(SleepSessionRecord::class, request.recordType)
        assertEquals(start.minus(Duration.ofHours(24)), request.timeRangeFilter.startTime)
        assertEquals(end, request.timeRangeFilter.endTime)
        assertEquals(SLEEP_MAX_RECORDS, request.pageSize)
    }

    @Test
    fun stageTypesCoverTheStagesOfThatType() {
        val expected = mapOf(
            HealthConstants.SLEEP_LIGHT to minutes("00:00" to 60.0),
            HealthConstants.SLEEP_DEEP to minutes("01:00" to 60.0),
            HealthConstants.SLEEP_AWAKE to minutes("02:00" to 20.0),
            // The SLEEPING stages, not the light, deep or REM ones.
            HealthConstants.SLEEP_ASLEEP to minutes("02:00" to 40.0, "05:00" to 60.0, "06:00" to 30.0),
            HealthConstants.SLEEP_REM to minutes("03:00" to 60.0, "04:00" to 30.0),
            HealthConstants.SLEEP_OUT_OF_BED to minutes("04:00" to 10.0),
            HealthConstants.SLEEP_UNKNOWN to minutes("04:00" to 20.0),
            // Only before the range.
            HealthConstants.SLEEP_AWAKE_IN_BED to minutes(),
        )
        assertEquals(sleepTypes - HealthConstants.SLEEP_SESSION, expected.keys)
        for ((type, buckets) in expected) {
            assertEquals(type, buckets, read(type, listOf(night)).minutes())
        }
    }

    @Test
    fun intervalsCoverTheDataPointsThatReadsReturn() {
        // The night's stages do not overlap: the minutes of the read's points add up to the intervals.
        for (type in sleepTypes) {
            val points = mutableListOf<Map<String, Any?>>()
            SleepConverter(HealthDataConverter(), HealthRecordingFilter()).handleSleepData(listOf(night), emptyList(), type, points)
            val pointMinutes = points.sumOf { point ->
                val from = maxOf(point["date_from"] as Long, start.toEpochMilli())
                val to = minOf(point["date_to"] as Long, end.toEpochMilli())
                maxOf(0L, to - from) / 60_000.0
            }
            assertEquals(type, pointMinutes, read(type, listOf(night)).sumOf { it["value"] as Double }, 1e-9)
        }
    }

    @Test
    fun aSessionWithoutStagesHasNoStageIntervals() {
        assertEquals(minutes(), read(HealthConstants.SLEEP_ASLEEP, listOf(morning)).minutes())
        assertEquals(minutes("05:00" to 30.0, "06:00" to 60.0), read(HealthConstants.SLEEP_SESSION, listOf(morning)).minutes())
    }

    @Test
    fun overlappingSessionsAreCountedOnce() {
        val data = read(HealthConstants.SLEEP_SESSION, listOf(night, morning))
        // 05:00-07:00 is covered by the night until 06:30 and by the morning from 05:30.
        assertEquals(minutes("05:00" to 60.0, "06:00" to 60.0), data.takeLast(2).minutes())
        assertEquals(List(2) { "com.example.watch, com.example.diary" }, data.takeLast(2).map { it["source_name"] })
        assertEquals("com.example.watch", data.first()["source_name"])
    }

    @Test
    fun everyPageIsRead() {
        val data = read(HealthConstants.SLEEP_SESSION, listOf(night), listOf(morning))
        assertEquals(listOf(null, "1"), requests.map { it.pageToken })
        assertEquals(List(2) { start.minus(Duration.ofHours(24)) }, requests.map { it.timeRangeFilter.startTime })
        assertEquals(read(HealthConstants.SLEEP_SESSION, listOf(night, morning)), data)
    }

    @Test
    fun recordingMethodsAreFiltered() {
        val manual = listOf(Metadata.RECORDING_METHOD_MANUAL_ENTRY)
        val data = read(HealthConstants.SLEEP_SESSION, listOf(night, morning), recordingMethodsToFilter = manual)
        assertEquals(read(HealthConstants.SLEEP_SESSION, listOf(night)), data)
    }

    @Test
    fun theLastBucketEndsAtTheEndOfTheRead() {
        val data = read(HealthConstants.SLEEP_SESSION, listOf(night), interval = Duration.ofHours(4), endTime = time("05:00"))
        assertEquals(minutes("00:00" to 240.0, "04:00" to 60.0), data.minutes())
        assertEquals(time("05:00").toEpochMilli(), data.last()["date_to"])
    }

    @Test
    fun anEmptyRangeIsNotRead() {
        assertEquals(emptyList<Map<String, Any>>(), read(HealthConstants.SLEEP_SESSION, listOf(night), endTime = start))
        assertEquals(emptyList<ReadRecordsRequest<*>>(), requests)
    }

    @Test
    fun theIntervalMustBePositive() {
        for (interval in listOf(Duration.ZERO, Duration.ofHours(-1))) {
            assertThrows(IllegalArgumentException::class.java) {
                read(HealthConstants.SLEEP_SESSION, listOf(night), interval = interval)
            }
        }
        assertEquals(emptyList<ReadRecordsRequest<*>>(), requests)
    }
}
