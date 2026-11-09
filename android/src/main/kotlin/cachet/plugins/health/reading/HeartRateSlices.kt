package cachet.plugins.health.reading

/**
 * The page token of a heart rate read: "v2:<cursor>:<span>:<plan>:<sliceEnd>:<records>:<hcToken>"
 * (times in epoch ms, "-" when absent). [plan] holds the ends of the slices planned after the
 * current one ([HistogramPlanner]); when it runs out, the next plan covers about [span] ms per page.
 * Between slices the last three are "-" and the next slice starts at [cursor]. Inside a slice the
 * next page goes on reading [cursor, sliceEnd) at [healthConnectToken], [records] records per
 * request. Like [DataPageToken] it is opaque to Dart, only valid with the same other arguments,
 * and never persisted.
 */
internal class SliceToken(
    val cursor: Long,
    val span: Long,
    val sliceEnd: Long? = null,
    val records: Int? = null,
    val healthConnectToken: String? = null,
    val plan: List<Long> = emptyList(),
) {
    init {
        require(span > 0) { "Slice token span $span is not positive" }
        val inSlice = listOf(sliceEnd, records, healthConnectToken).count { it != null }
        require(inSlice == 0 || inSlice == 3) { "Slice token has only part of a slice" }
        require(sliceEnd == null || sliceEnd > cursor) { "Slice token slice end $sliceEnd is not after $cursor" }
        require(records == null || records in 1..HC_MAX_RECORDS) { "Slice token record count $records is not in 1..$HC_MAX_RECORDS" }
        require(healthConnectToken == null || healthConnectToken.isNotEmpty()) { "Slice token has an empty token" }
        require(plan.size <= MAX_PLANNED_SLICES) { "Slice token plans ${plan.size} slices" }
        require((listOf(sliceEnd ?: cursor) + plan).zipWithNext().all { (a, b) -> a < b }) { "Slice token plan is not increasing" }
    }

    fun encode(): String =
        listOf(
            VERSION, cursor, span, plan.joinToString(",").ifEmpty { NONE }, sliceEnd ?: NONE, records ?: NONE,
            healthConnectToken ?: NONE,
        ).joinToString(":")

    companion object {
        private const val VERSION = "v2"
        private const val NONE = "-"

        /** The token [encode] made, or null for the first page. Throws IllegalArgumentException if malformed. */
        fun decode(token: String?): SliceToken? {
            if (token == null) return null
            // The Health Connect token comes last, so it may contain ':'.
            val parts = token.split(":", limit = 7)
            require(parts.size == 7 && parts[0] == VERSION) { "Malformed page token '$token'" }
            fun long(part: String) = requireNotNull(part.toLongOrNull()) { "Malformed page token '$token'" }
            fun int(part: String) = requireNotNull(part.toIntOrNull()) { "Malformed page token '$token'" }
            return SliceToken(
                cursor = long(parts[1]),
                span = long(parts[2]),
                plan = if (parts[3] == NONE) emptyList() else parts[3].split(",").map(::long),
                sliceEnd = parts[4].takeIf { it != NONE }?.let(::long),
                records = parts[5].takeIf { it != NONE }?.let(::int),
                healthConnectToken = parts[6].takeIf { it != NONE },
            )
        }
    }
}

/**
 * A slice of a heart rate read: the records that start in [start, end), with [samples] samples
 * counted in that range. [hasRecords] is false when no record starts in it, so it need not be read.
 */
internal data class PlannedSlice(val start: Long, val end: Long, val samples: Long, val hasRecords: Boolean = true)

/**
 * Plans one time slice of a heart rate read by counting its samples first
 * (HeartRateRecord.MEASUREMENTS_COUNT, an aggregate, so nothing is built). Health Connect pages by
 * record, and a heart rate record can hold thousands of samples, so a page of records has no bound
 * on its samples; building millions of samples runs the app out of memory inside Health Connect's
 * own threads, where the plugin cannot catch it. The pages of a read are planned in bulk by
 * [HistogramPlanner]; this planner sizes the slices of the look-back, which goes newest first.
 *
 * Health Connect counts samples by their own time but returns records by their start time, so a
 * slice also returns the samples after its end of the records that start in it. Those are rarely
 * more than one record's worth; [HeartRatePageReader] re-reads a page that holds far more.
 */
