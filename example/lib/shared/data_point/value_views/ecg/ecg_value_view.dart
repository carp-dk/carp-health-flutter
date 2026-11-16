/// The details of an electrocardiogram: its classification, heart rate, samples and a trace.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/layout/metric_grid.dart';

import 'ecg_trace.dart';

/// An [ElectrocardiogramHealthValue] (iOS: ECGs that an Apple Watch recorded, which apps can only read):
/// the classification as a status pill, the average heart rate, sampling frequency and number of
/// voltage samples as figures, and a trace of the first seconds.
class EcgValueView extends StatelessWidget {
  /// Creates the view of [value].
  const EcgValueView({super.key, required this.value});

  /// The ECG.
  final ElectrocardiogramHealthValue value;

  @override
  Widget build(BuildContext context) {
    final samples = value.voltageValues;
    final length = samples.isEmpty ? null : samples.last.timeSinceSampleStart;
    final (label, tone) = classificationOf(value.classification);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Electrocardiogram', subtitle: 'ElectrocardiogramHealthValue'),
        // Under the header rather than at its end, where a long classification would squeeze the title.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: StatusPill(label: label, tone: tone, icon: Icons.monitor_heart_outlined),
        ),
        const SizedBox(height: 12),
        MetricGrid(
          tiles: [
            if (value.averageHeartRate case final heartRate?)
              MetricTile(
                label: 'Average heart rate',
                value: formatNumber(heartRate, maxDecimals: 0),
                unit: 'bpm',
                icon: Icons.favorite_outline,
                shape: ExpressiveShape.cookie9,
              ),
            if (value.samplingFrequency case final frequency?)
              MetricTile(
                label: 'Sampling frequency',
                value: formatNumber(frequency, maxDecimals: 1),
                unit: 'Hz',
                icon: Icons.graphic_eq,
                shape: ExpressiveShape.cookie6,
              ),
            MetricTile(
              label: 'Voltage samples',
              value: formatNumber(samples.length),
              icon: Icons.show_chart,
              shape: ExpressiveShape.pill,
              footnote: length == null ? null : 'Over ${formatNumber(length, maxDecimals: 1)} s',
            ),
          ],
        ),
        if (samples.length > 1) ...[
          const SizedBox(height: 8),
          ExpressiveCard(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: SizedBox(height: 120, child: EcgTrace(voltages: samples)),
          ),
        ],
      ],
    );
  }

  /// The name and status tone of an ECG [classification]: a sinus rhythm reads as success, atrial
  /// fibrillation as an error and the inconclusive results as warnings.
  static (String, StatusTone) classificationOf(ElectrocardiogramClassification? classification) =>
      switch (classification) {
        null || ElectrocardiogramClassification.NOT_SET => ('Not classified', StatusTone.neutral),
        ElectrocardiogramClassification.SINUS_RHYTHM => ('Sinus rhythm', StatusTone.success),
        ElectrocardiogramClassification.ATRIAL_FIBRILLATION => ('Atrial fibrillation', StatusTone.error),
        ElectrocardiogramClassification.UNRECOGNIZED => ('Unrecognized', StatusTone.neutral),
        _ => (formatEnumName(classification), StatusTone.warning),
      };
}
