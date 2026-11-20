/// Which of the plugin's workout activity types each platform writes.
library;

import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';

/// The [HealthWorkoutActivityType]s that `writeWorkoutData` and `writeWorkoutDataUUID` write on each
/// platform. For any other type they throw a `HealthException` with `HealthErrorCode.notSupported`
/// (for example `ARCHERY` on Android or `DANCING` on iOS).
///
/// The plugin keeps these sets private, so they are repeated here from its source; a test checks them
/// against the plugin's own check.
abstract final class WorkoutActivities {
  /// The activity types HealthKit has a workout type for.
  static const Set<HealthWorkoutActivityType> ios = {
    HealthWorkoutActivityType.AMERICAN_FOOTBALL,
    HealthWorkoutActivityType.ARCHERY,
    HealthWorkoutActivityType.AUSTRALIAN_FOOTBALL,
    HealthWorkoutActivityType.BADMINTON,
    HealthWorkoutActivityType.BARRE,
    HealthWorkoutActivityType.BASEBALL,
    HealthWorkoutActivityType.BASKETBALL,
    HealthWorkoutActivityType.BIKING,
    HealthWorkoutActivityType.BOWLING,
    HealthWorkoutActivityType.BOXING,
    HealthWorkoutActivityType.CARDIO_DANCE,
    HealthWorkoutActivityType.CLIMBING,
    HealthWorkoutActivityType.COOLDOWN,
    HealthWorkoutActivityType.CORE_TRAINING,
    HealthWorkoutActivityType.CRICKET,
    HealthWorkoutActivityType.CROSS_COUNTRY_SKIING,
    HealthWorkoutActivityType.CROSS_TRAINING,
    HealthWorkoutActivityType.CURLING,
    HealthWorkoutActivityType.DISC_SPORTS,
    HealthWorkoutActivityType.DOWNHILL_SKIING,
    HealthWorkoutActivityType.ELLIPTICAL,
    HealthWorkoutActivityType.EQUESTRIAN_SPORTS,
    HealthWorkoutActivityType.FENCING,
    HealthWorkoutActivityType.FISHING,
    HealthWorkoutActivityType.FITNESS_GAMING,
    HealthWorkoutActivityType.FLEXIBILITY,
    HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
    HealthWorkoutActivityType.GOLF,
    HealthWorkoutActivityType.GYMNASTICS,
    HealthWorkoutActivityType.HAND_CYCLING,
    HealthWorkoutActivityType.HANDBALL,
    HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
    HealthWorkoutActivityType.HIKING,
    HealthWorkoutActivityType.HOCKEY,
    HealthWorkoutActivityType.HUNTING,
    HealthWorkoutActivityType.JUMP_ROPE,
    HealthWorkoutActivityType.KICKBOXING,
    HealthWorkoutActivityType.LACROSSE,
    HealthWorkoutActivityType.MARTIAL_ARTS,
    HealthWorkoutActivityType.MIND_AND_BODY,
    HealthWorkoutActivityType.MIXED_CARDIO,
    HealthWorkoutActivityType.OTHER,
    HealthWorkoutActivityType.PADDLE_SPORTS,
    HealthWorkoutActivityType.PICKLEBALL,
    HealthWorkoutActivityType.PILATES,
    HealthWorkoutActivityType.PLAY,
    HealthWorkoutActivityType.PREPARATION_AND_RECOVERY,
    HealthWorkoutActivityType.RACQUETBALL,
    HealthWorkoutActivityType.ROCK_CLIMBING,
    HealthWorkoutActivityType.ROWING,
    HealthWorkoutActivityType.RUGBY,
    HealthWorkoutActivityType.RUNNING,
    HealthWorkoutActivityType.RUNNING_TREADMILL,
    HealthWorkoutActivityType.SAILING,
    HealthWorkoutActivityType.SKATING,
    HealthWorkoutActivityType.SNOW_SPORTS,
    HealthWorkoutActivityType.SNOWBOARDING,
    HealthWorkoutActivityType.SOCCER,
    HealthWorkoutActivityType.SOCIAL_DANCE,
    HealthWorkoutActivityType.SOFTBALL,
    HealthWorkoutActivityType.SQUASH,
    HealthWorkoutActivityType.STAIR_CLIMBING,
    HealthWorkoutActivityType.STAIRS,
    HealthWorkoutActivityType.STEP_TRAINING,
    HealthWorkoutActivityType.SURFING,
    HealthWorkoutActivityType.SWIMMING,
    HealthWorkoutActivityType.TABLE_TENNIS,
    HealthWorkoutActivityType.TAI_CHI,
    HealthWorkoutActivityType.TENNIS,
    HealthWorkoutActivityType.TRACK_AND_FIELD,
    HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
    HealthWorkoutActivityType.VOLLEYBALL,
    HealthWorkoutActivityType.WALKING,
    HealthWorkoutActivityType.WATER_FITNESS,
    HealthWorkoutActivityType.WATER_POLO,
    HealthWorkoutActivityType.WATER_SPORTS,
    HealthWorkoutActivityType.WHEELCHAIR_RUN_PACE,
    HealthWorkoutActivityType.WHEELCHAIR_WALK_PACE,
    HealthWorkoutActivityType.WRESTLING,
    HealthWorkoutActivityType.YOGA,
    HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
    HealthWorkoutActivityType.SWIMMING_POOL,
    HealthWorkoutActivityType.UNDERWATER_DIVING,
  };

