/// The swimming part of the workout form: pool length, laps and stroke count (`SwimmingDetails`).
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/common/form_section.dart';
import 'package:health_example/features/write/forms/form_kit/form_note.dart';
import 'package:health_example/features/write/forms/form_kit/platform_section.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'lap_tile.dart';
import 'swim_laps.dart';
import 'workout_form_controller.dart';

/// The `swimming` argument of a swim: the pool length of a pool swim (with 25 and 50 m presets) and a lap
/// editor, where each lap has a stroke style and a duration and the laps follow each other from the
/// workout's start; then the stroke count, which only HealthKit stores.
///
/// It warns in one line when the laps run past the workout's end, which the plugin rejects with an
/// `ArgumentError`; its info sheet says what each platform stores of the stroke styles (README, "Swimming
/// workouts").
class SwimmingSection extends StatelessWidget {
  /// Creates the section for [controller]'s swim.
  const SwimmingSection({super.key, required this.controller});

  /// The workout form's state.
  final WorkoutFormController controller;

  @override
  Widget build(BuildContext context) {
    final laps = controller.laps;
    final pool = controller.pool;
    final distance = controller.lapDistance;
    const motion = ExpressiveMotion.spatialDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        FormSection(
          title: 'Swimming',
          parameter: 'swimming: SwimmingDetails(poolLength, laps)',
          caption: _caption(controller.capabilities.isIOS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              if (controller.isPoolSwim) ...[
                NumberField(
                  label: 'Pool length',
                  controller: controller.poolLength,
                  unit: 'm',
                  isRequired: false,
                  onChanged: (_) => controller.textChanged(),
                ),
                ConnectedButtonGroup<double?>(
                  segments: [
                    for (final preset in SwimLaps.poolPresets)
                      ButtonGroupSegment<double?>(value: preset, label: '${formatNumber(preset)} m', icon: Icons.pool),
                  ],
                  selected: SwimLaps.poolPresets.contains(pool) ? pool : null,
                  onSelected: (meters) => controller.setPoolLength(meters!),
                ),
              ],
              AnimatedSize(
                duration: motion.duration,
                curve: motion,
                alignment: Alignment.topCenter,
                child: laps.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : SegmentedList(
                        children: [for (var i = 0; i < laps.length; i++) LapTile(controller: controller, index: i)],
                      ),
              ),
              if (controller.lapsOverrun)
                FormNote(
                  warning: true,
                  icon: Icons.warning_amber,
                  text:
                      'Laps last ${formatDuration(controller.lapsDuration)}, the workout '
                      '${formatDuration(controller.workoutDuration)}',
                ),
              _LapActions(controller: controller, distance: distance),
            ],
          ),
        ),
        PlatformSection(
          title: 'Stroke count',
          parameter: 'totalSwimmingStrokeCount',
          onlyOn: HealthPlatformType.appleHealth,
          caption: "HealthKit's stroke total, read back as totalSwimmingStrokeCount.",
          note: 'Health Connect has no stroke count.',
          child: NumberField(label: 'Strokes', controller: controller.strokeCount, decimal: false, isRequired: false),
        ),
      ],
    );
  }

  /// The rules of the laps and the pool length, and what the platform stores of the stroke styles.
  static String _caption(bool iOS) {
    const rules =
        'Laps are optional, run back to back from the start and must end within the workout; a pool is '
        'up to 1000 m. ';
    return rules +
        (iOS
            ? 'HealthKit saves each lap with its stroke style (kickboard needs iOS 16; other becomes unknown).'
            : 'Health Connect saves stroke styles as segments (unknown saves none; kickboard reads back as other).');
  }
}

/// The buttons under the laps: add a lap, the sample laps, fit the laps into the workout, and use their
/// distance as the workout's.
class _LapActions extends StatelessWidget {
  const _LapActions({required this.controller, required this.distance});

  final WorkoutFormController controller;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(onPressed: controller.addLap, icon: const Icon(Icons.add), label: const Text('Add lap')),
        if (controller.laps.isEmpty)
          OutlinedButton.icon(
            onPressed: controller.useSampleLaps,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Sample laps'),
          ),
        if (controller.lapsOverrun)
          OutlinedButton.icon(
            onPressed: controller.fitLaps,
            icon: const Icon(Icons.compress),
            label: const Text('Fit to workout'),
          ),
        if (distance case final meters?)
          OutlinedButton.icon(
            onPressed: controller.useLapDistance,
            icon: const Icon(Icons.straighten),
            label: Text('Set distance: ${formatNumber(meters)} m'),
          ),
      ],
    );
  }
}
