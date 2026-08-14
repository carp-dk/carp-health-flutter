package cachet.plugins.health

import android.util.Log
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord

/**
 * Maps Flutter permission requests to Health Connect permission strings.
 */
object HealthPermissionMapper {
    /** Health Connect permissions for the requested Flutter data types and access modes. */
    fun prepare(types: List<String>, permissions: List<Int>): List<String>? {
        val permList = mutableListOf<String>()
        for ((index, typeKey) in types.withIndex()) {
            if (index >= permissions.size) return null
            if (typeKey == HealthConstants.WORKOUT_ROUTE) {
                addWorkoutRoutePermissions(permissions[index], permList)
                continue
            }
            val dataType = HealthConstants.mapToType[typeKey]
            if (dataType == null) {
                Log.w("FLUTTER_HEALTH::ERROR", "Datatype $typeKey not found in HC")
                return null
            }
            when (permissions[index]) {
                0 -> permList.add(HealthPermission.getReadPermission(dataType))
                1 -> permList.add(HealthPermission.getWritePermission(dataType))
                else -> permList.addAll(
                    listOf(
                        HealthPermission.getReadPermission(dataType),
                        HealthPermission.getWritePermission(dataType),
                    )
                )
            }
        }
        return permList
    }

    private fun addWorkoutRoutePermissions(access: Int, permList: MutableList<String>) {
        val sessionRead = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        val sessionWrite = HealthPermission.getWritePermission(ExerciseSessionRecord::class)
        when (access) {
            0 -> permList.add(sessionRead)
            1 -> {
                permList.add(HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE)
                permList.add(sessionWrite)
            }
            else -> {
                permList.add(sessionRead)
                permList.add(sessionWrite)
                permList.add(HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE)
            }
        }
    }
}
