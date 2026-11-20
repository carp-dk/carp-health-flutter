/// Where the plugin decodes and parses read replies, `Health.isolateMode`, in a connected button group.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/design/design.dart';

import '../../widgets/card_heading.dart';

/// The words and icon the Setup page shows for each [HealthIsolateMode] (README, "Where parsing runs").
extension HealthIsolateModeText on HealthIsolateMode {
  /// The mode's name on its segment.
  String get label => switch (this) {
    HealthIsolateMode.auto => 'Auto',
    HealthIsolateMode.worker => 'Worker',
    HealthIsolateMode.inline => 'Inline',
  };

  /// An icon for the mode.
  IconData get icon => switch (this) {
    HealthIsolateMode.auto => Icons.auto_mode,
    HealthIsolateMode.worker => Icons.call_split,
    HealthIsolateMode.inline => Icons.linear_scale,
  };

  /// Where the mode decodes and parses a reply, after its [label] in the info button.
  String get description => switch (this) {
    HealthIsolateMode.auto =>
      'replies of 64 KiB or more parse in a short-lived worker isolate, smaller ones and calls from '
          'background isolates inline (the default).',
    HealthIsolateMode.worker => 'every reply parses in a worker isolate.',
    HealthIsolateMode.inline => 'every reply parses in the calling isolate.',
  };
}

/// The isolate modes as a [ConnectedButtonGroup] that sets `Health.isolateMode` (through [settings]);
/// what each mode does sits behind the info button. The platform call itself always runs on the calling
/// isolate.
class IsolateModeCard extends StatelessWidget {
  /// Creates the card that edits [settings].
  const IsolateModeCard({super.key, required this.settings});

  /// The plugin's read settings.
  final PluginSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          CardHeading(
            icon: ShapedIcon(
              icon: Icons.memory,
              shape: ExpressiveShape.softBurst,
              size: 44,
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
            ),
            title: 'Parsing',
          ),
          ConnectedButtonGroup<HealthIsolateMode>(
            segments: [
              for (final value in HealthIsolateMode.values)
                ButtonGroupSegment(value: value, label: value.label, icon: value.icon),
            ],
            selected: settings.isolateMode,
            onSelected: (value) => settings.isolateMode = value,
          ),
        ],
      ),
    );
  }
}
