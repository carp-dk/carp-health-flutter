package cachet.plugins.health.reading

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class SliceTokenTest {
    @Test
    fun roundTripsBetweenSlices() {
        val token = SliceToken(1_700_000_000_000L, 60_000L)
        assertEquals("v2:1700000000000:60000:-:-:-:-", token.encode())

        val decoded = SliceToken.decode(token.encode())!!
        assertEquals(1_700_000_000_000L, decoded.cursor)
        assertEquals(60_000L, decoded.span)
        assertNull(decoded.sliceEnd)
        assertNull(decoded.records)
        assertNull(decoded.healthConnectToken)
    }

    @Test
    fun roundTripsInsideASliceKeepingColonsInTheHealthConnectToken() {
        val decoded = SliceToken.decode(SliceToken(100, 5, 200, 3, "a:b::c", listOf(300, 450)).encode())!!
        assertEquals(100L, decoded.cursor)
        assertEquals(5L, decoded.span)
        assertEquals(200L, decoded.sliceEnd)
        assertEquals(3, decoded.records)
        assertEquals("a:b::c", decoded.healthConnectToken)
        assertEquals(listOf(300L, 450L), decoded.plan)
    }

    @Test
    fun roundTripsAPlanBetweenSlices() {
        val token = SliceToken(100, 5, plan = listOf(200, 300))
        assertEquals("v2:100:5:200,300:-:-:-", token.encode())
        assertEquals(listOf(200L, 300L), SliceToken.decode(token.encode())!!.plan)
    }

    @Test
    fun nullIsTheFirstPage() {
        assertNull(SliceToken.decode(null))
    }

    @Test
    fun rejectsMalformedTokens() {
        val bad = listOf(
            "", "garbage", "v1:16:12345", "v2:1:2:-:-:-", "v3:1:2:-:-:-:-", "v2:x:2:-:-:-:-", "v2:1:x:-:-:-:-",
            // Part of a slice, an empty slice, no span, a record count Health Connect rejects, an empty token.
            "v2:1:2:-:3:-:-", "v2:1:2:-:-:4:t", "v2:5:2:-:5:1:t", "v2:1:0:-:-:-:-", "v2:1:2:-:3:0:t", "v2:1:2:-:3:5001:t",
            "v2:1:2:-:3:4:",
            // A plan that does not go forward, from the cursor or the slice end, or holds something else.
            "v2:10:2:5:-:-:-", "v2:10:2:20,20:-:-:-", "v2:10:2:30,20:-:-:-", "v2:1:2:4:5:1:t", "v2:1:2:x:-:-:-", "v2:1:2::-:-:-",
            "v2:1:2:" + (2..18).joinToString(",") + ":-:-:-",
        )
        for (token in bad) {
            assertThrows("'$token'", IllegalArgumentException::class.java) { SliceToken.decode(token) }
        }
    }
}
