/// The start and end of what a write form writes, with duration presets.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'field_pair.dart';

/// The [start] and [end] fields of a write ([DateTimeField]s, side by side on wide windows), a connected
/// button group of [presets] that set the end to the start plus the preset, and a pill with the duration.
///
/// Moving the start keeps the duration, so the end moves with it. An end before the start (or at it,
/// unless [allowInstant]) is shown as a problem but not prevented: the plugin's own check then throws an
/// `ArgumentError`, which the form shows, and which is part of what the example demonstrates.
class TimeSpanFields extends StatelessWidget {
  /// Creates the fields for the span from [start] to [end].
  const TimeSpanFields({
    super.key,
    required this.start,
    required this.end,
    required this.onChanged,
    this.presets = const [Duration(minutes: 15), Duration(minutes: 30), Duration(hours: 1)],
    this.startLabel = 'Start',
    this.endLabel = 'End',
    this.allowInstant = false,
  });

  /// The start of the span.
  final DateTime start;

  /// The end of the span.
  final DateTime end;

  /// Called with the new start and end when either changes.
  final void Function(DateTime start, DateTime end) onChanged;

  /// The durations offered as presets; [Duration.zero] reads "Instant".
  final List<Duration> presets;

  /// The label of the start field.
  final String startLabel;

  /// The label of the end field.
  final String endLabel;

  /// Whether the span may end when it starts, as an insulin bolus can.
  final bool allowInstant;

  @override
  Widget build(BuildContext context) {
    final duration = end.difference(start);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        FieldPair(
          first: DateTimeField(
            label: startLabel,
            value: start,
            onChanged: (value) => onChanged(value, duration.isNegative ? end : value.add(duration)),
          ),
          second: DateTimeField(label: endLabel, value: end, onChanged: (value) => onChanged(start, value)),
        ),
        if (presets.isNotEmpty)
          ConnectedButtonGroup<Duration?>(
            segments: [
              for (final preset in presets) ButtonGroupSegment<Duration?>(value: preset, label: presetLabel(preset)),
            ],
            // No segment is selected when the span matches no preset.
            selected: presets.contains(duration) ? duration : null,
            onSelected: (preset) {
              if (preset != null) onChanged(start, start.add(preset));
            },
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: DurationPill(duration, allowInstant: allowInstant),
        ),
      ],
    );
  }

  /// The label of [preset]: "Instant" for no duration, else the duration, such as "30 min".
  static String presetLabel(Duration preset) => preset == Duration.zero ? 'Instant' : formatDuration(preset);
}

/// How long a span lasts, or why it is not a valid span, as a status pill.
class DurationPill extends StatelessWidget {
  /// Creates the pill for a span of [duration].
  const DurationPill(this.duration, {super.key, this.allowInstant = false});

  /// The span's length; negative when it ends before it starts.
  final Duration duration;

  /// Whether a span without a duration is valid.
  final bool allowInstant;

  @override
  Widget build(BuildContext context) {
    if (duration.isNegative) {
      return const StatusPill(label: 'Ends before it starts', tone: StatusTone.error, icon: Icons.error_outline);
    }
    if (duration == Duration.zero) {
      return allowInstant
          ? const StatusPill(label: 'An instant', tone: StatusTone.info, icon: Icons.bolt)
          : const StatusPill(label: 'Ends when it starts', tone: StatusTone.error, icon: Icons.error_outline);
    }
    return StatusPill(label: 'Lasts ${formatDuration(duration)}', tone: StatusTone.info, icon: Icons.timelapse);
  }
}
