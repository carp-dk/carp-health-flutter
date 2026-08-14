package cachet.plugins.health.write

import cachet.plugins.health.metadata.HealthMetadataFactory
import cachet.plugins.health.write.requests.WriteRequestDecoder
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WriteRequestDecoderTest {
    private val decoder = WriteRequestDecoder()

    @Test
    fun genericRequestConvertsClientRecordVersionToLong() {
        val request = decoder.generic(
            MethodCall(
                "writeData",
                mapOf(
                    "dataTypeKey" to "WEIGHT",
                    "startTime" to 1000L,
                    "endTime" to 2000L,
                    "value" to 80,
                    "recordingMethod" to 1,
                    "clientRecordId" to "client-1",
                    "clientRecordVersion" to 3.0,
                )
            )
        )

        assertEquals("WEIGHT", request.dataTypeKey)
        assertEquals(80.0, request.value, 0.0)
        assertEquals("client-1", request.metadata.clientRecordId)
        assertEquals(3L, request.metadata.clientRecordVersion)
    }

    @Test
    fun bloodPressureAcceptsIntegerPayloadFromFlutter() {
        val request = decoder.bloodPressure(
            MethodCall(
                "writeBloodPressure",
                mapOf(
                    "systolic" to 120,
                    "diastolic" to 80,
                    "startTime" to 1000L,
                    "recordingMethod" to 2,
                )
            )
        )

        assertEquals(120.0, request.systolic, 0.0)
        assertEquals(80.0, request.diastolic, 0.0)
        assertEquals(HealthMetadataFactory.RECORDING_METHOD_AUTOMATIC, request.metadata.recordingMethod)
    }

    @Test
    fun nutritionAcceptsDartThiaminKey() {
        val request = decoder.nutrition(
            MethodCall(
                "writeMeal",
                mapOf(
                    "start_time" to 1000L,
                    "end_time" to 2000L,
                    "meal_type" to "DINNER",
                    "b1_thiamin" to 1.5,
                )
            )
        )

        assertEquals("DINNER", request.mealType)
        assertEquals(1.5, request.nutrients.b1Thiamin!!, 0.0)
        assertEquals(HealthMetadataFactory.RECORDING_METHOD_MANUAL, request.metadata.recordingMethod)
    }

    @Test
    fun routeInsertDefaultsMissingLocationsToEmptyList() {
        val request = decoder.routeInsert(
            MethodCall("insertWorkoutRouteData", mapOf("builderId" to "builder-1"))
        )

        assertEquals("builder-1", request.builderId)
        assertEquals(emptyList<Any>(), request.locations)
    }

    @Test
    fun optionalMetadataFieldsRemainNullWhenAbsent() {
        val request = decoder.activityIntensity(
            MethodCall(
                "writeActivityIntensity",
                mapOf(
                    "intensityType" to 1,
                    "startTime" to 1000L,
                    "endTime" to 2000L,
                    "recordingMethod" to 3,
                )
            )
        )

        assertEquals(HealthMetadataFactory.RECORDING_METHOD_ACTIVE, request.metadata.recordingMethod)
        assertNull(request.metadata.clientRecordId)
        assertNull(request.metadata.clientRecordVersion)
    }
}
