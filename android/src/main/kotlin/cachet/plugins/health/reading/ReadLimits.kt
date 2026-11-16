package cachet.plugins.health.reading

import java.time.Duration

// Health Connect rejects larger pages ("Valid pageSize range is 1 - 5000").
internal const val HC_MAX_RECORDS = 5000

// Data points per getDataPage reply when Dart sends no 'pageSize', and the most it may ask for.
internal const val DEFAULT_PAGE_SIZE = 20000
internal const val MAX_PAGE_SIZE = 50000

// Heart rate is read in time slices of at most a page of samples: their shortest span.
internal const val MIN_SLICE_MS = 1_000L

// The pages of a heart rate read are planned from histograms (HistogramPlanner): buckets per
// histogram, pages each plan aims to cover, the most slices one plan (and page token) holds, how
// often a bucket that alone holds more than a page is split again, and the range of the first plan.
internal const val PLAN_BUCKETS = 64
internal const val PLAN_PAGES = 8
internal const val MAX_PLANNED_SLICES = 16
internal const val MAX_PLAN_DEPTH = 3
internal val FIRST_PLAN_WINDOW_MS: Long = Duration.ofDays(1).toMillis()

// Speed, power, cycling cadence and skin temperature have no sample count, so their records per
// request assume a record may hold an hour of 1 Hz samples: at most pageSize / 3600 records (5 at
// the default pageSize), one on the first page, and that cap but no more than 20 on the Health
// Connect APK (before Android 14) for the whole token chain.
internal const val ASSUMED_MAX_SAMPLES_PER_RECORD = 3600
internal const val SERIES_FIRST_RECORDS = 1
internal const val SERIES_FIXED_RECORDS_PRE34 = 20

// Records per request for sessions: sleep sessions expand to their stages, each workout costs
// up to three more reads, and each exercise session carries its whole route.
internal const val SLEEP_MAX_RECORDS = 500
internal const val WORKOUT_MAX_RECORDS = 20
internal const val ROUTE_MAX_RECORDS = 5

// How far before the requested start series reads look for records that began earlier. Heart
// rate scans that whole range slice by slice; the other series check only the newest records (as
// many as one page may hold, fewer after a page did not fit in memory).
internal val SERIES_LOOKBACK: Duration = Duration.ofHours(24)
internal const val SERIES_PROBE_RECORDS_RETRY = 1

// The heart rate look-back (HeartRateLookback) reads slices of at least this many samples, whatever
// the page size, and makes at most this many Health Connect calls; a page makes at most
// MAX_HEART_RATE_PAGE_CALLS in all (planning, reading and re-reading its slice, and the look-back),
// and one more for each read that ends inside the records of one start time (readPastTies).
internal const val LOOKBACK_SLICE_SAMPLES = DEFAULT_PAGE_SIZE
internal const val MAX_LOOKBACK_CALLS = 24
internal const val MAX_HEART_RATE_PAGE_CALLS = 40

// How far before the requested start sleep intervals and sleep stage reads look for sessions: Health
// Connect matches sessions by start time, but a session that began earlier counts with its part in
// the first buckets, and a read returns its stages that start in the range ([SleepLookback]).
internal val SLEEP_LOOKBACK: Duration = Duration.ofHours(24)

// Re-reads of a page with fewer records per getDataPage call, and how many times 'pageSize'
// samples a series page may hold before it is re-read.
internal const val MAX_SHRINK_RETRIES = 3
internal const val OVERSIZE_FACTOR = 2
