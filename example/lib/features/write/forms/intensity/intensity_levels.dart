/// How the Activity intensity form shows the plugin's `ActivityIntensityLevel`s.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/features/write/forms/form_kit/choice_tiles.dart';

/// A name and the choice tile of each [ActivityIntensityLevel].
extension ActivityIntensityLevelVisuals on ActivityIntensityLevel {
  /// The level's name, such as "Moderate".
  String get label => switch (this) {
    ActivityIntensityLevel.moderate => 'Moderate',
    ActivityIntensityLevel.vigorous => 'Vigorous',
    ActivityIntensityLevel.unknown => 'Unknown',
  };

  /// The choice tile of this level.
  ChoiceTile<ActivityIntensityLevel> get tile => ChoiceTile(
    value: this,
    label: label,
    icon: switch (this) {
      ActivityIntensityLevel.moderate => Icons.directions_walk,
      ActivityIntensityLevel.vigorous => Icons.directions_run,
      ActivityIntensityLevel.unknown => Icons.help_outline,
    },
  );
}
