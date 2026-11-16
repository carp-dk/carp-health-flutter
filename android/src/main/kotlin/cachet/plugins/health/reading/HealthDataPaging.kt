package cachet.plugins.health.reading

import android.os.Build
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
 * The page token of getDataPage: "v1:<records>:<hcToken>", or "o1:<records>:<hcToken>" for a read
 * of this app's own records only ([ownOnly]). [records] is the number of Health Connect records to
 * request for the next page, and [healthConnectToken] is the token Health Connect returned (a decimal
 * long on Android 14 and later), or a position at offset 0 of the plugin's own: past the records of
 * the start time a page ended inside ([readPastTies]), or past a cut page ([RecordsPage.cut]). Dart
 * sends it back verbatim, so it is only valid with the same other arguments. It is never persisted.
 */
internal class DataPageToken(val records: Int, val healthConnectToken: String, val ownOnly: Boolean = false) {
    init {
        require(records in 1..HC_MAX_RECORDS) { "Page token record count $records is not in 1..$HC_MAX_RECORDS" }
        require(healthConnectToken.isNotEmpty()) { "Page token has no Health Connect token" }
    }

    fun encode(): String = "${if (ownOnly) OWN_VERSION else VERSION}:$records:$healthConnectToken"

    companion object {
        private const val VERSION = "v1"
        private const val OWN_VERSION = "o1"

        /** The token [encode] made, or null for the first page. Throws IllegalArgumentException if malformed. */
        fun decode(token: String?): DataPageToken? {
            if (token == null) return null
            val parts = token.split(":", limit = 3)
            val ownOnly = parts[0] == OWN_VERSION
            require(parts.size == 3 && (parts[0] == VERSION || ownOnly)) { "Malformed page token '$token'" }
            val records = requireNotNull(parts[1].toIntOrNull()) { "Malformed page token '$token'" }
            return DataPageToken(records, parts[2], ownOnly)
        }

        /** Whether [token] is one of a read of this app's own records ([ownOnly]), as [encode] makes it. */
        fun isOwnOnly(token: String?): Boolean = token?.startsWith("$OWN_VERSION:") == true
    }
}

