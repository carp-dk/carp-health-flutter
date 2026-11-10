package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthRecordingFilter
import cachet.plugins.health.RecordingResult
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.joinAll
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull

/** A data point that a read replied, as its times and app. */
internal data class ReadPoint(val from: Instant, val to: Instant, val source: String)

/** The pages of a getDataPage read, and the token each page replied. */
internal class PageRead(val pages: List<List<ReadPoint>>, val tokens: List<String?>) {
    val points get() = pages.flatten()
}

/**
 * Reads sleep types with getDataPage and getData while Health Connect holds the sessions given
 * ([fakeSleepStore]), and adds each Health Connect read request to [requests].
 */
internal class SleepReads {
    val requests = mutableListOf<ReadRecordsRequest<*>>()
    private val job = SupervisorJob()

    /** Reads [dataType] in [from, to) page by page, sending each token back as Dart does. */
    fun pages(
        dataType: String,
        from: Instant,
        to: Instant,
        sessions: List<SleepSessionRecord>,
        pageSize: Int = DEFAULT_PAGE_SIZE,
        recordingMethodsToFilter: List<Int> = emptyList(),
    ): PageRead {
        val client = fakeSleepStore(sessions, requests)
        val reader = DataPageReader(
            client, CoroutineScope(job), HealthDataConverter(), converter(client),
            WorkoutRoutes(HealthRecordingFilter()), SeriesLookback(client), SleepLookback(client),
            HeartRatePageReader(FakeHeartRateSource(emptyList()), 37),
        )
        val pages = mutableListOf<List<ReadPoint>>()
        val tokens = mutableListOf<String?>()
        var token: String? = null
        do {
            val arguments = hashMapOf(
                "dataTypeKey" to dataType, "startTime" to from.toEpochMilli(), "endTime" to to.toEpochMilli(),
                "recordingMethodsToFilter" to recordingMethodsToFilter, "pageSize" to pageSize, "pageToken" to token,
            )
            val page = reply { reader.getDataPage(MethodCall("getDataPage", arguments), it) } as Map<*, *>
            pages += points(page["data"])
            token = page["nextPageToken"] as String?
            tokens += token
        } while (token != null)
        return PageRead(pages, tokens)
    }

    /** Reads [dataType] in [from, to) with the deprecated getData, in one reply. */
    fun legacy(dataType: String, from: Instant, to: Instant, sessions: List<SleepSessionRecord>): List<ReadPoint> {
        val client = fakeSleepStore(sessions, requests)
        val reader = LegacyDataReader(
            client, CoroutineScope(job), converter(client), WorkoutRoutes(HealthRecordingFilter()),
            SeriesLookback(client), SleepLookback(client),
        )
        val arguments = hashMapOf(
            "dataTypeKey" to dataType, "startTime" to from.toEpochMilli(), "endTime" to to.toEpochMilli(),
            "recordingMethodsToFilter" to emptyList<Int>(),
        )
        return points(reply { reader.getData(MethodCall("getData", arguments), it) })
    }

    private fun converter(client: HealthConnectClient): RecordConverter {
        val dataConverter = HealthDataConverter()
        val recordingFilter = HealthRecordingFilter()
        val sleep = SleepConverter(dataConverter, recordingFilter)
        return RecordConverter(dataConverter, recordingFilter, WorkoutConverter(client, recordingFilter), sleep)
    }

    // The one reply that [send] gets, once the reader's coroutine is done.
    private fun reply(send: (RecordingResult) -> Unit): Any? {
        val result = RecordingResult()
        send(result)
        runBlocking { job.children.toList().joinAll() }
        assertEquals(1, result.replies)
        assertNull(result.message, result.code)
        return result.value
    }

    private fun points(data: Any?): List<ReadPoint> = (data as List<*>).map { point ->
        point as Map<*, *>
        val from = Instant.ofEpochMilli(point["date_from"] as Long)
        ReadPoint(from, Instant.ofEpochMilli(point["date_to"] as Long), point["source_name"] as String)
    }
}
