package cachet.plugins.health.reading

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.units.Velocity
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthErrors
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Reads of a type the app may write but not read: Health Connect returns the app's own records when
 * every call asks for them only ([ReadAccess.OWN]). The fake store throws, as Android 14 QPR2 and
 * later do, for a call without that filter, which the readers (on Android 17 unless said otherwise)
 * report as an error. Sleep stages and workouts: [OwnSessionReadsTest]; heart rate: [OwnHeartRateReadsTest].
 */
class OwnRecordReadsTest {
    private val start = Instant.parse("2026-11-08T09:00:00Z")
    private val end = start.plusSeconds(7200)
    private val requests = mutableListOf<ReadRecordsRequest<*>>()
    private val writeSpeed = setOf(HealthPermission.getWritePermission(SpeedRecord::class))

    // This app's records from 08:50 (reaching into the read), 09:30 and 10:00; the other app's from
    // 08:40, 09:10 and 10:30. Each has a sample a minute for 30 minutes.
    private val speeds = listOf(
        speed(OWN_PACKAGE, "own-early", -600), speed(OWN_PACKAGE, "own1", 1800), speed(OWN_PACKAGE, "own2", 3600),
        speed(OTHER, "other-early", -1200), speed(OTHER, "other1", 600), speed(OTHER, "other-late", 5400),
    )

    @Test
    fun aSeriesReadWithOnlyWritePermissionReadsTheAppsOwnRecordsOnEveryPage() {
        val client = fakeRecordStore(SpeedRecord::class, speeds, requests, writeSpeed)
        val replies = PageReplies(client).read(HealthConstants.SPEED, start, end)

        assertNull(replies.last().error)
        // One record on the first page, with the one that began before the read, then the rest.
        assertEquals(listOf(20 + 30, 30), replies.map { it.points.size })
        assertTrue(replies.flatMap { it.points }.all { it.source == OWN_PACKAGE })
        // Every page says that the points are the app's own: the read permission is missing.
        assertEquals(listOf(true, true), replies.map { it.permissionDenied })
        assertTrue(replies.first().token!!.startsWith("o1:"))
        // The read, the lookback before it, and the second page: each asks for the app's records only.
        assertEquals(3, requests.size)
        assertEquals(start, requests[1].timeRangeFilter.endTime)
        assertTrue(requests.allOwn())
    }

    @Test
    fun aSeriesReadWithReadPermissionReadsEveryAppsRecordsUnflagged() {
        val granted = setOf(HealthPermission.getReadPermission(SpeedRecord::class)) + writeSpeed
        val client = fakeRecordStore(SpeedRecord::class, speeds, requests, granted)
        val replies = PageReplies(client).read(HealthConstants.SPEED, start, end)

        assertNull(replies.last().error)
        assertEquals(setOf(OWN_PACKAGE, OTHER), replies.flatMap { it.points }.map { it.source }.toSet())
        assertTrue(replies.all { it.permissionDenied == null })
        assertTrue(replies.dropLast(1).all { it.token!!.startsWith("v1:") })
        assertTrue(requests.all { it.dataOriginFilter.isEmpty() })
    }

    @Test
    fun withoutReadOrWritePermissionTheFirstPageIsEmptyLastAndFlagged() {
        val client = fakeRecordStore(SpeedRecord::class, speeds, requests, granted = emptySet())
        val reply = PageReplies(client).read(HealthConstants.SPEED, start, end).single()

        assertEquals(emptyList<ReadPoint>(), reply.points)
        assertNull(reply.token)
        assertEquals(true, reply.permissionDenied)
        assertEquals(emptyList<ReadPoint>(), PageReplies(client).legacy(HealthConstants.SPEED, start, end))
        assertTrue(requests.isEmpty())
    }

    @Test
    fun aLimitedReadWithOnlyWritePermissionReadsTheAppsNewestRecords() {
        val client = fakeRecordStore(SpeedRecord::class, speeds, requests, writeSpeed)
        val replies = PageReplies(client).read(HealthConstants.SPEED, start, end, pageSize = 30, limit = 30)

        // The other app's record that starts last is not the app's.
        val reply = replies.single()
        assertEquals(30, reply.points.size)
        assertEquals(start.plusSeconds(3600), reply.points.first().from)
        assertEquals(true, reply.permissionDenied)
        val legacy = PageReplies(client).legacy(HealthConstants.SPEED, start, end, limit = 1)
        assertEquals(reply.points, legacy)
        assertEquals(2, requests.size)
        assertTrue(requests.all { !it.ascendingOrder })
        assertTrue(requests.allOwn())
    }

    @Test
    fun getDataWithOnlyWritePermissionReadsTheAppsOwnRecords() {
        val client = fakeRecordStore(SpeedRecord::class, speeds, requests, writeSpeed)
        val points = PageReplies(client).legacy(HealthConstants.SPEED, start, end)

        assertEquals(20 + 30 + 30, points.size)
        assertTrue(points.all { it.source == OWN_PACKAGE })
        // The read and its lookback.
        assertEquals(2, requests.size)
        assertTrue(requests.allOwn())
    }

    @Test
    fun theHealthConnectApkRefusingARead() {
        // The Health Connect APK (Android 13 and lower) is closed source: say it refuses the second page.
        val refused = { request: ReadRecordsRequest<*> ->
            SecurityException("Refused").takeIf { request.pageToken != null }
        }
        val client = fakeRecordStore(SpeedRecord::class, speeds, requests, writeSpeed, refused)
        val replies = PageReplies(client, sdkInt = 33).read(HealthConstants.SPEED, start, end, pageSize = 3600)

        // The refused page is replied as without permission: empty, last, and flagged.
        assertEquals(listOf(50, 0), replies.map { it.points.size })
        assertEquals(listOf(true, true), replies.map { it.permissionDenied })
        assertNull(replies.last().token)
        assertNull(replies.last().error)

        // From Android 14 on, Health Connect accepts the read, so a refusal is an error.
        val failing = fakeRecordStore(SpeedRecord::class, speeds, requests, writeSpeed) { SecurityException("Refused") }
        val error = PageReplies(failing, sdkInt = 34).read(HealthConstants.SPEED, start, end).single().error
        assertEquals(HealthErrors.PERMISSION_DENIED, error)
        // As it is with read permission, on any version.
        val granted = setOf(HealthPermission.getReadPermission(SpeedRecord::class))
        val withRead = fakeRecordStore(SpeedRecord::class, speeds, requests, granted) { SecurityException("Revoked") }
        val readError = PageReplies(withRead, sdkInt = 33).read(HealthConstants.SPEED, start, end).single().error
        assertEquals(HealthErrors.PERMISSION_DENIED, readError)
    }

    /** A speed record of [packageName], 30 minutes from [offset] seconds after 09:00, with a sample a minute. */
    private fun speed(packageName: String, id: String, offset: Long): SpeedRecord {
        val from = start.plusSeconds(offset)
        val samples = (0 until 30).map { SpeedRecord.Sample(from.plusSeconds(60L * it), Velocity.metersPerSecond(2.0)) }
        return SpeedRecord(from, null, from.plusSeconds(1800), null, samples, writtenBy(packageName, id))
    }

    private companion object {
        const val OTHER = "com.example.other"
    }
}
