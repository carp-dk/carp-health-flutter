package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Metadata
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

/** One getDataPage reply: its points, next page token and 'permissionDenied' flag, or its error code. */
internal class PageReply(
    val points: List<ReadPoint>,
    val token: String?,
    val permissionDenied: Any?,
    val error: String? = null,
)

/**
 * Reads with getDataPage and getData from [client] as [OWN_PACKAGE] on Android [sdkInt], with heart
 * rate slices from [heartRate] (by default counted and read from [client], [fakeHeartRateStore]), and
 * keeps every reply as it came.
 */
internal class PageReplies(
    private val client: HealthConnectClient,
    private val heartRate: HeartRatePageReader? = null,
    private val sdkInt: Int = 37,
) {
    private val job = SupervisorJob()

    /**
     * The replies to a read of [dataType] in [from, to), page by page, sending each token back as
     * Dart does, until the last page, an error, or (with a [limit]) [limit] points.
     */
    fun read(
        dataType: String,
        from: Instant,
        to: Instant,
        pageSize: Int = DEFAULT_PAGE_SIZE,
        limit: Int? = null,
    ): List<PageReply> {
        val reader = DataPageReader(
            client, CoroutineScope(job), HealthDataConverter(), converter(),
            WorkoutRoutes(HealthRecordingFilter()), SeriesLookback(client), SleepLookback(client),
            heartRate ?: HeartRatePageReader(HealthConnectHeartRateSource(client), sdkInt), OWN_PACKAGE, sdkInt,
        )
        val replies = mutableListOf<PageReply>()
        var token: String? = null
        do {
            val arguments = hashMapOf(
                "dataTypeKey" to dataType, "startTime" to from.toEpochMilli(), "endTime" to to.toEpochMilli(),
                "pageSize" to pageSize, "pageToken" to token, "limit" to limit,
            )
            val result = reply { reader.getDataPage(MethodCall("getDataPage", arguments), it) }
            if (result.code != null) {
                replies += PageReply(emptyList(), null, null, result.code)
                break
            }
            val page = result.value as Map<*, *>
            token = page["nextPageToken"] as String?
            replies += PageReply(points(page["data"]), token, page["permissionDenied"])
        } while (token != null && (limit == null || replies.sumOf { it.points.size } < limit))
        return replies
    }

    /** Reads [dataType] in [from, to) with the deprecated getData, in one reply. */
    fun legacy(dataType: String, from: Instant, to: Instant, limit: Int? = null): List<ReadPoint> {
        val reader = LegacyDataReader(
            client, CoroutineScope(job), converter(), WorkoutRoutes(HealthRecordingFilter()),
            SeriesLookback(client), SleepLookback(client), OWN_PACKAGE, sdkInt,
        )
        val arguments = hashMapOf(
            "dataTypeKey" to dataType, "startTime" to from.toEpochMilli(), "endTime" to to.toEpochMilli(),
            "recordingMethodsToFilter" to emptyList<Int>(), "limit" to limit,
        )
        val result = reply { reader.getData(MethodCall("getData", arguments), it) }
        assertEquals(null, result.code)
        return points(result.value)
    }

    private fun converter(): RecordConverter {
        val dataConverter = HealthDataConverter()
        val recordingFilter = HealthRecordingFilter()
        val workouts = WorkoutConverter(client, recordingFilter, OWN_PACKAGE, sdkInt)
        return RecordConverter(dataConverter, recordingFilter, workouts, SleepConverter(dataConverter, recordingFilter))
    }

    // The one reply that [send] gets, once the reader's coroutine is done.
    private fun reply(send: (RecordingResult) -> Unit): RecordingResult {
        val result = RecordingResult()
        send(result)
        runBlocking { job.children.toList().joinAll() }
        assertEquals(1, result.replies)
        return result
    }

    private fun points(data: Any?): List<ReadPoint> = (data as List<*>).map { point ->
        point as Map<*, *>
        val from = Instant.ofEpochMilli(point["date_from"] as Long)
        ReadPoint(from, Instant.ofEpochMilli(point["date_to"] as Long), point["source_name"] as String)
    }
}

/** Whether every request asked for the records of [OWN_PACKAGE] only. */
internal fun List<ReadRecordsRequest<*>>.allOwn(): Boolean =
    all { it.dataOriginFilter == setOf(DataOrigin(OWN_PACKAGE)) }

/** The metadata of a record with [id] that the app [packageName] wrote. */
internal fun writtenBy(packageName: String, id: String): Metadata =
    metadata(Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED, id, DataOrigin(packageName))
