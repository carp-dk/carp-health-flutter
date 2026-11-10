package cachet.plugins.health.writing

import android.util.Log
import androidx.health.connect.client.response.InsertRecordsResponse

/** The id of the first record [response] inserted, or an empty string (logged as an error) if none. */
internal fun firstInsertedId(response: InsertRecordsResponse): String {
    val id = response.recordIdsList.firstOrNull() ?: ""
    if (id.isEmpty()) {
        Log.e("FLUTTER_HEALTH::ERROR", "UUID is empty! No records were inserted.")
    }
    return id
}

/** Logs that adding [what] (e.g. "the workout") to Health Connect failed with [error], and its stack trace. */
internal fun logAddFailed(what: String, error: Exception) {
    Log.w("FLUTTER_HEALTH::ERROR", "[Health Connect] There was an error adding $what", error)
}
