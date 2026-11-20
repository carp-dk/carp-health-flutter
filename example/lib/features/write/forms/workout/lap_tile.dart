/// One lap in the workout form's lap editor.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/form_kit/duration_stepper.dart';

import 'swim_laps.dart';
import 'workout_form_controller.dart';

/// Lap [index] of [controller]'s swim: its number, its stroke style (a menu), when it starts, its
/// duration with buttons that shorten or lengthen it, and a button that removes it.
class LapTile extends StatelessWidget {
  /// Creates the tile of lap [index].
  const LapTile({super.key, required this.controller, required this.index});

  /// The workout form's state.
  final WorkoutFormController controller;

  /// The lap's position, from 0.
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lap = controller.laps[index];
    final number = index + 1;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Row(
            spacing: 12,
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: scheme.secondaryContainer,
                  shape: const ExpressiveShapeBorder(shape: ExpressiveShape.cookie6),
                ),
                child: SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: Text(
                      '$number',
                      style: theme.textTheme.labelLargeEmphasized.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _StrokeStyleMenu(controller: controller, index: index, lap: lap),
              ),
              IconButton(
                tooltip: 'Remove lap $number',
                onPressed: () => controller.removeLap(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'From ${formatTime(controller.lapStart(index), withSeconds: true)}',
                  style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              DurationStepper(
                value: lap.duration,
                step: SwimLaps.step,
                min: SwimLaps.shortest,
                max: SwimLaps.longest,
                label: 'lap $number',
                onChanged: (duration) => controller.updateLap(index, lap.copyWith(duration: duration)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The stroke style of a lap, as a menu of the plugin's `SwimmingStrokeStyle`s.
class _StrokeStyleMenu extends StatelessWidget {
  const _StrokeStyleMenu({required this.controller, required this.index, required this.lap});

  final WorkoutFormController controller;
  final int index;
  final LapDraft lap;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SwimmingStrokeStyle>(
      tooltip: 'Stroke style of lap ${index + 1}',
      initialValue: lap.strokeStyle,
      onSelected: (style) => controller.updateLap(index, lap.copyWith(strokeStyle: style)),
      itemBuilder: (context) => [
        for (final style in SwimmingStrokeStyle.values)
          PopupMenuItem<SwimmingStrokeStyle>(value: style, child: Text(formatEnumName(style))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          spacing: 4,
          children: [
            Flexible(
              child: Text(
                formatEnumName(lap.strokeStyle),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
