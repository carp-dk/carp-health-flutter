package cachet.plugins.health.reading

import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SleepSessionRecord
import cachet.plugins.health.HealthConstants
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.intList
import cachet.plugins.health.optionalLong
import cachet.plugins.health.optionalString
import cachet.plugins.health.requireLong
import cachet.plugins.health.requireString
import io.flutter.plugin.common.MethodCall
import java.time.Instant
import kotlin.reflect.KClass

/**
 * The page token of getDataPage: "v1:<records>:<hcToken>". [records] is the number of Health
 * Connect records to request for the next page, and [healthConnectToken] is the token Health
 * Connect returned, passed through untouched (a decimal long on Android 14 and later). Dart sends
 * it back verbatim, so it is only valid with the same other arguments. It is never persisted.
 */
internal class DataPageToken(val records: Int, val healthConnectToken: String) {
    init {
        require(records in 1..HC_MAX_RECORDS) { "Page token record count $records is not in 1..$HC_MAX_RECORDS" }
        require(healthConnectToken.isNotEmpty()) { "Page token has no Health Connect token" }
    }

    fun encode(): String = "$VERSION:$records:$healthConnectToken"

    companion object {
        private const val VERSION = "v1"

        /** The token [encode] made, or null for the first page. Throws IllegalArgumentException if malformed. */
        fun decode(token: String?): DataPageToken? {
            if (token == null) return null
            val parts = token.split(":", limit = 3)
            require(parts.size == 3 && parts[0] == VERSION) { "Malformed page token '$token'" }
            val records = requireNotNull(parts[1].toIntOrNull()) { "Malformed page token '$token'" }
            return DataPageToken(records, parts[2])
        }
    }
}

/**
 * Sizes the pages of speed, power, cycling cadence and skin temperature, whose records hold any
 * number of samples and have no sample count to plan by (heart rate is read in counted time
 * slices, [SlicePlanner]). A request asks for at most [cap] records, so even records of an hour
 * of 1 Hz samples keep a page near pageSize samples.
 *
 * Health Connect page tokens are positional on Android 14 and later, so the number of records may
 * change along a token chain (verified on Android 17). That is not verified for the Health Connect
 * APK on older versions, so there one fixed number is used for the whole chain.
 */
internal object SeriesPageSizer {
    /** The most records one request may ask for at [pageSize]. */
    fun cap(pageSize: Int): Int = (pageSize / ASSUMED_MAX_SAMPLES_PER_RECORD).coerceIn(1, HC_MAX_RECORDS)

    /** Records for the first page, before anything is known about their size. */
    fun firstRecords(sdkInt: Int, pageSize: Int): Int =
        if (sdkInt >= 34) SERIES_FIRST_RECORDS else minOf(cap(pageSize), SERIES_FIXED_RECORDS_PRE34)

    /**
     * Records for the page after one of [current] records, the largest of which held
     * [maxSamplesPerRecord] samples. Grows at most fourfold and never past [cap].
     */
    fun nextRecords(current: Int, pageSize: Int, maxSamplesPerRecord: Int, sdkInt: Int): Int =
        if (sdkInt < 34) current
        else minOf(4 * current, pageSize / maxOf(1, maxSamplesPerRecord), cap(pageSize)).coerceAtLeast(1)

    /**
     * Fewer records to read the same position with when a page of [current] records holds more than
     * [OVERSIZE_FACTOR] times [pageSize] samples ([rawSamples]), or null to keep the page.
     */
    fun shrinkForOversize(current: Int, pageSize: Int, rawSamples: Int): Int? =
        if (current > 1 && rawSamples > OVERSIZE_FACTOR * pageSize)
            maxOf(1, (current.toLong() * pageSize / rawSamples).toInt())
        else null
}

/**
 * The Health Connect record type of [dataType]; workout routes are stored on exercise
 * sessions. Throws UnsupportedOperationException for a type Health Connect does not have,
 * such as BODY_MASS_INDEX (which the Dart side computes).
 */
internal fun recordTypeFor(dataType: String): KClass<out Record> =
    if (dataType == HealthConstants.WORKOUT_ROUTE) {
        ExerciseSessionRecord::class
    } else {
        HealthConstants.mapToType[dataType]
            ?: throw UnsupportedOperationException("Data type $dataType is not supported by Health Connect")
    }

/** The arguments of a getDataPage call. */
internal class DataPageRequest(
    val dataType: String,
    val dataUnit: String?,
    val startTime: Instant,
    val endTime: Instant,
    val recordingMethodsToFilter: List<Int>,
    val pageSize: Int,
    val token: DataPageToken?,
    val sliceToken: SliceToken? = null,
    /** Read only the records that start last, as the one page ([readNewestRecords]); null for all. */
    val limit: Int? = null,
) {
    /** The Health Connect record type to read. */
    val recordType: KClass<out Record> = recordTypeFor(dataType)

    /** Whether each record holds a series of samples, each of which is a data point. */
    val isSeries: Boolean get() = recordType in HealthDataConverter.seriesTypes

    /** Whether this is a heart rate read, which goes slice by slice ([SlicePlanner], [sliceToken]). */
    val isSliced: Boolean get() = dataType == HealthConstants.HEART_RATE

    /** Whether this is a read of a sleep stage type, whose first page also looks back ([SleepLookback]). */
    val isSleepStage: Boolean get() = isSleepStageType(dataType)

    /** Whether this is the first page of the read. */
    val isFirstPage: Boolean get() = token == null && sliceToken == null

    /** Records to request for the first page; later pages take the number from [token]. */
    fun firstRecords(sdkInt: Int): Int = when {
        isSeries -> SeriesPageSizer.firstRecords(sdkInt, pageSize)
        // Each session carries its whole route.
        dataType == HealthConstants.WORKOUT_ROUTE -> minOf(pageSize, ROUTE_MAX_RECORDS)
        // Each workout costs up to three more reads (distance, energy, steps).
        dataType == HealthConstants.WORKOUT -> minOf(pageSize, WORKOUT_MAX_RECORDS)
        // Each session expands to its stages.
        recordType == SleepSessionRecord::class -> minOf(pageSize, SLEEP_MAX_RECORDS)
        else -> minOf(pageSize, HC_MAX_RECORDS)
    }

    companion object {
        /**
         * Reads the arguments of [call]. Throws IllegalArgumentException for a missing or malformed
         * argument, and UnsupportedOperationException for a type Health Connect does not have.
         */
        fun from(call: MethodCall): DataPageRequest {
            val dataType = call.requireString("dataTypeKey")
            val pageToken = call.optionalString("pageToken")
            val sliced = dataType == HealthConstants.HEART_RATE
            return DataPageRequest(
                dataType = dataType,
                dataUnit = call.optionalString("dataUnitKey"),
                startTime = Instant.ofEpochMilli(call.requireLong("startTime")),
                endTime = Instant.ofEpochMilli(call.requireLong("endTime")),
                recordingMethodsToFilter = call.intList("recordingMethodsToFilter"),
                pageSize = call.optionalLong("pageSize")?.coerceIn(1L, MAX_PAGE_SIZE.toLong())?.toInt()
                    ?: DEFAULT_PAGE_SIZE,
                token = if (sliced) null else DataPageToken.decode(pageToken),
                sliceToken = if (sliced) SliceToken.decode(pageToken) else null,
                limit = call.recordLimit(),
            )
        }
    }
}
