package cachet.plugins.health.reading

import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SleepSessionRecord.Stage
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import cachet.plugins.health.HealthConstants
import java.time.Duration
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Test

/** Range reads of the sleep types, from Health Connect that matches sessions by start time ([fakeSleepStore]). */
class SleepStageReadsTest {
    private val reads = SleepReads()
    private val requests get() = reads.requests
    private val stageTypes = sleepTypes - HealthConstants.SLEEP_SESSION

    private fun time(hhmm: String, day: Int = 8): Instant = Instant.parse("2026-11-0${day}T$hhmm:00Z")

    // An afternoon nap; a night from 22:00 to 06:30 with stages of every type; and a manual entry of
    // another app that overlaps the end of the night.
    private val nap = sleepSession(
        time("15:00", day = 7), time("15:40", day = 7),
        stages = listOf(Stage(time("15:00", day = 7), time("15:40", day = 7), SleepSessionRecord.STAGE_TYPE_LIGHT)),
        packageName = WATCH,
    )
    private val night = sleepSession(
        time("22:00", day = 7), time("06:30"),
        stages = listOf(
            Stage(time("22:00", day = 7), time("22:20", day = 7), SleepSessionRecord.STAGE_TYPE_AWAKE_IN_BED),
            Stage(time("22:20", day = 7), time("23:30", day = 7), SleepSessionRecord.STAGE_TYPE_LIGHT),
            Stage(time("23:30", day = 7), time("00:30"), SleepSessionRecord.STAGE_TYPE_DEEP),
            Stage(time("00:30"), time("01:30"), SleepSessionRecord.STAGE_TYPE_LIGHT),
            Stage(time("01:30"), time("02:00"), SleepSessionRecord.STAGE_TYPE_REM),
            Stage(time("02:00"), time("02:10"), SleepSessionRecord.STAGE_TYPE_AWAKE),
            Stage(time("02:10"), time("03:30"), SleepSessionRecord.STAGE_TYPE_LIGHT),
            Stage(time("03:30"), time("04:30"), SleepSessionRecord.STAGE_TYPE_DEEP),
            Stage(time("04:30"), time("05:30"), SleepSessionRecord.STAGE_TYPE_REM),
            Stage(time("05:30"), time("06:00"), SleepSessionRecord.STAGE_TYPE_SLEEPING),
            Stage(time("06:00"), time("06:10"), SleepSessionRecord.STAGE_TYPE_OUT_OF_BED),
            Stage(time("06:10"), time("06:30"), SleepSessionRecord.STAGE_TYPE_UNKNOWN),
        ),
        packageName = WATCH,
    )
    private val morning = sleepSession(
        time("06:00"), time("07:30"),
        stages = listOf(
            Stage(time("06:00"), time("06:45"), SleepSessionRecord.STAGE_TYPE_LIGHT),
            Stage(time("06:45"), time("07:30"), SleepSessionRecord.STAGE_TYPE_AWAKE),
        ),
        packageName = DIARY,
        recordingMethod = Metadata.RECORDING_METHOD_MANUAL_ENTRY,
    )
    private val sessions = listOf(nap, night, morning)

    private fun read(
        dataType: String,
        from: Instant,
        to: Instant,
        sessions: List<SleepSessionRecord> = this.sessions,
        pageSize: Int = DEFAULT_PAGE_SIZE,
        recordingMethodsToFilter: List<Int> = emptyList(),
    ): PageRead = reads.pages(dataType, from, to, sessions, pageSize, recordingMethodsToFilter)

    /** The stages of [type] in the sessions that start in [from, to), oldest session first. */
    private fun stagesStartingIn(type: String, from: Instant, to: Instant) =
        sessions.sortedBy { it.startTime }.flatMap { session ->
            session.stages
                .filter { HealthConstants.mapSleepStageToType[it.stage] == type }
                .filter { !it.startTime.isBefore(from) && it.startTime.isBefore(to) }
                .map { ReadPoint(it.startTime, it.endTime, session.metadata.dataOrigin.packageName) }
        }

