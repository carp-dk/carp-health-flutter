/// Chooses the recording methods a read leaves out: the `recordingMethodsToFilter` argument of
/// `getHealthDataFromTypes` and `getHealthDataPages`.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/shared/scope_lookup.dart';
import 'package:health_example/shared/visuals/recording_method_visuals.dart';

/// Filter chips, one per recording method, selected when data recorded that way is included. Tapping a
/// chip reports the new set of methods to leave out ([filtered]) through [onChanged].
///
/// The chips follow the platform's rules (README, "Filtering by recording method"):
/// * Health Connect stores one of four methods with every record, so each of them can be left out.
/// * HealthKit only marks the samples a user entered by hand, so on iOS only manual entries can be
///   left out: the other samples read as automatic whatever the filter says, and the Automatic chip
///   stays selected and disabled.
class RecordingMethodFilter extends StatelessWidget {
  /// Creates a filter showing [filtered] as left out.
  const RecordingMethodFilter({super.key, required this.filtered, required this.onChanged, this.platform});

  /// The methods the read leaves out (`recordingMethodsToFilter`).
  final Set<RecordingMethod> filtered;

  /// Called with the methods to leave out after the user tapped a chip.
  final ValueChanged<Set<RecordingMethod>> onChanged;

  /// The platform whose rules apply; the app's platform by default.
  final HealthPlatformType? platform;

  /// The methods a read on [platform] can leave out.
  static List<RecordingMethod> filterableOn(HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect => const [
      RecordingMethod.automatic,
      RecordingMethod.active,
      RecordingMethod.manual,
      RecordingMethod.unknown,
    ],
    HealthPlatformType.appleHealth => const [RecordingMethod.manual],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final platform = this.platform ?? healthPlatformOf(context);
    final filterable = filterableOn(platform);
    final isIOS = platform == HealthPlatformType.appleHealth;
    final shown = isIOS ? const [RecordingMethod.automatic, RecordingMethod.manual] : filterable;
    // On iOS automatic samples always remain, so only Android can leave everything out.
    final nothingLeft = !isIOS && filterable.every(filtered.contains);
    final (icon, color, note) = switch ((nothingLeft, isIOS)) {
      (true, _) => (Icons.warning_amber, scheme.error, 'Every recording method is left out, so reads return no data.'),
      (false, true) => (
        Icons.info_outline,
        scheme.onSurfaceVariant,
        'HealthKit marks only the samples a user entered by hand, so iOS can leave out manual entries only.',
      ),
      (false, false) => (
        Icons.info_outline,
        scheme.onSurfaceVariant,
        'Health Connect stores how each record was made. Some apps write manual entries as unknown.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Include data recorded as', style: theme.textTheme.labelLarge!.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in shown)
              FilterChip(
                label: Text(method.label),
                tooltip: method.description,
                // A method the platform cannot leave out is always included.
                selected: !filterable.contains(method) || !filtered.contains(method),
                onSelected: filterable.contains(method) ? (include) => onChanged(_toggled(method, include)) : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _Note(icon: icon, color: color, text: note),
      ],
    );
  }

  /// [filtered] with [method] included again, or left out.
  Set<RecordingMethod> _toggled(RecordingMethod method, bool include) =>
      include ? ({...filtered}..remove(method)) : {...filtered, method};
}

/// A small icon and a line of explanation.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: color),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: color)),
        ),
      ],
    );
  }
}
