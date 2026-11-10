package cachet.plugins.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.metadata.Metadata
import cachet.plugins.health.reading.WorkoutConverter
import cachet.plugins.health.reading.WorkoutRoutes
import java.time.Instant
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WorkoutTypeNamesTest {
    private val workoutTypes = HealthConstants.workoutTypeMap
    private val start = Instant.parse("2026-11-08T10:00:00Z")

    @Test
    fun everyNameReadsBackAsItselfOrAsTheGenericNameOfItsExerciseType() {
        for ((name, exerciseType) in workoutTypes) {
            val readBack = workoutTypeName(exerciseType)
            assertEquals(name, exerciseType, workoutTypes[readBack])
            assertTrue("$name reads back as $readBack", readBack == name || readBack in genericWorkoutTypes)
        }
    }

    @Test
    fun namesThatShareAnExerciseTypeReadBackAsTheGenericName() {
        val shared = mapOf(
            "DANCING" to listOf("CARDIO_DANCE", "DANCING", "SOCIAL_DANCE"),
            "SKIING" to listOf("CROSS_COUNTRY_SKIING", "DOWNHILL_SKIING", "SKIING"),
            "WHEELCHAIR" to listOf("WHEELCHAIR", "WHEELCHAIR_RUN_PACE", "WHEELCHAIR_WALK_PACE"),
        )
        for ((generic, names) in shared) {
            for (name in names) assertEquals(name, generic, workoutTypeName(workoutTypes.getValue(name)))
        }
    }

    @Test
    fun everyExerciseTypeOfSeveralNamesHasOneGenericName() {
        val shared = workoutTypes.entries.groupBy({ it.value }, { it.key }).values.filter { it.size > 1 }
        for (names in shared) assertEquals("$names", 1, names.count { it in genericWorkoutTypes })
        // And every generic name is the name of such an exercise type.
        assertEquals(genericWorkoutTypes, shared.flatten().filter { it in genericWorkoutTypes }.toSet())
    }

    @Test
    fun anExerciseTypeOfOneNameReadsUnderThatName() {
        // Stationary biking is an exercise type of its own in Health Connect, not a kind of BIKING. Ice hockey
        // and paddling read under the HealthKit names that they are written from.
        val names = mapOf(
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING to "BIKING",
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY to "BIKING_STATIONARY",
            ExerciseSessionRecord.EXERCISE_TYPE_ICE_HOCKEY to "HOCKEY",
            ExerciseSessionRecord.EXERCISE_TYPE_PADDLING to "PADDLE_SPORTS",
            ExerciseSessionRecord.EXERCISE_TYPE_SOCCER to "SOCCER",
        )
        for ((exerciseType, name) in names) assertEquals(name, workoutTypeName(exerciseType))
    }

    @Test
    fun anExerciseTypeWithoutANameReadsAsOther() {
        assertEquals("OTHER", workoutTypeName(ExerciseSessionRecord.EXERCISE_TYPE_BOOT_CAMP))
        assertEquals("OTHER", workoutTypeName(ExerciseSessionRecord.EXERCISE_TYPE_OTHER_WORKOUT))
        // HOCKEY is written as ice hockey, so roller hockey has no name.
        assertEquals("OTHER", workoutTypeName(ExerciseSessionRecord.EXERCISE_TYPE_ROLLER_HOCKEY))
    }

    @Test
    fun everyReaderNamesAWorkoutTheSame() {
        // A workout of each exercise type that the plugin has a name for, and of one that it has none for.
        val exerciseTypes = workoutTypes.values.distinct() + ExerciseSessionRecord.EXERCISE_TYPE_BOOT_CAMP
        val sessions = exerciseTypes.map { session(it) }
        val expected = exerciseTypes.map { workoutTypeName(it) }

        // Workouts, also read by UUID. Without permission to read the totals, nothing else is read.
        val workouts = mutableListOf<Map<String, Any?>>()
        val converter = WorkoutConverter(fakeOf<HealthConnectClient> { error("Unexpected call of $it") }, HealthRecordingFilter())
        runBlocking { converter.handleWorkoutData(sessions, emptyList(), workouts, emptySet()) }
        assertEquals(expected, workouts.map { it["workoutActivityType"] })

        // Workout routes, also read by UUID, with and without the consent to read them.
        val routes = WorkoutRoutes(HealthRecordingFilter())
        val route = ExerciseRoute(listOf(ExerciseRoute.Location(start, 55.78, 12.52)))
        assertEquals(expected, sessions.map { routes.buildWorkoutRouteMap(it, route)!!.routeActivityType() })
        assertEquals(expected, sessions.map { routes.buildConsentRequiredRouteMap(it).routeActivityType() })

        assertEquals(expected, changedDataPoints(sessions).map { it["workoutActivityType"] })
    }

    private fun session(exerciseType: Int) = ExerciseSessionRecord(
        startTime = start,
        startZoneOffset = null,
        endTime = start.plusSeconds(1800),
        endZoneOffset = null,
        metadata = Metadata.manualEntry(),
        exerciseType = exerciseType,
    )

    private fun Map<String, Any?>.routeActivityType() = (this["metadata"] as Map<*, *>)["workout_activity_type"]
}
