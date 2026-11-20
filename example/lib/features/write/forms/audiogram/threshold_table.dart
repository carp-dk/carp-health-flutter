/// The Audiogram form's editor of frequencies and hearing thresholds.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/form_kit/form_note.dart';
import 'package:health_example/features/write/forms/form_kit/number_stepper.dart';

import 'audiogram_controller.dart';
import 'audiogram_points.dart';

/// The frequencies of [controller]'s audiogram as chips that test or skip each, and a row per tested
/// frequency with each ear's threshold between minus and plus buttons, in 5 dB steps.
///
/// Choosing frequencies from a fixed list keeps them unique and in ascending order, and the steppers keep
/// the thresholds within HealthKit's range, as `writeAudiogram` requires. Without any frequency a one-line
/// warning asks for one, as the plugin throws an `ArgumentError` for none.
class ThresholdTable extends StatelessWidget {
  /// Creates the editor of [controller]'s audiogram.
  const ThresholdTable({super.key, required this.controller});

  /// The form's state.
  final AudiogramController controller;

  @override
  Widget build(BuildContext context) {
    final points = controller.points;
    const motion = ExpressiveMotion.spatialDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final frequency in AudiogramPlan.frequencies)
              FilterChip(
                label: Text(frequencyLabel(frequency)),
                selected: controller.tests(frequency),
                onSelected: (_) => controller.toggleFrequency(frequency),
              ),
          ],
        ),
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: points.isEmpty
              ? const FormNote(warning: true, icon: Icons.hearing_disabled, text: 'Pick at least one frequency')
              : SegmentedList(
                  children: [for (final point in points) _ThresholdRow(point: point, controller: controller)],
                ),
        ),
      ],
    );
  }
}

/// One tested frequency: its label and each ear's threshold, side by side when there is room.
class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({required this.point, required this.controller});

  final AudiogramPoint point;
  final AudiogramController controller;

  @override
  Widget build(BuildContext context) {
    final label = Text(frequencyLabel(point.frequency), style: Theme.of(context).textTheme.titleSmallEmphasized);
    final ears = [for (final ear in Ear.values) _EarStepper(point: point, ear: ear, controller: controller)];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 440
            ? Row(
                spacing: 12,
                children: [
                  Expanded(child: label),
                  ...ears,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  label,
                  Wrap(spacing: 16, runSpacing: 4, children: ears),
                ],
              ),
      ),
    );
  }
}

/// The threshold of one ear at one frequency: the ear's chart marker and a stepper.
class _EarStepper extends StatelessWidget {
  const _EarStepper({required this.point, required this.ear, required this.controller});

  final AudiogramPoint point;
  final Ear ear;
  final AudiogramController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The colours and markers of the chart: crosses for the left ear, circles for the right.
    final (color, marker) = ear == Ear.left ? (scheme.primary, Icons.close) : (scheme.tertiary, Icons.circle_outlined);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Icon(marker, size: 18, color: color),
        NumberStepper(
          value: point.of(ear),
          step: AudiogramPlan.step,
          min: AudiogramPlan.minThreshold,
          max: AudiogramPlan.maxThreshold,
          format: (value) => '${formatNumber(value, maxDecimals: 1)} dB',
          label: '${ear.name} ear at ${frequencyLabel(point.frequency)}',
          color: color,
          onChanged: (value) => controller.setThreshold(point.frequency, ear, value),
        ),
      ],
    );
  }
}
