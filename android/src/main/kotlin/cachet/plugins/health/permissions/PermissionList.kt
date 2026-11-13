package cachet.plugins.health.permissions

import android.util.Log
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import cachet.plugins.health.HealthConstants
import io.flutter.plugin.common.MethodCall
import kotlin.reflect.KClass

/**
 * The Health Connect permissions for the data types in the 'types' argument of [call], with the
 * access in the 'permissions' argument at the same index, or null if Health Connect does not have
 * one of the types.
 */
internal fun permissionsFor(call: MethodCall): List<String>? {
    val args = call.arguments as HashMap<*, *>
    val types = (args["types"] as? ArrayList<*>)?.filterIsInstance<String>()!!
    val permissions = (args["permissions"] as? ArrayList<*>)?.filterIsInstance<Int>()!!

    val permList = mutableListOf<String>()
    for ((i, typeKey) in types.withIndex()) {
        if (typeKey == HealthConstants.WORKOUT_ROUTE) {
            permList.addAll(workoutRoutePermissions(permissions[i]))
            continue
        }
        val dataType = HealthConstants.mapToType[typeKey]
        if (dataType == null) {
            Log.w("FLUTTER_HEALTH::ERROR", "Datatype $typeKey not found in HC")
            return null
        }
        permList.addAll(dataTypePermissions(dataType, permissions[i]))
    }
    return permList
}

/** The permissions for [dataType] with [access]: 0 read, 1 write, anything else read and write. */
private fun dataTypePermissions(dataType: KClass<out Record>, access: Int): List<String> =
    when (access) {
        0 -> listOf(HealthPermission.getReadPermission(dataType))
        1 -> listOf(HealthPermission.getWritePermission(dataType))
        else -> listOf(HealthPermission.getReadPermission(dataType), HealthPermission.getWritePermission(dataType))
    }

/**
 * The permissions for workout routes with [access], as for [dataTypePermissions]. A route is part
 * of its exercise session: it is read with the session, and written with the session and the
 * exercise route permission.
 */
private fun workoutRoutePermissions(access: Int): List<String> {
    val sessionRead = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
    val sessionWrite = HealthPermission.getWritePermission(ExerciseSessionRecord::class)
    return when (access) {
        0 -> listOf(sessionRead)
        1 -> listOf(HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE, sessionWrite)
        else -> listOf(sessionRead, sessionWrite, HealthPermission.PERMISSION_WRITE_EXERCISE_ROUTE)
    }
}
