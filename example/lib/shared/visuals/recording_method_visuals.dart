/// How the example shows a data point's `RecordingMethod`: a name, an icon, a status tone and a short
/// description, used by the recording method filter, the data point tiles and the data point sheet.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

/// Display information for the plugin's [RecordingMethod]s.
///
/// Health Connect stores one of four recording methods with every record. HealthKit only marks the
/// samples a user entered by hand (`HKMetadataKeyWasUserEntered`), which the plugin reads as
/// [RecordingMethod.manual]; it reads the other samples as [RecordingMethod.automatic].
extension RecordingMethodVisuals on RecordingMethod {
  /// The method's name, such as "Manual".
  String get label => switch (this) {
    RecordingMethod.unknown => 'Unknown',
    RecordingMethod.active => 'Active',
    RecordingMethod.automatic => 'Automatic',
    RecordingMethod.manual => 'Manual',
  };

  /// The method's name in at most six letters, for button groups on narrow screens: "Auto" for automatic.
  String get shortLabel => this == RecordingMethod.automatic ? 'Auto' : label;

  /// An icon for the method.
  IconData get icon => switch (this) {
    RecordingMethod.unknown => Icons.help_outline,
    RecordingMethod.active => Icons.play_circle_outline,
    RecordingMethod.automatic => Icons.sensors,
    RecordingMethod.manual => Icons.edit_note,
  };

  /// The tone of the method's status pill: measured data reads as success, entered data as
  /// information and an unknown method as neutral.
  StatusTone get tone => switch (this) {
    RecordingMethod.unknown => StatusTone.neutral,
    RecordingMethod.active || RecordingMethod.automatic => StatusTone.success,
    RecordingMethod.manual => StatusTone.info,
  };

  /// What the method means, in a short sentence for tooltips and info sheets.
  String get description => switch (this) {
    RecordingMethod.unknown => 'Not reported by the writing app.',
    RecordingMethod.active => 'Recorded in a session the user started.',
    RecordingMethod.automatic => 'Recorded in the background, such as by a watch.',
    RecordingMethod.manual => 'Entered by hand.',
  };
}
