/// The top of the data point sheet: the type in its shape, the value in big type, when it was recorded
/// and status pills.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_text.dart';
import 'package:health_example/shared/scope_lookup.dart';
import 'package:health_example/shared/visuals/recording_method_visuals.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

/// The header of the data point sheet: a [TypeIcon], the type's name, the [dataPointHeadline] in big
/// emphasized type, when the point was recorded ([dataPointTime]) and for how long, and pills for its
/// recording method, its platform and whether this app wrote it.
class DataPointHeader extends StatelessWidget {
  /// Creates the header of [point].
  const DataPointHeader({super.key, required this.point});

  /// The data point.
  final HealthDataPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = point.dateTo.difference(point.dateFrom);
    final when = [dataPointTime(point), if (duration > Duration.zero) formatDuration(duration)].join(' · ');
    // A record in the app's log of its writes is the app's own, which deleteByUUID can delete.
    final ownWrite =
        point.uuid.isNotEmpty &&
        (maybeAppServices(context)?.recentWrites.items.any((write) => write.uuid == point.uuid) ?? false);
    final method = point.recordingMethod;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 16,
          children: [
            TypeIcon(type: point.type, size: 72),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.type.label, style: theme.textTheme.titleMedium!.copyWith(color: scheme.onSurfaceVariant)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      dataPointHeadline(point),
                      maxLines: 1,
                      style: theme.textTheme.displaySmallEmphasized.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(when, style: theme.textTheme.bodyLarge!.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(label: method.label, tone: method.tone, icon: method.icon),
            StatusPill(
              label: point.sourcePlatform == HealthPlatformType.appleHealth ? 'Apple Health' : 'Health Connect',
              icon: point.sourcePlatform == HealthPlatformType.appleHealth ? Icons.apple : Icons.android,
            ),
            if (ownWrite) const StatusPill(label: 'Written by this app', tone: StatusTone.info, icon: Icons.edit),
          ],
        ),
      ],
    );
  }
}
