part of '../../health.dart';

/// The type of a mindfulness session, written with
/// [Health.writeMindfulnessSession].
///
/// These are the session types of Health Connect
/// (`MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_*`). HealthKit's mindful
/// sessions have no type, so iOS does not store it.
enum MindfulnessSessionType {
  /// A session of none of the other types: Health Connect has no "other"
  /// type.
  UNKNOWN,

  /// Meditation.
  MEDITATION,

  /// Breathing exercises.
  BREATHING,

  /// Music or soundscapes.
  MUSIC,

  /// Stretching or other movement.
  MOVEMENT,

  /// Unguided practice.
  UNGUIDED,
}
