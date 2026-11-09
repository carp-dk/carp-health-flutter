package cachet.plugins.health.reading

import android.os.RemoteException
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordByIdReaderTest {
    @Test
    fun recordNotFound() {
        // Android 14 and later: readRecord throws RemoteException("No records").
        assertTrue(RecordByIdReader.isRecordNotFound(MessageRemoteException("No records"), 34))
        assertFalse(RecordByIdReader.isRecordNotFound(MessageRemoteException("Binder died"), 36))
        assertFalse(RecordByIdReader.isRecordNotFound(RemoteException(), 34))
        // The Health Connect APK: any RemoteException.
        assertTrue(RecordByIdReader.isRecordNotFound(RemoteException(), 33))
        assertTrue(RecordByIdReader.isRecordNotFound(MessageRemoteException("Binder died"), 28))
        // Anything else is a failure.
        assertFalse(RecordByIdReader.isRecordNotFound(IllegalStateException("No records"), 34))
        assertFalse(RecordByIdReader.isRecordNotFound(SecurityException(), 33))
    }
}

/** android.os.RemoteException drops its message in JVM unit tests. */
private class MessageRemoteException(override val message: String) : RemoteException()