    private fun List<ReadRecordsRequest<*>>.ranges() =
        map { it.timeRangeFilter.startTime to it.timeRangeFilter.endTime }

    @Test
    fun aReadFromMidNightReturnsTheStagesThatStartInIt() {
        // Health Connect returns the night, which began at 22:00, to no read that starts later.
        val light = read(HealthConstants.SLEEP_LIGHT, time("00:15"), time("12:00"))
        val expected = listOf(
            ReadPoint(time("00:30"), time("01:30"), WATCH),
            ReadPoint(time("02:10"), time("03:30"), WATCH),
            ReadPoint(time("06:00"), time("06:45"), DIARY),
        )
        assertEquals(expected, light.points)
        // The range, then the sessions that began in the 24 hours before it.
        assertEquals(listOf(time("00:15") to time("12:00"), time("00:15", day = 7) to time("00:15")), requests.ranges())
        for (type in stageTypes) {
            val points = read(type, time("00:15"), time("12:00")).points
            assertEquals(type, stagesStartingIn(type, time("00:15"), time("12:00")), points)
        }
    }

    @Test
    fun consecutiveWindowsTogetherReturnEveryStageOnce() {
        val (from, to) = time("12:00", day = 7) to time("12:00")
        // Inside a stage, at the end of a stage, at the start of a session, near the end of the night, after it.
        val splits =
            listOf(time("23:45", day = 7), time("00:30"), time("02:05"), time("06:00"), time("06:20"), time("09:00"))
        for (type in stageTypes) {
            for (split in splits) {
                for (pageSize in listOf(1, DEFAULT_PAGE_SIZE)) {
                    val label = "$type split at $split, pageSize $pageSize"
                    val first = read(type, from, split, pageSize = pageSize).points
                    val second = read(type, split, to, pageSize = pageSize).points
                    assertEquals(label, stagesStartingIn(type, from, split), first)
                    assertEquals(label, stagesStartingIn(type, split, to), second)
                    val all = stagesStartingIn(type, from, to)
                    assertEquals(label, all.sortedBy { it.from }, (first + second).sortedBy { it.from })
                }
            }
        }
    }

    @Test
    fun sleepSessionReadsAreUnchanged() {
        // A session is returned whole when it starts in the range, and nothing before the range is read.
        val fromMidNight = read(HealthConstants.SLEEP_SESSION, time("00:15"), time("12:00"))
        assertEquals(listOf(ReadPoint(time("06:00"), time("07:30"), DIARY)), fromMidNight.points)
        assertEquals(listOf(time("00:15") to time("12:00")), requests.ranges())
        val evening = read(HealthConstants.SLEEP_SESSION, time("12:00", day = 7), time("00:15"))
        val expected = listOf(
            ReadPoint(time("15:00", day = 7), time("15:40", day = 7), WATCH),
            ReadPoint(time("22:00", day = 7), time("06:30"), WATCH),
        )
        assertEquals(expected, evening.points)
    }

    @Test
    fun aSessionThatEndsAtTheStartAddsNothing() {
        val evening = sleepSession(
            time("21:00", day = 7), time("00:15"),
            stages = listOf(
                Stage(time("21:00", day = 7), time("23:00", day = 7), SleepSessionRecord.STAGE_TYPE_LIGHT),
                Stage(time("23:00", day = 7), time("00:15"), SleepSessionRecord.STAGE_TYPE_DEEP),
            ),
        )
        for (type in stageTypes) {
            assertEquals(type, emptyList<ReadPoint>(), read(type, time("00:15"), time("12:00"), listOf(evening)).points)
        }
        // The lookback finds it but leaves it out, as it leaves out the sessions on the page.
        val endsAfter = sleepSession(time("22:00", day = 7), time("00:15").plusMillis(1), packageName = DIARY)
        val onPage = sleepSession(time("23:00", day = 7), time("06:00"), packageName = WATCH)
        val kept = SleepLookback.keepLookbackSessions(
            listOf(evening, endsAfter, onPage), time("00:15"), setOf(onPage.metadata.id),
        )
        assertEquals(listOf(endsAfter), kept)
    }

