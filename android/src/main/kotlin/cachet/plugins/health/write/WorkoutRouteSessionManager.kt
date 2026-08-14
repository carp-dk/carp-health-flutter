package cachet.plugins.health.write

import androidx.health.connect.client.records.ExerciseRoute
import java.util.UUID

/**
 * In-memory workout route builders keyed by builder ID.
 */
class WorkoutRouteSessionManager {
    private val sessions = mutableMapOf<String, MutableList<ExerciseRoute.Location>>()

    /** Starts a route builder and returns its builder ID. */
    fun start(): String {
        val builderId = UUID.randomUUID().toString()
        sessions[builderId] = mutableListOf()
        return builderId
    }

    /** Appends route locations to an existing builder. */
    fun append(builderId: String, locations: List<ExerciseRoute.Location>): Boolean {
        val session = sessions[builderId] ?: return false
        session.addAll(locations)
        return true
    }

    /** Current route locations for a builder ID. */
    fun locations(builderId: String): List<ExerciseRoute.Location>? = sessions[builderId]

    /** Discards a route builder. */
    fun discard(builderId: String): Boolean = sessions.remove(builderId) != null
}
