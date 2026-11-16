package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.RecordingResult
import io.flutter.plugin.common.MethodCall
import java.time.Duration
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The plugin's own loops over Health Connect page tokens, over records that share a start time, from a Health
 * Connect whose tokens lose count of them ([tiedTokenStore]): each reads every record once, with one more
 * request for the records of a start time a page ends inside ([readPastTies]), never sends an offset, and ends.
 */
class TiedTokenLoopsTest {
    private val eight = Instant.parse("2016-11-02T08:00:00Z")
    private val requests = mutableListOf<ReadRecordsRequest<*>>()
    private val job = SupervisorJob()

    // 3,000 steps records a millisecond apart from 07:30, then [tied] at 08:00: the first request of 5,000 ends
    // inside those.
    private fun steps(tied: Int, packageName: String = "app.steps"): List<StepsRecord> {
        val times = List(3000) { eight.minusSeconds(1800).plusMillis(it.toLong()) } + List(tied) { eight }
        return times.mapIndexed { i, at ->
            StepsRecord(at, null, at.plusSeconds(60).plusMillis(i.toLong()), null, 1, writtenBy(packageName, "s$i"))
        }
    }

    private fun position(at: Instant) = HealthConnectPosition(false, at.toEpochMilli(), 0).encode()

    private fun assertOneTieRead(at: Instant) {
        val ranges = tieReads(requests).map { it.timeRangeFilter.startTime to it.timeRangeFilter.endTime }
        assertEquals(listOf(at to at.plusMillis(1)), ranges)
        assertTrue(noOffsets(requests))
    }

    @Test
    fun filteredTotalStepsCountEveryTieOnce() {
        val result = totalSteps(tiedTokenStore(steps(4000), requests = requests))

        assertEquals(7000L, result.value)
        assertEquals(listOf(null, null, position(eight.plusMillis(1))), requests.map { it.pageToken })
        assertOneTieRead(eight)
    }

    @Test
    fun aLoopThatCannotGoPastATokenEndsWithAnError() {
        // The Health Connect APK's tokens are not positions: the same one again cannot be moved past.
        val apk = fakeHealthConnect { method, args ->
            check(method == "readRecords") { "Unexpected call of $method" }
            requests.add(args.single() as ReadRecordsRequest<*>)
            // A read that went round would fail the test here instead of hanging it.
            if (requests.size > 10) throw AssertionError("The read went round")
            ReadRecordsResponse(tiedSteps(eight, 1), "CgYIARCAAQ")
        }
        val repeated = totalSteps(apk)
        assertEquals(HealthErrors.HEALTH_ERROR, repeated.code)
        assertTrue(repeated.message!!, "Health Connect returned the same page token twice" in repeated.message!!)
        assertEquals(listOf(null, "CgYIARCAAQ"), requests.map { it.pageToken })

        // 5,001 records at 08:00, more than one request holds.
        requests.clear()
        val group = totalSteps(tiedTokenStore(steps(HC_MAX_RECORDS + 1), requests = requests))
        assertEquals(HealthErrors.HEALTH_ERROR, group.code)
        assertTrue(group.message!!, "More than 5000 StepsRecord records start at" in group.message!!)
        assertEquals(listOf(HC_MAX_RECORDS, HC_MAX_RECORDS), requests.map { it.pageSize })
    }

    @Test
    fun aWorkoutsStepTotalCountsEveryTieOnce() {
        val run = ExerciseSessionRecord(
            startTime = eight.minusSeconds(1800), startZoneOffset = null, endTime = eight.plusSeconds(3600),
            endZoneOffset = null, metadata = writtenBy("app.watch", "run"),
            exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
        )
        val client = tiedTokenStore(steps(4000, "app.watch"), requests = requests)
        val data = mutableListOf<Map<String, Any?>>()
        val granted = setOf(HealthPermission.getReadPermission(StepsRecord::class))
        val converter = WorkoutConverter(client, HealthRecordingFilter(), OWN_PACKAGE)
        runBlocking { converter.handleWorkoutData(listOf(run), emptyList(), data, granted) }

        assertEquals(7000.0, data.single()["totalSteps"])
        assertEquals(listOf(null, null, position(eight.plusMillis(1))), requests.map { it.pageToken })
        assertOneTieRead(eight)
    }

