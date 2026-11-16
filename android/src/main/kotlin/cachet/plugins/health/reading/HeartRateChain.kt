package cachet.plugins.health.reading

import android.os.Build
import androidx.health.connect.client.records.HeartRateRecord

/** A request's worth of heart rate records, and the number of records it was read with. */
internal class ChainPage(val page: HeartRateRecords, val records: Int)

/**
 * The Health Connect requests of one heart rate slice, which is a token chain of its own. Health
 * Connect pages by record, and a record may hold any number of samples, so a request that returns far
 * more samples than counted is read again with fewer records, and the next one asks for more again.
 */
internal object HeartRateChain {
    /**
     * Up to [records] of the records that start in [from, to) at [pageToken] (and every further one of the
     * start time the last one has, [HeartRateSource.read]), read again with fewer while they hold more than
     * [OVERSIZE_FACTOR] times [budget] samples ([SeriesPageSizer.shrinkForOversize]), at most
     * [MAX_SHRINK_RETRIES] times. The Health Connect APK (before Android 14) cannot change that number
     * inside a chain.
     */
    suspend fun read(
        source: HeartRateSource,
        from: Long,
        to: Long,
        records: Int,
        pageToken: String?,
        budget: Int,
        sdkInt: Int,
    ): ChainPage {
        var asked = records
        var page = source.read(from, to, asked, pageToken)
        var retries = 0
        val positions = sdkInt >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
        while (retries < MAX_SHRINK_RETRIES && (pageToken == null || positions)) {
            // From Android 14 on, the records of the page's last start time come whole: fewer must leave them out.
            // The Health Connect APK's tokens are no positions, so no records come whole there ([pastTies]).
            val most = if (positions) recordsBeforeLastStart(page.records) else page.records.size
            val fewer = SeriesPageSizer.shrinkForOversize(page.records.map { it.samples.size }, budget)
                ?.takeIf { it <= most } ?: break
            val again = source.read(from, to, fewer, pageToken)
            // Records written between the two reads may make the read again no smaller: the page read before stays.
            if (again.records.size >= page.records.size) break
            page = again
            asked = fewer
            retries++
        }
        return ChainPage(page, asked)
    }

    /**
     * Records for the request after one of [records] whose largest record held [largest] samples: up
     * to four times more, as many as [budget] samples of that record allow, at least one. Fixed for the
     * whole chain before Android 14.
     */
    fun nextRecords(records: Int, largest: Int, budget: Int, sdkInt: Int): Int {
        if (sdkInt < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return records
        val fit = minOf(4L * records, budget.toLong() / maxOf(1, largest), HC_MAX_RECORDS.toLong())
        return fit.toInt().coerceAtLeast(1)
    }
}

/** Whether [record] starts in [from, to) (epoch ms). */
internal fun startsIn(record: HeartRateRecord, from: Long, to: Long): Boolean =
    record.startTime.toEpochMilli().let { it >= from && it < to }

/** The samples of [records] whose time is in [from, to) (epoch ms). */
internal fun samplesIn(records: List<HeartRateRecord>, from: Long, to: Long): Long =
    records.sumOf { record ->
        record.samples.count { it.time.toEpochMilli().let { t -> t >= from && t < to } }.toLong()
    }
