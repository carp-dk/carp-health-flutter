package cachet.plugins.health.reading

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
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
    fun rejectsTokensItCouldNotDecode() {
        assertThrows(IllegalArgumentException::class.java) { DataPageToken(0, "123") }
        assertThrows(IllegalArgumentException::class.java) { DataPageToken(5001, "123") }
        assertThrows(IllegalArgumentException::class.java) { DataPageToken(5, "") }
    }
}
