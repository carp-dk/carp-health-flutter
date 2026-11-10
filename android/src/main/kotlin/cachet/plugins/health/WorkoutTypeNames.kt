package cachet.plugins.health

/**
 * The generic names of the exercise types that several workout names in
 * [HealthConstants.workoutTypeMap] map to: Health Connect stores CARDIO_DANCE, DANCING and
 * SOCIAL_DANCE all as EXERCISE_TYPE_DANCING, so a read cannot tell which one a workout was written as.
 */
internal val genericWorkoutTypes = setOf("DANCING", "SKIING", "WHEELCHAIR")

/**
 * The workout name of each exercise type in [HealthConstants.workoutTypeMap]: its only name, or its
 * generic name ([genericWorkoutTypes]) when it has several.
 */
private val workoutTypeNames: Map<Int, String> =
    HealthConstants.workoutTypeMap.entries
        .groupBy({ it.value }, { it.key })
        .mapValues { (_, names) -> names.firstOrNull { it in genericWorkoutTypes } ?: names.first() }

/**
 * The workout name that every read reports for [exerciseType] (workouts, workout routes, changes and
 * reads by UUID), OTHER for an exercise type that the plugin has no name for.
 */
internal fun workoutTypeName(exerciseType: Int): String = workoutTypeNames[exerciseType] ?: "OTHER"
