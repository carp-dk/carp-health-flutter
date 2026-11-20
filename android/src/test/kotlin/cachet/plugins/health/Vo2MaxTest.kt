package cachet.plugins.health

import android.content.ContextWrapper
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.response.ChangesResponse
import cachet.plugins.health.permissions.permissionsFor
import cachet.plugins.health.writing.valueRecord
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test

/** VO2_MAX is Health Connect's Vo2MaxRecord: one value at one time, in mL/(kg·min). */
class Vo2MaxTest {
    private val time = Instant.parse("2026-11-08T10:00:00Z")
    private val start = time.toEpochMilli()
    private val record = Vo2MaxRecord(
        time = time,
        zoneOffset = null,
        vo2MillilitersPerMinuteKilogram = 52.5,
        metadata = Metadata.manualEntry(),
    )

    @Test
    fun aRecordIsReadAsOneDataPointAtItsTime() {
        val converter = HealthDataConverter()
        val point = converter.convertRecord(record, HealthConstants.VO2_MAX).single()
        assertEquals(52.5, point["value"])
        assertEquals(start, point["date_from"])
        assertEquals(start, point["date_to"])
        assertEquals(1, converter.sampleCount(record))
        assertFalse(Vo2MaxRecord::class in HealthDataConverter.seriesTypes)
    }

    @Test
    fun aValueIsWrittenAtItsStartTime() {
        val written = valueRecord(HealthConstants.VO2_MAX, start, start + 3_600_000, 42.5, Metadata.manualEntry())
        assertEquals(Vo2MaxRecord::class, written!!::class)
        written as Vo2MaxRecord
        assertEquals(time, written.time)
        assertEquals(42.5, written.vo2MillilitersPerMinuteKilogram, 1e-9)
        assertEquals(Vo2MaxRecord.MEASUREMENT_METHOD_OTHER, written.measurementMethod)
    }

    @Test
    fun valuesOutside0To100AreRejected() {
        // ValueWriter replies false to writeData for a value Health Connect rejects.
        for (value in listOf(-1.0, 100.5)) {
            assertThrows(IllegalArgumentException::class.java) {
                valueRecord(HealthConstants.VO2_MAX, start, start, value, Metadata.manualEntry())
            }
        }
    }

    @Test
    fun theTypeHasPermissionsOfItsOwn() {
        val call = MethodCall(
            "hasPermissions",
            hashMapOf("types" to arrayListOf(HealthConstants.VO2_MAX), "permissions" to arrayListOf(2)),
        )
        assertEquals(
            listOf("android.permission.health.READ_VO2_MAX", "android.permission.health.WRITE_VO2_MAX"),
            permissionsFor(call),
        )
    }

    @Test
    fun theTypeHasNoIntervals() {
        // Health Connect has no VO2 max aggregate, so getIntervalData returns no data points for it.
        assertFalse(HealthConstants.VO2_MAX in HealthConstants.mapToAggregateMetric)
    }

    @Test
    fun aChangedRecordIsSentAsAVo2MaxDataPoint() {
        val client = fakeOf<HealthConnectClient> { method ->
            check(method == "getChanges") { "Unexpected call of $method" }
            ChangesResponse(listOf(UpsertionChange(record)), "next", hasMore = false, changesTokenExpired = false)
        }
        val job = Job()
        val changes = HealthDataChanges(
            client, CoroutineScope(Dispatchers.Unconfined + job), ContextWrapper(null), HealthDataConverter(),
        )
        val reply = RecordingResult()
        changes.getChanges(MethodCall("getChanges", hashMapOf("changesToken" to "token")), reply)
        // getChanges replies from a coroutine on another thread: wait until that has ended.
        job.complete()
        runBlocking { withTimeout(30_000) { job.join() } }
        val change = ((reply.value as Map<*, *>)["changes"] as List<*>).single() as Map<*, *>
        assertEquals(HealthConstants.VO2_MAX, change["dataTypeKey"])
        assertEquals(52.5, (change["dataPoint"] as Map<*, *>)["value"])
    }
}
