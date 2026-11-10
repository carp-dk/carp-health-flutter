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
 * ([fakeSleepStore]), or any type from a client given, and adds each Health Connect read request
 * of the sleep store to [requests].
 */
internal class SleepReads {
    val requests = mutableListOf<ReadRecordsRequest<*>>()
    private val job = SupervisorJob()

    /** Reads [dataType] in [from, to) page by page while Health Connect holds [sessions]. */
    fun pages(
        dataType: String,
        from: Instant,
        to: Instant,
        sessions: List<SleepSessionRecord>,
        pageSize: Int = DEFAULT_PAGE_SIZE,
        recordingMethodsToFilter: List<Int> = emptyList(),
        limit: Int? = null,
    ): PageRead =
        pages(dataType, from, to, fakeSleepStore(sessions, requests), pageSize, recordingMethodsToFilter, limit)

    /**
     * Reads [dataType] in [from, to) from [client] page by page, sending each token back as Dart
     * does: a read with a [limit] stops once it has [limit] points.
     */
    fun pages(
        dataType: String,
        from: Instant,
        to: Instant,
        client: HealthConnectClient,
        pageSize: Int = DEFAULT_PAGE_SIZE,
        recordingMethodsToFilter: List<Int> = emptyList(),
        limit: Int? = null,
    ): PageRead {
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
                "limit" to limit,
            )
            val page = reply { reader.getDataPage(MethodCall("getDataPage", arguments), it) } as Map<*, *>
            pages += points(page["data"])
            token = page["nextPageToken"] as String?
            tokens += token
        } while (token != null && (limit == null || pages.sumOf { it.size } < limit))
        return PageRead(pages, tokens)
    }

    /** Reads [dataType] in [from, to) with the deprecated getData, in one reply. */
    fun legacy(
        dataType: String,
        from: Instant,
        to: Instant,
        sessions: List<SleepSessionRecord>,
        limit: Int? = null,
    ): List<ReadPoint> = legacy(dataType, from, to, fakeSleepStore(sessions, requests), limit)

    /** Reads [dataType] in [from, to) from [client] with the deprecated getData, in one reply. */
    fun legacy(
        dataType: String,
        from: Instant,
        to: Instant,
        client: HealthConnectClient,
        limit: Int? = null,
    ): List<ReadPoint> {
        val reader = LegacyDataReader(
            client, CoroutineScope(job), converter(client), WorkoutRoutes(HealthRecordingFilter()),
            SeriesLookback(client), SleepLookback(client),
        )
        val arguments = hashMapOf(
            "dataTypeKey" to dataType, "startTime" to from.toEpochMilli(), "endTime" to to.toEpochMilli(),
            "recordingMethodsToFilter" to emptyList<Int>(), "limit" to limit,
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
