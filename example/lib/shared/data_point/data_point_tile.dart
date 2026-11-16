/// One data point in a list: its value, when and by whom it was recorded, and how.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_text.dart';
import 'package:health_example/shared/visuals/recording_method_visuals.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

/// A list tile for [point]: the type's icon in its category's shape, the value as the title
/// (`formatPointValue`, such as "72 bpm" or "Running · 30 min · 5.2 km"), the type and when it was
/// recorded ([dataPointTime]), the source app (`HealthDataPoint.sourceName`), and an icon for its
/// `RecordingMethod`.
///
/// It is a `ListTile`, so a `SegmentedList` shapes its ink to the segment. [onTap] is usually
/// `() => showDataPointSheet(context, point)`; without it the tile is not interactive.
class DataPointTile extends StatelessWidget {
  /// Creates a tile for [point].
  const DataPointTile({super.key, required this.point, this.onTap, this.showType = true});

  /// The data point.
  final HealthDataPoint point;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Whether to name the type in the subtitle; lists grouped under a type header leave it out.
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final method = point.recordingMethod;
    final when = [if (showType) point.type.label, dataPointTime(point)].join(' · ');
    // Intervals of several apps name them all, comma-separated.
    final source = point.sourceName.isEmpty ? 'Unknown source' : point.sourceName;
    return ListTile(
      onTap: onTap,
      leading: TypeIcon(type: point.type),
      title: Text(
        formatPointValue(point),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMediumEmphasized.copyWith(color: scheme.onSurface),
      ),
      subtitle: Text('$when\n$source', maxLines: 3, overflow: TextOverflow.ellipsis),
      isThreeLine: true,
      trailing: Tooltip(
        message: '${method.label}: ${method.description}',
        child: Icon(method.icon, semanticLabel: '${method.label} recording'),
      ),
    );
  }
}
