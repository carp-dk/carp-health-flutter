package cachet.plugins.health.reading

import android.content.Context
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import cachet.plugins.health.HealthDataConverter
import cachet.plugins.health.HealthErrors
import cachet.plugins.health.HealthRecordingFilter
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers

/**
 * Handles reading and querying health data from Health Connect.
 * Manages data retrieval, filtering, aggregation, and format conversion for Flutter consumption.
 *
 * Every Health Connect call runs on [Dispatchers.Default], and replies are sent from there:
 * converting and encoding a large reply on the main thread would stall the UI.
 */
class HealthDataReader(
    private val healthConnectClient: HealthConnectClient,
    private val scope: CoroutineScope,
    private val context: Context,
    private val dataConverter: HealthDataConverter
) {
    private val recordingFilter = HealthRecordingFilter()
    private val workouts = WorkoutConverter(healthConnectClient, recordingFilter)
    private val sleep = SleepConverter(dataConverter, recordingFilter)
    private val routes = WorkoutRoutes(recordingFilter)
    private val converter = RecordConverter(dataConverter, recordingFilter, workouts, sleep)
    private val lookback = SeriesLookback(healthConnectClient)
    private val sleepLookback = SleepLookback(healthConnectClient)

    private val legacyReader = LegacyDataReader(healthConnectClient, scope, converter, routes, lookback, sleepLookback)
    private val heartRate = HeartRatePageReader(HealthConnectHeartRateSource(healthConnectClient), Build.VERSION.SDK_INT)
    private val pageReader =
        DataPageReader(healthConnectClient, scope, dataConverter, converter, routes, lookback, sleepLookback, heartRate)
    private val recordByIdReader =
        RecordByIdReader(healthConnectClient, scope, dataConverter, workouts, sleep, routes)
    private val aggregateReader =
        AggregateReader(healthConnectClient, scope, SleepIntervalReader(healthConnectClient, recordingFilter))
    private val totalStepsReader = TotalStepsReader(healthConnectClient, scope, recordingFilter)

    /**
     * Retrieves all health data points of a specified type within a given time range.
     * Handles pagination for large datasets and applies recording method filtering.
     * Supports special processing for workout and sleep data.
     *
     * The whole range is held in memory and sent as one reply, which runs the Java heap out of
     * memory at a few hundred thousand points; the Dart side reads through [getDataPage].
     *
     * @param call Method call containing 'dataTypeKey', 'startTime', 'endTime', 'recordingMethodsToFilter'
     * and optionally 'limit' ([readNewestRecords])
     * @param result Flutter result callback returning list of health data maps
     */
    // Deprecated: the Dart side reads through getDataPage since 14.0.0 and calls this only for
    // channel mocks written for older versions; remove in a later major version.
    fun getData(call: MethodCall, result: Result) {
        legacyReader.getData(call, result)
    }

    /**
     * Reads one page of data points, so the Dart side can walk ranges of any size without this
     * side holding the whole range in memory (one reply for ~300k points runs the Java heap out of
     * memory on a 256 MB device).
     *
     * A page holds about 'pageSize' data points. Health Connect pages by record, and one series
     * record can hold thousands of samples: heart rate is therefore read in time slices planned
     * from counts of its samples ([HistogramPlanner]), and speed, power, cycling cadence and skin
     * temperature ask for few records per request ([SeriesPageSizer]).
     * A sleep stage is returned when it starts in the range, whichever session it belongs to: the
     * first page also reads the sessions that began in the [SLEEP_LOOKBACK] before the range ([SleepLookback]).
     * The reply is {data, nextPageToken}; the token ([DataPageToken], [SliceToken]) is opaque to
     * Dart and null on the last page. Without read permission the first page is empty, last, and flagged
     * 'permissionDenied'. Failures are reported with the codes of [HealthErrors], never as data.
     * A call with a 'limit' pages newest first, by record start time, with a first page of at most
     * 'limit' records ([DataPageRequest.limit]).
     *
     * @param call Method call containing 'dataTypeKey', 'dataUnitKey', 'startTime', 'endTime',
     * 'recordingMethodsToFilter', 'pageSize' and the 'pageToken' returned by the previous page, or a 'limit'
     * @param result Flutter result callback returning a map with 'data' and 'nextPageToken'
     */
    fun getDataPage(call: MethodCall, result: Result) {
        pageReader.getDataPage(call, result)
    }

    /**
     * Retrieves single health data point by given UUID and type.
     * Replies null when Health Connect has no record with that UUID.
     *
     * @param call Method call containing 'uuid' and 'dataTypeKey'
     * @param result Flutter result callback returning the health data map
     */
    fun getDataByUUID(call: MethodCall, result: Result) {
        recordByIdReader.getDataByUUID(call, result)
    }

    /**
     * Retrieves aggregated health data grouped by time intervals.
     * Calculates totals or averages over specified time periods, and for sleep types the minutes
     * their data points cover ([SleepIntervalReader]). Intervals without data are left out.
     *
     * @param call Method call containing 'dataTypeKey', 'interval', 'startTime', 'endTime' and,
     * for sleep types, 'recordingMethodsToFilter'
     * @param result Flutter result callback returning list of aggregated data maps
     */
    fun getIntervalData(call: MethodCall, result: Result) {
        aggregateReader.getAggregateData(call, result)
    }

    /**
     * Gets total step count within a specified time interval with optional filtering.
     * Optimizes between aggregated queries and filtered individual record queries
     * based on whether recording method filtering is required.
     *
     * @param call Method call containing 'startTime', 'endTime', 'recordingMethodsToFilter'
     * @param result Flutter result callback returning total step count as integer
     */
    fun getTotalStepsInInterval(call: MethodCall, result: Result) {
        totalStepsReader.getTotalStepsInInterval(call, result)
    }
}
