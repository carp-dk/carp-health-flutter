package cachet.plugins.health.reading

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class DataPageTokenTest {
    @Test
    fun roundTrips() {
        val token = DataPageToken(37, "1712345678901")
        assertEquals("v1:37:1712345678901", token.encode())

        val decoded = DataPageToken.decode(token.encode())!!
        assertEquals(37, decoded.records)
        assertEquals("1712345678901", decoded.healthConnectToken)
    }

    @Test
    fun keepsColonsInTheHealthConnectToken() {
        // Only the first two colons separate: the Health Connect token is passed through untouched.
        val decoded = DataPageToken.decode("v1:5:a:b::c")!!
        assertEquals(5, decoded.records)
        assertEquals("a:b::c", decoded.healthConnectToken)
        assertEquals("v1:5:a:b::c", decoded.encode())
    }

    @Test
    fun nullIsTheFirstPage() {
        assertNull(DataPageToken.decode(null))
    }

    @Test
    fun acceptsOneToFiveThousandRecords() {
        assertEquals(1, DataPageToken.decode("v1:1:9")!!.records)
        assertEquals(5000, DataPageToken.decode("v1:5000:9")!!.records)
    }

    @Test
    fun malformedTokensAreIllegalArguments() {
        val malformed = listOf(
            "", "v1", "v1:", "v1:5", "v1:5:", "v2:5:123", "V1:5:123", ":5:123", "v1::123",
            "v1:x:123", "v1: 5:123", "v1:0:123", "v1:-1:123", "v1:5001:123", "v1:99999999999:123",
            "{hc=123, records=5}",
        )
        for (token in malformed) {
            assertThrows("'$token'", IllegalArgumentException::class.java) { DataPageToken.decode(token) }
        }
    }

    @Test
    fun aReadOfTheAppsOwnRecordsHasTokensOfItsOwn() {
        val token = DataPageToken(5, "a:1", ownOnly = true)
        assertEquals("o1:5:a:1", token.encode())
        assertTrue(DataPageToken.isOwnOnly(token.encode()))

        val decoded = DataPageToken.decode(token.encode())!!
        assertTrue(decoded.ownOnly)
        assertEquals(5, decoded.records)
        assertEquals("a:1", decoded.healthConnectToken)
        // The tokens of other reads are as before.
        val earlier = DataPageToken.decode("v1:37:1712345678901")!!
        assertFalse(earlier.ownOnly)
        assertEquals("v1:37:1712345678901", earlier.encode())
        assertFalse(DataPageToken.isOwnOnly("v1:37:1712345678901"))
        assertFalse(DataPageToken.isOwnOnly("v2:500:100:-:-:-:-"))
        assertFalse(DataPageToken.isOwnOnly(null))
        for (malformed in listOf("o1", "o1:", "o1:5", "o1:5:", "o1:x:1", "o1:0:1", "o1:5001:1", "O1:5:1", "o2:5:1")) {
            assertThrows("'$malformed'", IllegalArgumentException::class.java) { DataPageToken.decode(malformed) }
        }
    }

    @Test
    fun rejectsTokensItCouldNotDecode() {
        assertThrows(IllegalArgumentException::class.java) { DataPageToken(0, "123") }
        assertThrows(IllegalArgumentException::class.java) { DataPageToken(5001, "123") }
        assertThrows(IllegalArgumentException::class.java) { DataPageToken(5, "") }
    }
}
