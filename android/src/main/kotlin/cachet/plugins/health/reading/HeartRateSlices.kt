package cachet.plugins.health.reading

/**
 * The page token of a heart rate read: "v2:<cursor>:<span>:<plan>:<sliceEnd>:<records>:<hcToken>"
 * (times in epoch ms, "-" when absent), or "o2:..." for a read of this app's own records only
 * ([ownOnly]). [plan] holds the ends of the slices planned after the
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
    val ownOnly: Boolean = false,
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
            if (ownOnly) OWN_VERSION else VERSION, cursor, span, plan.joinToString(",").ifEmpty { NONE },
            sliceEnd ?: NONE, records ?: NONE, healthConnectToken ?: NONE,
        ).joinToString(":")

    companion object {
        private const val VERSION = "v2"
        private const val OWN_VERSION = "o2"
        private const val NONE = "-"

        /** The token [encode] made, or null for the first page. Throws IllegalArgumentException if malformed. */
        fun decode(token: String?): SliceToken? {
            if (token == null) return null
            // The Health Connect token comes last, so it may contain ':'.
            val parts = token.split(":", limit = 7)
            val ownOnly = parts[0] == OWN_VERSION
            require(parts.size == 7 && (parts[0] == VERSION || ownOnly)) { "Malformed page token '$token'" }
            fun long(part: String) = requireNotNull(part.toLongOrNull()) { "Malformed page token '$token'" }
            fun int(part: String) = requireNotNull(part.toIntOrNull()) { "Malformed page token '$token'" }
            return SliceToken(
                cursor = long(parts[1]),
                span = long(parts[2]),
                plan = if (parts[3] == NONE) emptyList() else parts[3].split(",").map(::long),
                sliceEnd = parts[4].takeIf { it != NONE }?.let(::long),
                records = parts[5].takeIf { it != NONE }?.let(::int),
                healthConnectToken = parts[6].takeIf { it != NONE },
                ownOnly = ownOnly,
            )
        }
    }
}
