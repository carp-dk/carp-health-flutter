/// How the Mindfulness form shows the plugin's `MindfulnessSessionType`s.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/features/write/forms/form_kit/choice_tiles.dart';

/// A name, an icon and the choice tile of each [MindfulnessSessionType], the session types of
/// Health Connect (`MindfulnessSessionRecord.MINDFULNESS_SESSION_TYPE_*`).
extension MindfulnessSessionTypeVisuals on MindfulnessSessionType {
  /// The type's name, such as "Breathing".
  String get label => switch (this) {
    MindfulnessSessionType.UNKNOWN => 'Unknown',
    MindfulnessSessionType.MEDITATION => 'Meditation',
    MindfulnessSessionType.BREATHING => 'Breathing',
    MindfulnessSessionType.MUSIC => 'Music',
    MindfulnessSessionType.MOVEMENT => 'Movement',
    MindfulnessSessionType.UNGUIDED => 'Unguided',
  };

  /// An icon for the type.
  IconData get icon => switch (this) {
    MindfulnessSessionType.UNKNOWN => Icons.help_outline,
    MindfulnessSessionType.MEDITATION => Icons.self_improvement,
    MindfulnessSessionType.BREATHING => Icons.air,
    MindfulnessSessionType.MUSIC => Icons.headphones,
    MindfulnessSessionType.MOVEMENT => Icons.accessibility_new,
    MindfulnessSessionType.UNGUIDED => Icons.spa_outlined,
  };

  /// The choice tile of this type, for the form's type picker.
  ChoiceTile<MindfulnessSessionType> get tile => ChoiceTile(value: this, label: label, icon: icon);
}
