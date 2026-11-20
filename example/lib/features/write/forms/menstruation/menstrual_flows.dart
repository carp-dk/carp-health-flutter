/// Which menstrual flows the Menstruation flow form offers on each platform, and how it shows them.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/features/write/forms/form_kit/choice_tiles.dart';

/// The [MenstrualFlow]s that `writeMenstruationFlow` writes as themselves on each platform.
abstract final class MenstrualFlows {
  /// The flows of Health Connect (`MenstruationFlowRecord.FLOW_*`). It has no "none" or "spotting" flow:
  /// `MenstrualFlow.toHealthConnect` maps them to -1, for which the plugin throws an `ArgumentError`.
  static const List<MenstrualFlow> android = [
    MenstrualFlow.unspecified,
    MenstrualFlow.light,
    MenstrualFlow.medium,
    MenstrualFlow.heavy,
  ];

  /// The flows that reach HealthKit as themselves. The plugin sends a flow's `index` as HealthKit's
  /// `HKCategoryValueMenstrualFlow`, whose values run from unspecified (1) to none (5): light, medium and
  /// heavy line up, while unspecified (index 0) is no HealthKit value and fails, none is saved as
  /// unspecified and spotting as none.
  static const List<MenstrualFlow> ios = [MenstrualFlow.light, MenstrualFlow.medium, MenstrualFlow.heavy];

  /// The flows the form offers on [platform].
  static List<MenstrualFlow> on(HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect => android,
    HealthPlatformType.appleHealth => ios,
  };
}

/// A name, an icon and the choice tile of each [MenstrualFlow].
extension MenstrualFlowVisuals on MenstrualFlow {
  /// The flow's name, such as "Medium".
  String get label => switch (this) {
    MenstrualFlow.unspecified => 'Unspecified',
    MenstrualFlow.none => 'None',
    MenstrualFlow.light => 'Light',
    MenstrualFlow.medium => 'Medium',
    MenstrualFlow.heavy => 'Heavy',
    MenstrualFlow.spotting => 'Spotting',
  };

  /// An icon for the flow: an empty, a part-filled and a full drop for light, medium and heavy.
  IconData get icon => switch (this) {
    MenstrualFlow.unspecified => Icons.help_outline,
    MenstrualFlow.none => Icons.block,
    MenstrualFlow.light => Icons.water_drop_outlined,
    MenstrualFlow.medium => Icons.opacity,
    MenstrualFlow.heavy => Icons.water_drop,
    MenstrualFlow.spotting => Icons.grain,
  };

  /// The choice tile of this flow, for the form's flow picker.
  ChoiceTile<MenstrualFlow> get tile => ChoiceTile(value: this, label: label, icon: icon);
}
