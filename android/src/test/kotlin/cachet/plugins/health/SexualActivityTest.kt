package cachet.plugins.health

import android.content.ContextWrapper
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.changes.UpsertionChange
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SexualActivityRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.response.ChangesResponse
import androidx.health.connect.client.response.InsertRecordsResponse
import cachet.plugins.health.permissions.permissionsFor
import cachet.plugins.health.reading.fakeHealthConnect
import cachet.plugins.health.reading.pagingTimeMillis
import cachet.plugins.health.writing.SexualActivityWriter
import cachet.plugins.health.writing.sexualActivityRecord
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** SEXUAL_ACTIVITY is Health Connect's SexualActivityRecord: an instant event with protection status. */
class SexualActivityTest {
    private val time = Instant.parse("2026-11-19T10:00:00Z")
    private val start = time.toEpochMilli()
    private val record = SexualActivityRecord(
        time = time,
        zoneOffset = null,
        protectionUsed = SexualActivityRecord.PROTECTION_USED_PROTECTED,
        metadata = Metadata.manualEntry(),
    )

    @Test
    fun recordsAreReadAsOneDataPointAtTheirTime() {
        val converter = HealthDataConverter()
        val cases = listOf(
            SexualActivityRecord.PROTECTION_USED_UNKNOWN,
            SexualActivityRecord.PROTECTION_USED_PROTECTED,
            SexualActivityRecord.PROTECTION_USED_UNPROTECTED,
        )
        for (protection in cases) {
            val sample = SexualActivityRecord(
                time = time,
                zoneOffset = null,
                protectionUsed = protection,
                metadata = Metadata.manualEntry(),
            )
            val point = converter.convertRecord(sample, HealthConstants.SEXUAL_ACTIVITY).single()
            assertEquals(protection, point["value"])
            assertEquals(start, point["date_from"])
            assertEquals(start, point["date_to"])
            assertEquals(1, converter.sampleCount(sample))
        }
        assertFalse(SexualActivityRecord::class in HealthDataConverter.seriesTypes)
    }

    @Test
    fun protectionBooleanMapsToHealthConnectConstants() {
        val metadata = Metadata.manualEntry(clientRecordId = "sa-1", clientRecordVersion = 2)

        val protectedRecord = sexualActivityRecord(true, start, metadata)
        assertEquals(time, protectedRecord.time)
        assertEquals(SexualActivityRecord.PROTECTION_USED_PROTECTED, protectedRecord.protectionUsed)
        assertEquals("sa-1", protectedRecord.metadata.clientRecordId)
        assertEquals(2L, protectedRecord.metadata.clientRecordVersion)

        val unprotectedRecord = sexualActivityRecord(false, start, metadata)
        assertEquals(SexualActivityRecord.PROTECTION_USED_UNPROTECTED, unprotectedRecord.protectionUsed)

        val unknownRecord = sexualActivityRecord(null, start, metadata)
        assertEquals(SexualActivityRecord.PROTECTION_USED_UNKNOWN, unknownRecord.protectionUsed)
    }

    @Test
    fun writerInsertsRecordAndRepliesSuccess() {
        val inserted = mutableListOf<Record>()
        val client = fakeHealthConnect { method, args ->
            check(method == "insertRecords") { "Unexpected call of $method" }
            @Suppress("UNCHECKED_CAST")
            inserted.addAll(args.single() as List<Record>)
            InsertRecordsResponse(listOf("id-1"))
        }
        val writer = SexualActivityWriter(client, CoroutineScope(Dispatchers.Unconfined))
        val reply = RecordingResult()
        val call = MethodCall(
            "writeSexualActivity",
            hashMapOf(
                "protectionUsed" to false,
                "startTime" to start,
                "endTime" to start,
                "recordingMethod" to 3,
                "clientRecordId" to "client-sa",
                "clientRecordVersion" to 1.0,
            ),
        )

        writer.writeSexualActivity(call, reply)

        assertEquals(true, reply.value)
        val written = inserted.single() as SexualActivityRecord
        assertEquals(time, written.time)
        assertEquals(SexualActivityRecord.PROTECTION_USED_UNPROTECTED, written.protectionUsed)
        assertEquals("client-sa", written.metadata.clientRecordId)
    }

    @Test
    fun writerRepliesFalseWhenInsertFails() {
        val client = fakeOf<HealthConnectClient> { method ->
            check(method == "insertRecords") { "Unexpected call of $method" }
            throw SecurityException("Permission denied")
        }
        val writer = SexualActivityWriter(client, CoroutineScope(Dispatchers.Unconfined))
        val reply = RecordingResult()
        val call = MethodCall(
            "writeSexualActivity",
            hashMapOf("protectionUsed" to null, "startTime" to start, "recordingMethod" to 2),
        )

        writer.writeSexualActivity(call, reply)

        assertEquals(false, reply.value)
    }

    @Test
    fun pagingTimeUsesRecordTime() {
        assertEquals(start, pagingTimeMillis(record))
    }

    @Test
    fun theTypeHasPermissionsOfItsOwn() {
        assertEquals(SexualActivityRecord::class, HealthConstants.mapToType[HealthConstants.SEXUAL_ACTIVITY])
        val call = MethodCall(
            "hasPermissions",
            hashMapOf("types" to arrayListOf(HealthConstants.SEXUAL_ACTIVITY), "permissions" to arrayListOf(2)),
        )
        assertEquals(
            listOf(
                "android.permission.health.READ_SEXUAL_ACTIVITY",
                "android.permission.health.WRITE_SEXUAL_ACTIVITY",
            ),
            permissionsFor(call),
        )
    }

    @Test
    fun theTypeHasNoIntervals() {
        assertFalse(HealthConstants.SEXUAL_ACTIVITY in HealthConstants.mapToAggregateMetric)
    }

    @Test
    fun aChangedRecordIsSentAsASexualActivityDataPoint() {
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
        job.complete()
        runBlocking { withTimeout(30_000) { job.join() } }
        val change = ((reply.value as Map<*, *>)["changes"] as List<*>).single() as Map<*, *>
        assertEquals(HealthConstants.SEXUAL_ACTIVITY, change["dataTypeKey"])
        assertEquals(SexualActivityRecord.PROTECTION_USED_PROTECTED, (change["dataPoint"] as Map<*, *>)["value"])
        assertTrue((change["dataPoint"] as Map<*, *>)["date_from"] == start)
    }
}