internal object SlicePlanner {
    /**
     * The slice that starts at [cursor] and ends by [end], trying [span] ms first. It holds at most
     * [budget] samples, and at least a quarter of that unless it reaches [end]. A gap is skipped with
     * one [firstStart] read instead of widening step by step. After [MAX_PLAN_STEPS] counts the
     * widest slice that fits is taken, or if none did, the narrowest one counted.
     *
     * @param countSamples the number of samples whose time is in [from, to)
     * @param firstStart the start of the first record that starts in [from, to), or null if none does
     */
    suspend fun plan(
        cursor: Long,
        end: Long,
        span: Long,
        budget: Int,
        countSamples: suspend (from: Long, to: Long) -> Long,
        firstStart: suspend (from: Long, to: Long) -> Long?,
    ): PlannedSlice {
        require(cursor < end) { "Empty slice range $cursor..$end" }
        val target = maxOf(1L, budget * 3L / 4)
        val enough = maxOf(1L, budget / 4L)
        // [cursor, fit) holds at most budget samples, [cursor, over) more; no record starts before floor.
        var fit = cursor
        var fitSamples = 0L
        var over = Long.MAX_VALUE
        var overSamples = 0L
        var floor = cursor
        var probed = false
        var next = cursor + span.coerceAtLeast(MIN_SLICE_MS).coerceAtMost(end - cursor)

        // The widest slice that fits, unless no record starts in it: then the narrowest that does not.
        fun best() = if (fit > floor || over == Long.MAX_VALUE) PlannedSlice(cursor, fit, fitSamples)
        else PlannedSlice(cursor, over, overSamples)

        repeat(MAX_PLAN_STEPS) {
            val samples = countSamples(cursor, next)
            var concentrated = false
            if (samples <= budget) {
                fit = next
                fitSamples = samples
                if (next >= end || samples >= enough) return PlannedSlice(cursor, next, samples)
                if (samples == 0L && !probed) {
                    probed = true
                    floor = firstStart(cursor, end) ?: return PlannedSlice(cursor, end, 0, hasRecords = false)
                }
                // A record starts inside but holds no samples there: read it rather than search on.
                if (samples == 0L && floor < next) return PlannedSlice(cursor, next, samples)
            } else {
                // A narrower slice that still holds most of the samples of the last one: they sit at its
                // start, so the shortest slice is tried next instead of narrowing a quarter at a time.
                concentrated = over != Long.MAX_VALUE && fit <= floor && samples * 4 > overSamples * 3
                over = next
                overSamples = samples
                if (next - floor <= MIN_SLICE_MS) return best()
            }
            // The next end to count, between what fits (or the first record) and what does not.
            val low = maxOf(fit, floor)
            next = when {
                concentrated -> low + MIN_SLICE_MS
                over == Long.MAX_VALUE && fitSamples > 0 ->
                    cursor + ((fit - cursor) * minOf(GROWTH.toDouble(), target.toDouble() / fitSamples)).toLong()
                over == Long.MAX_VALUE -> low + maxOf(MIN_SLICE_MS, fit - cursor)
                else -> {
                    val lowSamples = if (low == fit) fitSamples else 0L
                    val share = (target - lowSamples).toDouble() / maxOf(1L, overSamples - lowSamples)
                    val guess = low + ((over - low) * share.coerceIn(0.0, 1.0)).toLong()
                    // Inside a bracket, move at least an eighth of it, so that the search narrows.
                    if (low > cursor) guess.coerceIn(low + (over - low) / 8, over - (over - low) / 8) else guess
                }
            }.coerceAtLeast(maxOf(low + 1, cursor + MIN_SLICE_MS)).coerceAtMost(minOf(end, over - 1))
            if (next <= low) return best()
        }
        return best()
    }

    /**
     * The span to try after a slice of [span] ms that held [samples] samples: sized to three
     * quarters of [budget] at the same density, but at most [GROWTH] times longer.
     */
    fun nextSpan(span: Long, samples: Long, budget: Int): Long {
        val target = maxOf(1L, budget * 3L / 4)
        val factor = if (samples <= 0) GROWTH.toDouble() else minOf(GROWTH.toDouble(), target.toDouble() / samples)
        return (span * factor).toLong().coerceAtLeast(MIN_SLICE_MS)
    }

    private const val GROWTH = 4L
}
