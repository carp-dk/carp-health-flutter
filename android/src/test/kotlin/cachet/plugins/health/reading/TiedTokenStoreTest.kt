package cachet.plugins.health.reading

import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import java.time.Instant
import kotlin.reflect.KClass
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * The fake of Health Connect's page tokens ([tiedTokenStore]) returns what the devices returned for client-made
 * tokens at the start time of several records, one record a request (Android 15, module 350820300; the steps
 * also on Android 16 and 17). The plugin sends no such token ([readPastTies]).
 */
class TiedTokenStoreTest {
    private val eight = Instant.parse("2016-11-02T08:00:00Z")
    private val range = TimeRangeFilter.between(eight.minusSeconds(3600), eight.plusSeconds(7200))

    /** The record that a request of one record at (08:00, [offset]) returns from [records], and the next token. */
    private fun <T : Record> at(records: List<T>, type: KClass<T>, offset: Int): Pair<T, String?> {
        val token = HealthConnectPosition(false, eight.toEpochMilli(), offset).encode()
        val response = readByPosition(records, ReadRecordsRequest(type, range, emptySet(), true, 1, token))
        @Suppress("UNCHECKED_CAST")
        return response.records.single() as T to response.pageToken
    }

    private fun token(offset: Int) = HealthConnectPosition(false, eight.toEpochMilli(), offset).encode()

    @Test
    fun healthConnectsOwnTokensReturnTheSameStepsForever() {
        // Five records at 08:00 and one at 08:10: after the first page, the second record with the same token.
        val steps = tiedSteps(eight, 5) + tiedSteps(eight.plusSeconds(600), 1, first = 5)
        val first = readByPosition(steps, ReadRecordsRequest(StepsRecord::class, range, emptySet(), true, 1, null))
        assertEquals(listOf("s0") to token(1), first.records.map { it.metadata.id } to first.pageToken)
        repeat(3) {
            val (record, next) = at(steps, StepsRecord::class, 1)
            assertEquals("s1" to token(1), record.metadata.id to next)
        }
        // At pageSize 2, records 3 and 4 again and again.
        val request = ReadRecordsRequest(StepsRecord::class, range, emptySet(), true, 2, token(2))
        val again = readByPosition(steps, request)
        assertEquals(listOf("s2", "s3") to token(2), again.records.map { it.metadata.id } to again.pageToken)
    }

    @Test
    fun anOffsetSkipsSamplesOfASpeedRecord() {
        val speeds = tiedSpeeds(eight, 4)
        fun samples(offset: Int) =
            at(speeds, SpeedRecord::class, offset).first.let { it.metadata.id to it.samples.size }
        assertEquals("v0" to 2, samples(1))
        assertEquals("v0" to 1, samples(2))
        assertEquals(listOf("v1", "v2", "v3").map { it to 3 }, listOf(3, 6, 9).map(::samples))
    }

    @Test
    fun anOffsetSkipsStagesOfASleepSession() {
        val nights = tiedNights(eight, 3)
        fun stages(offset: Int) =
            at(nights, SleepSessionRecord::class, offset).first.let { it.metadata.id to it.stages.map { s -> s.stage } }
        val awake = SleepSessionRecord.STAGE_TYPE_AWAKE
        val light = SleepSessionRecord.STAGE_TYPE_LIGHT
        val deep = SleepSessionRecord.STAGE_TYPE_DEEP
        assertEquals("n0" to listOf(light, deep), stages(1))
        assertEquals("n0" to listOf(deep), stages(2))
        assertEquals("n1" to listOf(awake, light, deep), stages(3))
        assertEquals("n2" to listOf(awake, light, deep), stages(6))
    }

    @Test
    fun anOffsetSkipsLapsAndSegmentsOfASwim() {
        val swims = tiedSwims(eight, 3)
        fun laps(offset: Int) =
            at(swims, ExerciseSessionRecord::class, offset).first.let { it.metadata.id to it.laps.size }
        assertEquals(listOf("w0" to 2, "w0" to 1, "w0" to 1), listOf(1, 2, 3).map(::laps))
        assertEquals(listOf("w1" to 2, "w2" to 2), listOf(4, 8).map(::laps))
    }
}
