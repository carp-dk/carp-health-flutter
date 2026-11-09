package cachet.plugins.health.permissions

import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.StepsRecord
import cachet.plugins.health.HealthConstants
import io.flutter.plugin.common.MethodCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PermissionListTest {
    private val readSteps = HealthPermission.getReadPermission(StepsRecord::class)
    private val writeSteps = HealthPermission.getWritePermission(StepsRecord::class)
    private val readSession = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
    private val writeSession = HealthPermission.getWritePermission(ExerciseSessionRecord::class)
    private val writeRoute = HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE

    // The arguments as the standard message codec decodes them.
    private fun permissions(types: List<String>, access: List<Int>): List<String>? =
        permissionsFor(MethodCall("hasPermissions", hashMapOf("types" to ArrayList(types), "permissions" to ArrayList(access))))

    @Test
    fun accessIsReadWriteOrBoth() {
        assertEquals(listOf(readSteps), permissions(listOf(HealthConstants.STEPS), listOf(0)))
        assertEquals(listOf(writeSteps), permissions(listOf(HealthConstants.STEPS), listOf(1)))
        assertEquals(listOf(readSteps, writeSteps), permissions(listOf(HealthConstants.STEPS), listOf(2)))
    }

    @Test
    fun workoutRoutesAreReadWithTheirSessionAndWrittenWithTheRoutePermission() {
        val route = listOf(HealthConstants.WORKOUT_ROUTE)
        assertEquals(listOf(readSession), permissions(route, listOf(0)))
        assertEquals(listOf(writeRoute, writeSession), permissions(route, listOf(1)))
        assertEquals(listOf(readSession, writeSession, writeRoute), permissions(route, listOf(2)))
    }

    @Test
    fun eachTypeHasTheAccessAtItsIndex() {
        assertEquals(
            listOf(writeSteps, readSession),
            permissions(listOf(HealthConstants.STEPS, HealthConstants.WORKOUT_ROUTE), listOf(1, 0)),
        )
    }

    @Test
    fun cyclingCadenceIsReadWithTheExercisePermission() {
        // Health Connect has no permission of its own for cadence records, so apps declare READ_EXERCISE.
        assertEquals(
            listOf("android.permission.health.READ_POWER", readSession),
            permissions(listOf(HealthConstants.POWER, HealthConstants.CYCLING_CADENCE), listOf(0, 0)),
        )
    }

    @Test
    fun aTypeThatHealthConnectDoesNotHaveFailsTheWholeList() {
        assertNull(permissions(listOf(HealthConstants.STEPS, "AUDIOGRAM"), listOf(0, 0)))
    }
}