    @Test
    fun onlyTheFirstPageLooksBackAndPageTokensAreUnchanged() {
        val afternoon = sleepSession(
            time("14:00"), time("14:30"),
            stages = listOf(Stage(time("14:00"), time("14:30"), SleepSessionRecord.STAGE_TYPE_LIGHT)),
            packageName = WATCH,
        )
        val light = read(HealthConstants.SLEEP_LIGHT, time("00:15"), time("23:00"), sessions + afternoon, pageSize = 1)
        // The night that began before the range comes first, as the oldest session.
        val firstPage = listOf(
            ReadPoint(time("00:30"), time("01:30"), WATCH),
            ReadPoint(time("02:10"), time("03:30"), WATCH),
            ReadPoint(time("06:00"), time("06:45"), DIARY),
        )
        assertEquals(listOf(firstPage, listOf(ReadPoint(time("14:00"), time("14:30"), WATCH))), light.pages)
        // The first page, its lookback, then the second page.
        assertEquals(listOf(null, null, "1"), requests.map { it.pageToken })
        assertEquals(listOf(time("00:15"), time("00:15", day = 7), time("00:15")), requests.ranges().map { it.first })
        // The tokens of a session read, which does not look back.
        val sessionRead =
            read(HealthConstants.SLEEP_SESSION, time("00:15"), time("23:00"), sessions + afternoon, pageSize = 1)
        assertEquals(listOf("v1:1:1", null), sessionRead.tokens)
        assertEquals(sessionRead.tokens, light.tokens)
    }

    @Test
    fun theLookbackReadsEveryPage() {
        // More short sessions than one read returns, then the night.
        val naps = List(SLEEP_MAX_RECORDS + 100) { i ->
            val start = time("00:15", day = 7).plus(Duration.ofMinutes(2L * i))
            val end = start.plusSeconds(60)
            sleepSession(start, end, listOf(Stage(start, end, SleepSessionRecord.STAGE_TYPE_DEEP)))
        }
        val deep = read(HealthConstants.SLEEP_DEEP, time("00:15"), time("12:00"), naps + night)
        assertEquals(listOf(ReadPoint(time("03:30"), time("04:30"), WATCH)), deep.points)
        assertEquals(listOf(null, null, "$SLEEP_MAX_RECORDS"), requests.map { it.pageToken })
    }

    @Test
    fun recordingMethodsAreFilteredInSessionsThatBeganBefore() {
        val withoutManual = read(
            HealthConstants.SLEEP_AWAKE, time("00:15"), time("12:00"),
            recordingMethodsToFilter = listOf(Metadata.RECORDING_METHOD_MANUAL_ENTRY),
        )
        assertEquals(listOf(ReadPoint(time("02:00"), time("02:10"), WATCH)), withoutManual.points)
        val withoutAutomatic = read(
            HealthConstants.SLEEP_AWAKE, time("00:15"), time("12:00"),
            recordingMethodsToFilter = listOf(Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED),
        )
        assertEquals(listOf(ReadPoint(time("06:45"), time("07:30"), DIARY)), withoutAutomatic.points)
    }

    @Test
    fun getDataReturnsWhatThePagesReturn() {
        for (type in sleepTypes) {
            val pages = read(type, time("00:15"), time("12:00")).points
            assertEquals(type, pages, reads.legacy(type, time("00:15"), time("12:00"), sessions))
        }
    }

    private companion object {
        const val WATCH = "com.example.watch"
        const val DIARY = "com.example.diary"
    }
}