    @Test
    fun sleepLookbacksAndIntervalsReadEveryTiedSessionOnce() {
        // More sessions at 07:30 (until after 08:30) than a request of 500 holds, read whole by one more.
        val half = eight.minusSeconds(1800)
        val nights = tiedNights(half, 1200)
        val client = tiedTokenStore(nights, requests = requests)
        val found = runBlocking { SleepLookback(client).readLookbackSessions(eight, emptySet(), emptySet()) }
        assertEquals(nights.map { it.metadata.id }, found.map { it.metadata.id })
        assertEquals(listOf(SLEEP_MAX_RECORDS, HC_MAX_RECORDS, SLEEP_MAX_RECORDS), requests.map { it.pageSize })
        assertEquals(listOf(null, null, position(half.plusMillis(1))), requests.map { it.pageToken })
        assertOneTieRead(half)

        requests.clear()
        val reader = SleepIntervalReader(client, HealthRecordingFilter())
        val until = half.plusSeconds(3600)
        val hour = Duration.ofHours(1)
        val buckets = runBlocking { reader.readIntervals(HealthConstants.SLEEP_LIGHT, half, until, hour, emptyList()) }
        // Light from 07:40 to 08:10, every night of it counted once.
        assertEquals(listOf(30.0), buckets.map { it["value"] })
        assertOneTieRead(half)
    }

    @Test
    fun theHeartRateLookbackFindsEveryTiedRecordOnce() {
        // Six records of another app that began an hour before the read, each of 10,000 samples: on the device,
        // round 4 found two of them. The look-back reads one record, and then all six in one more request.
        val tie = eight.toEpochMilli() - 3_600_000
        val tied = List(6) { heartRate("tie$it", tie, 10_000, end = tie + 10_000_000L + it, packageName = "app.other") }
        val client = tiedTokenStore(tied, fakeHeartRateStore(tied, counting = Counting.ANDROID_15), requests)
        val lookback = HeartRateLookback(HealthConnectHeartRateSource(client), sdkInt = 35)
        val found = runBlocking { lookback.find(eight.toEpochMilli(), 100, null, eight.toEpochMilli() + 3_600_000) }

        assertEquals(tied.map { it.metadata.id }, found.map { it.metadata.id })
        assertOneTieRead(Instant.ofEpochMilli(tie))
        // The slice that holds them: one record, then all six, then on past them.
        val slice = requests.filter { request ->
            val range = request.timeRangeFilter
            range.startTime!!.toEpochMilli() < tie && tie < range.endTime!!.toEpochMilli()
        }
        val past = HealthConnectPosition(false, tie + 1, 0).encode()
        assertEquals(listOf(1 to null, 2 to past), slice.map { it.pageSize to it.pageToken })
    }

    @Test
    fun aLookbackCountsItsRequestsForRecordsThatStartTogether() {
        // Twenty pairs of records that start together in the hours before the read, each pair a slice of its own:
        // the first request of every slice ends inside its pair, and one more reads both, which counts too.
        val start = eight.toEpochMilli()
        val pairs = (1..20).flatMap { hour ->
            val at = start - hour * 3_600_000L
            List(2) { heartRate("p$hour.$it", at, 10_001, stepMs = 1, end = at + 20_000L + it, packageName = "app.o") }
        }
        val calls = mutableListOf<HeartRateCall>()
        val client = tiedTokenStore(pairs, fakeHeartRateStore(pairs, calls, counting = Counting.ANDROID_15), requests)
        val lookback = HeartRateLookback(HealthConnectHeartRateSource(client), sdkInt = 35)
        val found = runBlocking { lookback.find(start, 100, null, start + 3_600_000) }

        assertTrue(found.isEmpty())
        assertTrue(tieReads(requests).isNotEmpty())
        assertTrue("${calls.size} + ${requests.size} calls", calls.size + requests.size <= MAX_LOOKBACK_CALLS + 1)
    }

    /** getTotalStepsInInterval from 07:00 to 09:00 of [client], without the actively recorded steps. */
    private fun totalSteps(client: HealthConnectClient): RecordingResult {
        val reader = TotalStepsReader(client, CoroutineScope(job), HealthRecordingFilter())
        val arguments = hashMapOf(
            "startTime" to eight.minusSeconds(3600).toEpochMilli(),
            "endTime" to eight.plusSeconds(3600).toEpochMilli(),
            "recordingMethodsToFilter" to listOf(Metadata.RECORDING_METHOD_ACTIVELY_RECORDED),
        )
        val result = RecordingResult()
        reader.getTotalStepsInInterval(MethodCall("getTotalStepsInInterval", arguments), result)
        runBlocking { job.children.toList().joinAll() }
        assertEquals(1, result.replies)
        return result
    }
}
