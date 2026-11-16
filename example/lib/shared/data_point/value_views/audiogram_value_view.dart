/// The details of an audiogram: the hearing threshold of each ear at each tested frequency.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// An [AudiogramHealthValue] (iOS) as a table: one row per frequency with the threshold of the left
/// and the right ear in decibels hearing level (dB HL). A frequency tested on one ear only shows a
/// dash for the other.
class AudiogramValueView extends StatelessWidget {
  /// Creates the view of [value].
  const AudiogramValueView({super.key, required this.value});

  /// The audiogram.
  final AudiogramHealthValue value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final header = theme.textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant);
    final cell = theme.textTheme.bodyLarge!.copyWith(color: scheme.onSurface);
    TableRow row(List<String> cells, TextStyle style) => TableRow(
      children: [
        for (final (index, text) in cells.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(text, style: style, textAlign: index == 0 ? TextAlign.start : TextAlign.end),
          ),
      ],
    );
    return DetailSection(
      title: 'Audiogram',
      subtitle: 'Hearing thresholds in dB HL, lower is better',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: value.frequencies.isEmpty
              ? Text('No frequencies were tested.', style: cell)
              : Table(
                  columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
                  children: [
                    row(const ['Frequency', 'Left ear', 'Right ear'], header),
                    for (final (index, frequency) in value.frequencies.indexed)
                      row([
                        '${formatNumber(frequency)} Hz',
                        _threshold(value.leftEarSensitivities, index),
                        _threshold(value.rightEarSensitivities, index),
                      ], cell),
                  ],
                ),
        ),
      ],
    );
  }

  /// The threshold at [index] of [sensitivities], or a dash where that ear was not tested.
  static String _threshold(List<num?> sensitivities, int index) {
    final threshold = index < sensitivities.length ? sensitivities[index] : null;
    return threshold == null ? '–' : '${formatNumber(threshold, maxDecimals: 1)} dB';
  }
}
