/// The fields every data point has, and its metadata.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';
import 'package:health_example/shared/visuals/recording_method_visuals.dart';

/// The fields of the [HealthDataPoint] itself: its times, unit, source, device model, recording
/// method, UUID and the id of the reading device, then its metadata, if any.
class DataPointFields extends StatelessWidget {
  /// Creates the fields of [point].
  const DataPointFields({super.key, required this.point});

  /// The data point.
  final HealthDataPoint point;

  /// The most metadata entries listed.
  static const int maxMetadata = 40;

  @override
  Widget build(BuildContext context) {
    final symbol = formatUnit(point.unit);
    final method = point.recordingMethod;
    final metadata = point.metadata ?? const <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailSection(
          title: 'Record',
          subtitle: 'HealthDataPoint',
          children: [
            DetailField(label: 'Start', value: _timestamp(point.dateFrom), icon: Icons.play_arrow_outlined),
            DetailField(label: 'End', value: _timestamp(point.dateTo), icon: Icons.stop_outlined),
            DetailField(
              label: 'Unit',
              value: symbol.isEmpty ? point.unit.name : '$symbol (${point.unit.name})',
              icon: Icons.straighten,
            ),
            DetailField(label: 'Source', value: _orNotReported(point.sourceName), icon: Icons.apps),
            // Health Connect reports the writing app's package as the source name and no source id.
            if (point.sourceId.isNotEmpty)
              DetailField(label: 'Source id', value: point.sourceId, icon: Icons.badge_outlined, monospace: true),
            DetailField(label: 'Device model', value: _orNotReported(point.deviceModel), icon: Icons.watch_outlined),
            DetailField(
              label: 'Recording method',
              value: method.description,
              icon: method.icon,
              trailing: StatusPill(label: method.label, tone: method.tone),
            ),
            DetailField(
              label: 'UUID',
              value: point.uuid.isEmpty ? 'None: interval data are aggregates, not records' : point.uuid,
              icon: Icons.fingerprint,
              copyable: point.uuid.isNotEmpty,
              monospace: point.uuid.isNotEmpty,
            ),
            // The id of the device that read the data (Health.deviceId), not of the one that recorded it.
            DetailField(
              label: 'Source device id (this device)',
              value: point.sourceDeviceId,
              icon: Icons.smartphone,
              copyable: true,
              monospace: true,
            ),
          ],
        ),
        if (metadata.isNotEmpty)
          DetailSection(
            title: 'Metadata',
            subtitle: 'HealthDataPoint.metadata',
            children: [
              for (final entry in metadata.entries.take(maxMetadata))
                DetailField(label: entry.key, value: '${entry.value}', monospace: true),
              if (metadata.length > maxMetadata)
                DetailField(label: 'More', value: '${metadata.length - maxMetadata} more entries are in the raw JSON'),
            ],
          ),
      ],
    );
  }

  /// The date and time of [time] to the second, such as "16 Nov 2026, 07:05:09".
  static String _timestamp(DateTime time) =>
      '${formatDate(time, withYear: true)}, ${formatTime(time, withSeconds: true)}';

  static String _orNotReported(String? text) => text == null || text.isEmpty ? 'Not reported' : text;
}
