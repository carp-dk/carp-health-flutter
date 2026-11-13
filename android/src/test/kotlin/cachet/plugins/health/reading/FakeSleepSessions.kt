package cachet.plugins.health.reading

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
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
 * Connect does ([fakeRecordStore]). Each read request is added to [requests].
 */
internal fun fakeSleepStore(
    sessions: List<SleepSessionRecord>,
    requests: MutableList<ReadRecordsRequest<*>> = mutableListOf(),
): HealthConnectClient = fakeRecordStore(SleepSessionRecord::class, sessions, requests)

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

/**
 * The metadata of a record that the app of [dataOrigin] wrote. Health Connect sets the data origin of a
 * record, so the constructor that takes one is internal to the client library: it is called through
 * reflection.
 */
internal fun metadata(recordingMethod: Int, id: String, dataOrigin: DataOrigin): Metadata =
    Metadata::class.java
        .getConstructor(
            Int::class.javaPrimitiveType, String::class.java, DataOrigin::class.java, Instant::class.java,
            String::class.java, Long::class.javaPrimitiveType, Device::class.java,
        )
        .newInstance(recordingMethod, id, dataOrigin, Instant.EPOCH, null, 0L, null)
