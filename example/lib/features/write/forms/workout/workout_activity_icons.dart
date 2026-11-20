/// Icons for the plugin's workout activity types.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// A Material icon for each [HealthWorkoutActivityType], for the workout form's activity picker and
/// preview.
extension WorkoutActivityIcon on HealthWorkoutActivityType {
  /// The icon of this activity; a generic sports icon where Material has nothing closer.
  IconData get icon => switch (this) {
    HealthWorkoutActivityType.RUNNING ||
    HealthWorkoutActivityType.RUNNING_TREADMILL ||
    HealthWorkoutActivityType.TRACK_AND_FIELD => Icons.directions_run,
    HealthWorkoutActivityType.WALKING || HealthWorkoutActivityType.WALKING_TREADMILL => Icons.directions_walk,
    HealthWorkoutActivityType.HIKING || HealthWorkoutActivityType.SNOWSHOEING => Icons.hiking,
    HealthWorkoutActivityType.BIKING ||
    HealthWorkoutActivityType.BIKING_STATIONARY ||
    HealthWorkoutActivityType.HAND_CYCLING => Icons.directions_bike,
    HealthWorkoutActivityType.SWIMMING ||
    HealthWorkoutActivityType.SWIMMING_POOL ||
    HealthWorkoutActivityType.SWIMMING_OPEN_WATER ||
    HealthWorkoutActivityType.WATER_FITNESS ||
    HealthWorkoutActivityType.WATER_POLO => Icons.pool,
    HealthWorkoutActivityType.UNDERWATER_DIVING || HealthWorkoutActivityType.SCUBA_DIVING => Icons.scuba_diving,
    HealthWorkoutActivityType.ROWING || HealthWorkoutActivityType.ROWING_MACHINE => Icons.rowing,
    HealthWorkoutActivityType.PADDLE_SPORTS || HealthWorkoutActivityType.WATER_SPORTS => Icons.kayaking,
    HealthWorkoutActivityType.SAILING => Icons.sailing,
    HealthWorkoutActivityType.SURFING => Icons.surfing,
    HealthWorkoutActivityType.DOWNHILL_SKIING ||
    HealthWorkoutActivityType.SKIING ||
    HealthWorkoutActivityType.SNOW_SPORTS => Icons.downhill_skiing,
    HealthWorkoutActivityType.CROSS_COUNTRY_SKIING => Icons.nordic_walking,
    HealthWorkoutActivityType.SNOWBOARDING => Icons.snowboarding,
    HealthWorkoutActivityType.SKATING => Icons.roller_skating,
    HealthWorkoutActivityType.ICE_SKATING || HealthWorkoutActivityType.CURLING => Icons.ice_skating,
    HealthWorkoutActivityType.YOGA ||
    HealthWorkoutActivityType.MIND_AND_BODY ||
    HealthWorkoutActivityType.TAI_CHI ||
    HealthWorkoutActivityType.FLEXIBILITY ||
    HealthWorkoutActivityType.PILATES ||
    HealthWorkoutActivityType.BARRE => Icons.self_improvement,
    HealthWorkoutActivityType.GUIDED_BREATHING ||
    HealthWorkoutActivityType.COOLDOWN ||
    HealthWorkoutActivityType.PREPARATION_AND_RECOVERY => Icons.air,
    HealthWorkoutActivityType.STRENGTH_TRAINING ||
    HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING ||
    HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING ||
    HealthWorkoutActivityType.WEIGHTLIFTING ||
    HealthWorkoutActivityType.CORE_TRAINING ||
    HealthWorkoutActivityType.CALISTHENICS ||
    HealthWorkoutActivityType.CROSS_TRAINING => Icons.fitness_center,
    HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING ||
    HealthWorkoutActivityType.MIXED_CARDIO ||
    HealthWorkoutActivityType.JUMP_ROPE ||
    HealthWorkoutActivityType.STEP_TRAINING ||
    HealthWorkoutActivityType.ELLIPTICAL => Icons.monitor_heart,
    HealthWorkoutActivityType.STAIR_CLIMBING ||
    HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE ||
    HealthWorkoutActivityType.STAIRS => Icons.stairs,
    HealthWorkoutActivityType.CLIMBING || HealthWorkoutActivityType.ROCK_CLIMBING => Icons.landscape,
    HealthWorkoutActivityType.DANCING ||
    HealthWorkoutActivityType.CARDIO_DANCE ||
    HealthWorkoutActivityType.SOCIAL_DANCE => Icons.music_note,
    HealthWorkoutActivityType.BOXING ||
    HealthWorkoutActivityType.KICKBOXING ||
    HealthWorkoutActivityType.MARTIAL_ARTS ||
    HealthWorkoutActivityType.FENCING => Icons.sports_martial_arts,
    HealthWorkoutActivityType.WRESTLING => Icons.sports_kabaddi,
    HealthWorkoutActivityType.GYMNASTICS => Icons.sports_gymnastics,
    HealthWorkoutActivityType.SOCCER || HealthWorkoutActivityType.AUSTRALIAN_FOOTBALL => Icons.sports_soccer,
    HealthWorkoutActivityType.AMERICAN_FOOTBALL => Icons.sports_football,
    HealthWorkoutActivityType.RUGBY => Icons.sports_rugby,
    HealthWorkoutActivityType.BASKETBALL => Icons.sports_basketball,
    HealthWorkoutActivityType.BASEBALL || HealthWorkoutActivityType.SOFTBALL => Icons.sports_baseball,
    HealthWorkoutActivityType.CRICKET => Icons.sports_cricket,
    HealthWorkoutActivityType.VOLLEYBALL => Icons.sports_volleyball,
    HealthWorkoutActivityType.HANDBALL => Icons.sports_handball,
    HealthWorkoutActivityType.HOCKEY || HealthWorkoutActivityType.LACROSSE => Icons.sports_hockey,
    HealthWorkoutActivityType.GOLF => Icons.sports_golf,
    HealthWorkoutActivityType.TENNIS ||
    HealthWorkoutActivityType.TABLE_TENNIS ||
    HealthWorkoutActivityType.BADMINTON ||
    HealthWorkoutActivityType.SQUASH ||
    HealthWorkoutActivityType.RACQUETBALL ||
    HealthWorkoutActivityType.PICKLEBALL => Icons.sports_tennis,
    HealthWorkoutActivityType.WHEELCHAIR ||
    HealthWorkoutActivityType.WHEELCHAIR_RUN_PACE ||
    HealthWorkoutActivityType.WHEELCHAIR_WALK_PACE => Icons.accessible_forward,
    HealthWorkoutActivityType.PARAGLIDING => Icons.paragliding,
    HealthWorkoutActivityType.FISHING => Icons.phishing,
    HealthWorkoutActivityType.FITNESS_GAMING => Icons.sports_esports,
    HealthWorkoutActivityType.FRISBEE_DISC || HealthWorkoutActivityType.DISC_SPORTS => Icons.album,
    _ => Icons.sports,
  };
}