/**
 * Sizes the pages of speed, power, cycling cadence and skin temperature, whose records hold any
 * number of samples and have no sample count to plan by (heart rate is read in counted time
 * slices, [HeartRatePageReader], unless [DataPageRequest.isSliced] is false: then it is sized here too).
 * A request asks for at most [cap] records, so even records of an hour of 1 Hz samples keep a page
 * near pageSize samples, and a page that holds far more is read again with fewer ([shrinkForOversize]).
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
        if (sdkInt >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) SERIES_FIRST_RECORDS
        else minOf(cap(pageSize), SERIES_FIXED_RECORDS_PRE34)

    /**
     * Records for the page after one of [current] records, the largest of which held
     * [maxSamplesPerRecord] samples. Grows at most fourfold and never past [cap].
     */
    fun nextRecords(current: Int, pageSize: Int, maxSamplesPerRecord: Int, sdkInt: Int): Int {
        if (sdkInt < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return current
        return minOf(4 * current, pageSize / maxOf(1, maxSamplesPerRecord), cap(pageSize)).coerceAtLeast(1)
    }

    /**
     * Fewer records to read the same position with when the records a page returned, of [samples]
     * samples each in order, hold more than [OVERSIZE_FACTOR] times [pageSize] samples; or null to
     * keep the page. It is the leading records that fit in [pageSize] samples, at least one: sized
     * from what came back, not from what was asked for, which may be far more than came back.
     */
    fun shrinkForOversize(samples: List<Int>, pageSize: Int): Int? {
        if (samples.size <= 1 || samples.sumOf { it.toLong() } <= OVERSIZE_FACTOR.toLong() * pageSize) return null
        var total = 0L
        var fit = 0
        while (fit < samples.size && total + samples[fit] <= pageSize) total += samples[fit++]
        return maxOf(1, fit)
    }
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
    /**
     * The 'limit' of a read of the newest data points ([recordLimit]), or null. Such a read pages
     * newest first by record start time, with a first page of at most [limit] records, until the
     * Dart side has 'limit' points; it reads heart rate by record, and does not look back.
     */
    val limit: Int? = null,
    /**
     * Whether only the records this app wrote are read, as it may write the type but not read it
     * ([ReadAccess.OWN]): every Health Connect call of the read asks for them only, and every page
     * is flagged 'permissionDenied'. The first page decides it from the grants ([ownRecordsOnly]),
     * later pages take it from [token] or [sliceToken].
     */
    val ownOnly: Boolean = token?.ownOnly == true || sliceToken?.ownOnly == true,
    /**
     * Whether heart rate without a limit is read by record rather than in slices: a read of the app's
     * own records whose samples Health Connect does not count ([readByRecord]). Later pages carry a [token].
     */
    private val byRecord: Boolean = token != null,
) {
    /** The Health Connect record type to read. */
    val recordType: KClass<out Record> = recordTypeFor(dataType)

    /** Whether each record holds a series of samples, each of which is a data point. */
    val isSeries: Boolean get() = recordType in HealthDataConverter.seriesTypes

    /**
     * Whether this is a heart rate read without a limit, which goes slice by slice ([HeartRatePageReader],
     * [sliceToken]), also of this app's own records only ([ownOnly]): their samples are counted with a
     * data origin filter of this app. With a limit, or [byRecord], heart rate is paged by record like
     * the other series.
     */
    val isSliced: Boolean get() = isSlicedRead(dataType, limit) && !byRecord

    /** Whether this is a read of a sleep stage type, whose first page also looks back ([SleepLookback]). */
    val isSleepStage: Boolean get() = isSleepStageType(dataType)

    /** Whether this is the first page of the read. */
    val isFirstPage: Boolean get() = token == null && sliceToken == null

    /** Whether Health Connect is asked for the records that start last first: a read with a [limit]. */
    val isNewestFirst: Boolean get() = limit != null

    /**
     * Whether this page also reads the records that began before the range and reach into it
     * ([SeriesLookback], [SleepLookback]): the first page of a read without a limit. A read with a
     * limit starts at the other end of the range.
     */
    val looksBack: Boolean get() = isFirstPage && limit == null

    /** This first page as a read of this app's own records only ([ownOnly]). */
    fun ownRecordsOnly(): DataPageRequest {
        check(isFirstPage) { "Only the first page decides whether a read is of the app's own records" }
        return DataPageRequest(
            dataType, dataUnit, startTime, endTime, recordingMethodsToFilter, pageSize, token, sliceToken, limit,
            ownOnly = true,
        )
    }

    /**
     * This first page of a read of the app's own heart rate, read by record with the page tokens of
     * the other types: Health Connect counts the samples of an app without read permission only since
     * Android 14 QPR2 (and only in the foreground), and refuses it before with SecurityException.
     */
    fun readByRecord(): DataPageRequest {
        check(isFirstPage && ownOnly) { "Only the first page of a read of the app's own records turns to records" }
        return DataPageRequest(
            dataType, dataUnit, startTime, endTime, recordingMethodsToFilter, pageSize, token, sliceToken, limit,
            ownOnly = true, byRecord = true,
        )
    }

    /**
     * Records to request for the first page, at most [limit]; later pages take the number from
     * [token].
     */
    fun firstRecords(sdkInt: Int): Int {
        val records = when {
            isSeries -> SeriesPageSizer.firstRecords(sdkInt, pageSize)
            // Each session carries its whole route.
            dataType == HealthConstants.WORKOUT_ROUTE -> minOf(pageSize, ROUTE_MAX_RECORDS)
            // Each workout costs up to three more reads (distance, energy, steps).
            dataType == HealthConstants.WORKOUT -> minOf(pageSize, WORKOUT_MAX_RECORDS)
            // Each session expands to its stages.
            recordType == SleepSessionRecord::class -> minOf(pageSize, SLEEP_MAX_RECORDS)
            else -> minOf(pageSize, HC_MAX_RECORDS)
        }
        return minOf(records, limit ?: records)
    }

    companion object {
        /**
         * Reads the arguments of [call]. Throws IllegalArgumentException for a missing or malformed
         * argument, and UnsupportedOperationException for a type Health Connect does not have.
         */
        fun from(call: MethodCall): DataPageRequest {
            val dataType = call.requireString("dataTypeKey")
            val pageToken = call.optionalString("pageToken")
            val limit = call.recordLimit()
            // A heart rate read of the app's own records whose samples Health Connect did not count goes on by
            // record, with the tokens of the other types ([readByRecord]).
            val sliced = isSlicedRead(dataType, limit) && !DataPageToken.isOwnOnly(pageToken)
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
                limit = limit,
            )
        }

        /** Whether a read of [dataType] goes in heart rate time slices: one without a [limit]. */
        private fun isSlicedRead(dataType: String, limit: Int?): Boolean =
            dataType == HealthConstants.HEART_RATE && limit == null
    }
}
