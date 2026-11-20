package cachet.plugins.health.reading

import android.os.Build
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.metadata.DataOrigin
import kotlin.reflect.KClass

/**
 * Which records of a type a list read may return, from the app's grants. Health Connect lets an
 * app that may write a type but not read it read the records it wrote itself. Since Android 14
 * QPR2 such a read must ask for this app's records only (a data origin filter of exactly its own
 * package), or Health Connect throws SecurityException("Caller does not have permission to read
 * data for the following (...) from other applications."); it then returns them without the
 * 30-day history limit. HealthKit also returns only the samples an app saved when read access is
 * denied. Aggregates over every app still need the read permission.
 */
internal enum class ReadAccess {
    /** The read permission is granted: every app's records. */
    ALL,

    /** Only the write permission is granted: the records this app wrote. */
    OWN,

    /** Neither is granted: nothing can be read. */
    NONE;

    companion object {
        /** The access that [granted] give to the records of [recordType]. */
        fun of(granted: Set<String>, recordType: KClass<out Record>): ReadAccess = when {
            HealthPermission.getReadPermission(recordType) in granted -> ALL
            HealthPermission.getWritePermission(recordType) in granted -> OWN
            else -> NONE
        }

        /**
         * The data origin filter of a read: [packageName], this app, when [ownOnly], else empty
         * (every app).
         */
        fun origins(ownOnly: Boolean, packageName: String): Set<DataOrigin> =
            if (ownOnly) setOf(DataOrigin(packageName)) else emptySet()

        /**
         * Whether [error] from a read of this app's own records is taken as a missing permission
         * rather than reported: a SecurityException from the Health Connect APK (Android 13 and
         * lower, [sdkInt] below 34), whose source is closed. From Android 14 on, the framework
         * accepts such a read, so a SecurityException there is a real failure.
         */
        fun isOwnReadRefused(error: Throwable, sdkInt: Int): Boolean =
            error is SecurityException && sdkInt < Build.VERSION_CODES.UPSIDE_DOWN_CAKE
    }
}