  /// The activity types Health Connect has an exercise type for.
  static const Set<HealthWorkoutActivityType> android = {
    HealthWorkoutActivityType.AMERICAN_FOOTBALL,
    HealthWorkoutActivityType.AUSTRALIAN_FOOTBALL,
    HealthWorkoutActivityType.BADMINTON,
    HealthWorkoutActivityType.BASEBALL,
    HealthWorkoutActivityType.BASKETBALL,
    HealthWorkoutActivityType.BIKING,
    HealthWorkoutActivityType.BOXING,
    HealthWorkoutActivityType.CARDIO_DANCE,
    HealthWorkoutActivityType.CRICKET,
    HealthWorkoutActivityType.CROSS_COUNTRY_SKIING,
    HealthWorkoutActivityType.DOWNHILL_SKIING,
    HealthWorkoutActivityType.ELLIPTICAL,
    HealthWorkoutActivityType.FENCING,
    HealthWorkoutActivityType.GOLF,
    HealthWorkoutActivityType.GYMNASTICS,
    HealthWorkoutActivityType.HANDBALL,
    HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
    HealthWorkoutActivityType.HIKING,
    HealthWorkoutActivityType.HOCKEY,
    HealthWorkoutActivityType.MARTIAL_ARTS,
    HealthWorkoutActivityType.PADDLE_SPORTS,
    HealthWorkoutActivityType.PILATES,
    HealthWorkoutActivityType.RACQUETBALL,
    HealthWorkoutActivityType.ROWING,
    HealthWorkoutActivityType.RUGBY,
    HealthWorkoutActivityType.RUNNING,
    HealthWorkoutActivityType.SAILING,
    HealthWorkoutActivityType.SKATING,
    HealthWorkoutActivityType.SNOWBOARDING,
    HealthWorkoutActivityType.SOCCER,
    HealthWorkoutActivityType.SOCIAL_DANCE,
    HealthWorkoutActivityType.SOFTBALL,
    HealthWorkoutActivityType.SQUASH,
    HealthWorkoutActivityType.STAIR_CLIMBING,
    HealthWorkoutActivityType.TABLE_TENNIS,
    HealthWorkoutActivityType.TENNIS,
    HealthWorkoutActivityType.VOLLEYBALL,
    HealthWorkoutActivityType.WALKING,
    HealthWorkoutActivityType.WATER_POLO,
    HealthWorkoutActivityType.WHEELCHAIR_RUN_PACE,
    HealthWorkoutActivityType.WHEELCHAIR_WALK_PACE,
    HealthWorkoutActivityType.YOGA,
    HealthWorkoutActivityType.BIKING_STATIONARY,
    HealthWorkoutActivityType.CALISTHENICS,
    HealthWorkoutActivityType.DANCING,
    HealthWorkoutActivityType.FRISBEE_DISC,
    HealthWorkoutActivityType.GUIDED_BREATHING,
    HealthWorkoutActivityType.ICE_SKATING,
    HealthWorkoutActivityType.PARAGLIDING,
    HealthWorkoutActivityType.ROCK_CLIMBING,
    HealthWorkoutActivityType.ROWING_MACHINE,
    HealthWorkoutActivityType.RUNNING_TREADMILL,
    HealthWorkoutActivityType.SCUBA_DIVING,
    HealthWorkoutActivityType.SKIING,
    HealthWorkoutActivityType.SNOWSHOEING,
    HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE,
    HealthWorkoutActivityType.STRENGTH_TRAINING,
    HealthWorkoutActivityType.SURFING,
    HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
    HealthWorkoutActivityType.SWIMMING_POOL,
    HealthWorkoutActivityType.WEIGHTLIFTING,
    HealthWorkoutActivityType.WHEELCHAIR,
    HealthWorkoutActivityType.OTHER,
  };

  /// The swims, which take `SwimmingDetails` and a stroke count. Health Connect has no plain `SWIMMING`.
  static const Set<HealthWorkoutActivityType> swims = {
    HealthWorkoutActivityType.SWIMMING,
    HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
    HealthWorkoutActivityType.SWIMMING_POOL,
  };

  /// The activity types [platform] writes, sorted by [label].
  static List<HealthWorkoutActivityType> on(HealthPlatformType platform) {
    final types = switch (platform) {
      HealthPlatformType.appleHealth => ios,
      HealthPlatformType.googleHealthConnect => android,
    };
    return types.toList()..sort((a, b) => label(a).compareTo(label(b)));
  }

  /// How many of the plugin's activity types [platform] has no workout type for.
  static int missingOn(HealthPlatformType platform) => HealthWorkoutActivityType.values.length - on(platform).length;

  /// Whether [type] is a swim, which takes swimming details.
  static bool isSwim(HealthWorkoutActivityType type) => swims.contains(type);

  /// The name of [type] in words, such as "High intensity interval training".
  static String label(HealthWorkoutActivityType type) => formatEnumName(type);
}
