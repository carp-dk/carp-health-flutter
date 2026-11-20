package cachet.plugins.health

import cachet.plugins.health.ChangesPageSizer.smallerPageSize
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChangesPageSizerTest {
    @Test
    fun keepsAPageOfUpToMaxChangePoints() {
        assertNull(smallerPageSize(1000, MAX_CHANGE_POINTS))
        assertNull(smallerPageSize(1000, 0))
        assertNull(smallerPageSize(0, 0))
    }

    @Test
    fun readsAsManyChangesAsHoldMaxChangePoints() {
        // 1000 changed heart rate series of 600 samples: 166 of them hold 99,600 points.
        assertEquals(166, smallerPageSize(1000, 600_000))
        assertEquals(500, smallerPageSize(1000, 2 * MAX_CHANGE_POINTS))
    }

    @Test
    fun readsAtMostHalfOfThePage() {
        // The points may sit in the first changes, so a page just over the limit is still halved.
        assertEquals(500, smallerPageSize(1000, MAX_CHANGE_POINTS + 1))
        assertEquals(1, smallerPageSize(3, MAX_CHANGE_POINTS + 1))
        for (changes in listOf(2, 3, 10, 1000, 5000)) {
            for (points in listOf(MAX_CHANGE_POINTS + 1, 3 * MAX_CHANGE_POINTS, 1_000_000_000L)) {
                val pageSize = smallerPageSize(changes, points)!!
                assertTrue("$changes changes, $points points", pageSize in 1..changes / 2)
            }
        }
    }

    @Test
    fun staysInHealthConnectsRangeOfOneTo5000() {
        assertEquals(1, smallerPageSize(2, 1_000_000_000L))
        // The page size is a soft limit, so a page may hold more changes than asked for.
        assertEquals(5000, smallerPageSize(12_000, 2 * MAX_CHANGE_POINTS))
    }

    @Test
    fun aSingleChangeOverTheLimitCannotGetSmaller() {
        assertNull(smallerPageSize(1, MAX_CHANGE_POINTS + 1))
        assertNull(smallerPageSize(1, 5_000_000))
    }
}
