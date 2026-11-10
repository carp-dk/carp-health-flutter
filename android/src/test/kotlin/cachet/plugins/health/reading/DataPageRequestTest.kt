package cachet.plugins.health.reading

import androidx.health.connect.client.records.CyclingPedalingCadenceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.PowerRecord
import androidx.health.connect.client.records.SleepSessionRecord
import cachet.plugins.health.HealthErrors
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DataPageRequestTest {
    private fun call(vararg arguments: Pair<String, Any?>) = MethodCall("getDataPage", hashMapOf(*arguments))

    private fun request(dataType: String, pageSize: Int = 20000) = DataPageRequest.from(
        call(
            "dataTypeKey" to dataType,
            "startTime" to 1_700_000_000_000L,
            "endTime" to 1_700_000_600_000L,
            "pageSize" to pageSize,
        )
    )

    @Test
    fun readsNumbersSentAsIntegerOrLong() {
        // The codec sends ints that fit in 32 bits as Integer, so argument<Long> would throw.
        val request = DataPageRequest.from(
            call("dataTypeKey" to "STEPS", "startTime" to 0, "endTime" to 1_700_000_600_000L, "pageSize" to 7)
        )
        assertEquals(Instant.EPOCH, request.startTime)
        assertEquals(Instant.ofEpochMilli(1_700_000_600_000L), request.endTime)
        assertEquals(7, request.pageSize)
    }

    @Test
    fun readsAllArguments() {
        val request = DataPageRequest.from(
            call(
                "dataTypeKey" to "WEIGHT",
                "dataUnitKey" to "POUND",
                "startTime" to 1_700_000_000_000L,
                "endTime" to 1_700_000_600_000L,
                "recordingMethodsToFilter" to listOf(3, 2L),
                "pageSize" to 100,
                "pageToken" to "v1:16:12345",
                "newestFirst" to true,
            )
        )
        assertEquals("WEIGHT", request.dataType)
        assertEquals("POUND", request.dataUnit)
        assertEquals(listOf(3, 2), request.recordingMethodsToFilter)
        assertEquals(100, request.pageSize)
        val token = request.token!!
        assertEquals(16, token.records)
        assertEquals("12345", token.healthConnectToken)
    }

    @Test
    fun optionalArgumentsHaveDefaults() {
        val request = DataPageRequest.from(call("dataTypeKey" to "STEPS", "startTime" to 0, "endTime" to 1))
        assertNull(request.dataUnit)
        assertEquals(emptyList<Int>(), request.recordingMethodsToFilter)
        assertEquals(20000, request.pageSize)
        assertNull(request.token)
        assertNull(request.limit)
    }

    @Test
    fun clampsPageSize() {
        for ((sent, used) in listOf(0 to 1, -5 to 1, 50000 to 50000, 100000 to 50000, 3_000_000_000L to 50000)) {
            val arguments = arrayOf("dataTypeKey" to "STEPS", "startTime" to 0, "endTime" to 1, "pageSize" to sent)
            assertEquals("$sent", used, DataPageRequest.from(call(*arguments)).pageSize)
        }
    }

    @Test
    fun readsAndClampsTheLimit() {
        // 0 or less means no limit, and Health Connect returns at most 5000 records per request.
        val sent = listOf<Any?>(null, 0, -3, 1, 7, 5000, 5001, 3_000_000_000L)
        val used = listOf(null, null, null, 1, 7, 5000, 5000, 5000)
        for ((limit, expected) in sent.zip(used)) {
            val arguments = arrayOf("dataTypeKey" to "WEIGHT", "startTime" to 0, "endTime" to 1, "limit" to limit)
            assertEquals("$limit", expected, DataPageRequest.from(call(*arguments)).limit)
        }
    }

    @Test
    fun badArgumentsAreInvalidArguments() {
        val valid = arrayOf("dataTypeKey" to "STEPS", "startTime" to 0, "endTime" to 1)
        val bad = listOf(
            call("startTime" to 0, "endTime" to 1),
            call("dataTypeKey" to "STEPS", "endTime" to 1),
            call("dataTypeKey" to "STEPS", "startTime" to "0", "endTime" to 1),
            call("dataTypeKey" to 5, "startTime" to 0, "endTime" to 1),
            call(*valid, "pageSize" to "big"),
            call(*valid, "pageToken" to "garbage"),
            call(*valid, "pageToken" to mapOf("hc" to "1", "records" to 5)),
            call(*valid, "recordingMethodsToFilter" to listOf("MANUAL")),
            call(*valid, "recordingMethodsToFilter" to 3),
            call(*valid, "limit" to "1"),
            MethodCall("getDataPage", "STEPS"),
        )
        for (badCall in bad) {
            val error = assertThrows("${badCall.arguments}", IllegalArgumentException::class.java) {
                DataPageRequest.from(badCall)
            }
            assertEquals(HealthErrors.INVALID_ARGUMENT, HealthErrors.codeFor(error, null))
        }
    }

    @Test
    fun typesHealthConnectDoesNotHaveAreNotSupported() {
        for (dataType in listOf("BODY_MASS_INDEX", "ELECTROCARDIOGRAM", "NOT_A_TYPE")) {
            val error = assertThrows(dataType, UnsupportedOperationException::class.java) { request(dataType) }
            assertEquals(HealthErrors.NOT_SUPPORTED, HealthErrors.codeFor(error, null))
        }
    }

    @Test
    fun resolvesRecordTypes() {
        assertEquals(ExerciseSessionRecord::class, request("WORKOUT_ROUTE").recordType)
        assertEquals(ExerciseSessionRecord::class, request("WORKOUT").recordType)
        assertEquals(SleepSessionRecord::class, request("SLEEP_DEEP").recordType)
        assertEquals(HeartRateRecord::class, request("HEART_RATE").recordType)
        assertEquals(PowerRecord::class, request("POWER").recordType)
        assertEquals(CyclingPedalingCadenceRecord::class, request("CYCLING_CADENCE").recordType)
        assertTrue(request("HEART_RATE").isSeries)
        assertTrue(request("SPEED").isSeries)
        assertTrue(request("POWER").isSeries)
        assertTrue(request("CYCLING_CADENCE").isSeries)
        assertTrue(request("SKIN_TEMPERATURE").isSeries)
        assertFalse(request("STEPS").isSeries)
        assertFalse(request("RESTING_HEART_RATE").isSeries)
    }

    @Test
    fun firstPageRecordsPerType() {
        assertEquals(1, request("SPEED").firstRecords(34))
        assertEquals(5, request("SPEED").firstRecords(33))
        assertEquals(1, request("POWER").firstRecords(34))
        assertEquals(5, request("CYCLING_CADENCE").firstRecords(33))
        assertEquals(1, request("SKIN_TEMPERATURE", pageSize = 1).firstRecords(36))
        assertEquals(5000, request("STEPS").firstRecords(34))
        assertEquals(100, request("STEPS", pageSize = 100).firstRecords(34))
        assertEquals(500, request("SLEEP_SESSION").firstRecords(34))
        assertEquals(100, request("SLEEP_REM", pageSize = 100).firstRecords(34))
        assertEquals(20, request("WORKOUT").firstRecords(34))
        assertEquals(7, request("WORKOUT", pageSize = 7).firstRecords(34))
        assertEquals(5, request("WORKOUT_ROUTE").firstRecords(34))
    }

    @Test
    fun heartRateTakesSliceTokens() {
        fun heartRate(token: String?) = DataPageRequest.from(
            call("dataTypeKey" to "HEART_RATE", "startTime" to 0, "endTime" to 1_000_000, "pageToken" to token)
        )
        assertTrue(heartRate(null).isSliced)
        assertTrue(heartRate(null).isFirstPage)
        val request = heartRate("v2:500:100:-:-:-:-")
        assertNull(request.token)
        assertEquals(500L, request.sliceToken!!.cursor)
        assertFalse(request.isFirstPage)
        // A token of the other kind is malformed, as is any token sent with the wrong type.
        assertThrows(IllegalArgumentException::class.java) { heartRate("v1:16:12345") }
        assertThrows(IllegalArgumentException::class.java) {
            DataPageRequest.from(call("dataTypeKey" to "SPEED", "startTime" to 0, "endTime" to 1, "pageToken" to "v2:0:1:-:-:-:-"))
        }
        assertFalse(request("SPEED").isSliced)
    }
}
