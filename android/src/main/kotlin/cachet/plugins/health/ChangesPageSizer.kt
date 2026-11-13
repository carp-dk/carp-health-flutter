package cachet.plugins.health

// The most data points one getChanges reply may hold: twice the largest getDataPage page.
internal const val MAX_CHANGE_POINTS = 100_000L

// Health Connect's range for the page size of getChanges, a soft limit on the number of changes.
private const val MAX_CHANGES_PAGE_SIZE = 5000

/**
 * Sizes the pages of getChanges. Health Connect returns a page of changed records whatever their
 * size, and one heart rate record can hold thousands of samples, so a page that holds more than
 * [MAX_CHANGE_POINTS] data points is read again from the same token with fewer changes.
 */
internal object ChangesPageSizer {
    /**
     * The page size to read the token of a page of [changes] changes again with when the page holds
     * [points] data points: as many changes as should hold [MAX_CHANGE_POINTS] points, but at most half
     * of the page, in 1..5000. When the points sit in the first changes of the page, the first share
     * hardly shrinks it; halving still takes 5000 changes down to one in 12 re-reads. Null if the page
     * fits, or if it cannot get smaller because it holds a single change.
     */
    fun smallerPageSize(changes: Int, points: Long): Int? =
        if (points <= MAX_CHANGE_POINTS || changes <= 1) null
        else minOf(changes.toLong() * MAX_CHANGE_POINTS / points, changes / 2L)
            .coerceIn(1L, MAX_CHANGES_PAGE_SIZE.toLong()).toInt()
}
