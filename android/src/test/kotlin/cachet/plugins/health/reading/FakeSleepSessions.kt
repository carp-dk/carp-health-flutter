package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.response.ReadRecordsResponse
import cachet.plugins.health.fakeOf
import java.lang.reflect.Proxy
import java.time.Instant

/**
 * A Health Connect client whose suspend functions return at once what [answer] returns for the
 * method's name and its arguments (without the continuation).
 */
internal fun fakeHealthConnect(answer: (method: String, args: List<Any?>) -> Any?): HealthConnectClient =
    Proxy.newProxyInstance(
        HealthConnectClient::class.java.classLoader,
        arrayOf(HealthConnectClient::class.java),
    ) { _, method, args -> answer(method.name, args.orEmpty().toList().dropLast(1)) } as HealthConnectClient

/**
 * A Health Connect client that holds [sessions] and grants reading them, and reads them as Health
 * Connect does (verified on Android 17): a session is in a time range when it starts in it, the
 * sessions come in start order (newest first if asked), and a page token is a position. Each read
 * request is added to [requests].
 */
internal fun fakeSleepStore(
    sessions: List<SleepSessionRecord>,
    requests: MutableList<ReadRecordsRequest<*>> = mutableListOf(),
): HealthConnectClient {
    val permissions = fakeOf<PermissionController> { method ->
        check(method == "getGrantedPermissions") { "Unexpected call of $method" }
        setOf(HealthPermission.getReadPermission(SleepSessionRecord::class))
    }
    val byStart = sessions.sortedBy { it.startTime }
    return fakeHealthConnect { method, args ->
        when (method) {
            "getPermissionController" -> permissions
            "readRecords" -> {
                val request = args.single() as ReadRecordsRequest<*>
                requests.add(request)
                val from = request.timeRangeFilter.startTime
                val to = request.timeRangeFilter.endTime
                val matching = byStart
                    .filter { from == null || !it.startTime.isBefore(from) }
                    .filter { to == null || it.startTime.isBefore(to) }
                    .let { if (request.ascendingOrder) it else it.reversed() }
                val position = request.pageToken?.toInt() ?: 0
                val next = minOf(position + request.pageSize, matching.size)
                ReadRecordsResponse(matching.subList(position, next), if (next < matching.size) "$next" else null)
            }
            else -> throw UnsupportedOperationException(method)
        }
    }
}

/** A sleep session written by the app [packageName]. */
internal fun sleepSession(
    startTime: Instant,
    endTime: Instant,
    stages: List<SleepSessionRecord.Stage> = emptyList(),
    packageName: String = "com.example.sleep",
    recordingMethod: Int = Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED,
): SleepSessionRecord = SleepSessionRecord(
    startTime = startTime,
    startZoneOffset = null,
    endTime = endTime,
    endZoneOffset = null,
    metadata = metadata(recordingMethod, "$packageName@$startTime", DataOrigin(packageName)),
    stages = stages,
)

// Health Connect sets the data origin of a record, so the constructor that takes one is internal to
// the client library: it is called through reflection.
private fun metadata(recordingMethod: Int, id: String, dataOrigin: DataOrigin): Metadata =
    Metadata::class.java
        .getConstructor(
            Int::class.javaPrimitiveType, String::class.java, DataOrigin::class.java, Instant::class.java,
            String::class.java, Long::class.javaPrimitiveType, Device::class.java,
        )
        .newInstance(recordingMethod, id, dataOrigin, Instant.EPOCH, null, 0L, null)
