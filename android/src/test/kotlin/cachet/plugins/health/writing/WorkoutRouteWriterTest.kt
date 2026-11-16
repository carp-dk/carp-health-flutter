package cachet.plugins.health.writing

import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Length
import java.time.Instant
import java.time.ZoneOffset
import org.junit.Assert.assertEquals
import org.junit.Test

class WorkoutRouteWriterTest {
    private val start = 1_700_000_000_000L

    private fun at(seconds: Long): Instant = Instant.ofEpochMilli(start + seconds * 1000)

    @Test
    fun theSessionWithARouteKeepsEveryOtherField() {
        val session = ExerciseSessionRecord(
            startTime = at(0),
            startZoneOffset = ZoneOffset.ofHours(1),
            endTime = at(1800),
            endZoneOffset = ZoneOffset.ofHours(2),
            metadata = Metadata.manualEntry(clientRecordId = "swim-1", clientRecordVersion = 3),
            exerciseType = ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL,
            title = "Morning swim",
            notes = "Felt good",
            segments = listOf(
                ExerciseSegment(at(0), at(600), ExerciseSegment.EXERCISE_SEGMENT_TYPE_SWIMMING_BACKSTROKE),
            ),
            laps = listOf(ExerciseLap(at(0), at(600), Length.meters(25.0))),
            plannedExerciseSessionId = "plan-1",
            rateOfPerceivedExertion = 7f,
        )
        val route = ExerciseRoute(listOf(ExerciseRoute.Location(at(60), 55.68, 12.57)))

        val withRoute = session.withRoute(route)

        assertEquals(ExerciseRouteResult.Data(route), withRoute.exerciseRouteResult)
        val expected = ExerciseSessionRecord(
            startTime = session.startTime,
            startZoneOffset = session.startZoneOffset,
            endTime = session.endTime,
            endZoneOffset = session.endZoneOffset,
            metadata = session.metadata,
            exerciseType = session.exerciseType,
            title = session.title,
            notes = session.notes,
            segments = session.segments,
            laps = session.laps,
            exerciseRoute = route,
            plannedExerciseSessionId = session.plannedExerciseSessionId,
            rateOfPerceivedExertion = session.rateOfPerceivedExertion,
        )
        // equals compares every field of the record, the route included.
        assertEquals(expected, withRoute)
        assertEquals(7f, withRoute.rateOfPerceivedExertion)
        assertEquals("plan-1", withRoute.plannedExerciseSessionId)
    }
}
