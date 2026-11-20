/// The results of a query: the summary, then the data points grouped by type in lazily built lists.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/data_point/data_point_tile.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import '../widgets/segmented_sliver_list.dart';
import 'query_controller.dart';
import 'query_result.dart';
import 'query_summary_card.dart';

/// The slivers of [result]: the [QuerySummaryCard], then for each type a header and its points as
/// [DataPointTile]s in a segmented list that builds only the tiles on screen, so thousands of points
/// scroll smoothly. Tapping a header folds its type away; tapping a point opens the data point sheet,
/// and a point deleted there (`deleteByUUID`) leaves the list.
class QueryResults extends StatefulWidget {
  /// Creates the results of [result], acting on [controller].
  const QueryResults({super.key, required this.controller, required this.result, required this.isAndroid});

  /// The Query section's controller.
  final QueryController controller;

  /// What the query read.
  final QueryResult result;

  /// Whether the app runs on Android, which the summary's info depends on.
  final bool isAndroid;

  @override
  State<QueryResults> createState() => _QueryResultsState();
}

/// Remembers which types are folded away.
class _QueryResultsState extends State<QueryResults> {
  final Set<HealthDataType> _folded = {};

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final controller = widget.controller;
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 24),
          sliver: SliverToBoxAdapter(
            child: QuerySummaryCard(
              result: result,
              onRemoveDuplicates: controller.removeDuplicates,
              isAndroid: widget.isAndroid,
            ),
          ),
        ),
        if (result.groups.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(icon: Icons.search_off, title: 'No data points'),
          ),
        for (final group in result.groups) ...[
          SliverToBoxAdapter(
            child: _GroupHeader(
              group: group,
              folded: _folded.contains(group.type),
              onToggle: () =>
                  setState(() => _folded.contains(group.type) ? _folded.remove(group.type) : _folded.add(group.type)),
            ),
          ),
          if (!_folded.contains(group.type))
            SegmentedSliverList(
              itemCount: group.points.length,
              itemBuilder: (context, index) {
                final point = group.points[index];
                return DataPointTile(
                  point: point,
                  showType: false,
                  onTap: () => showDataPointSheet(context, point, onDeleted: controller.removePoint),
                );
              },
            ),
        ],
      ],
    );
  }
}

/// The header of one type's points: its icon, name and count, a pill when it was read without the read
/// permission, and a chevron that folds the type away.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.folded, required this.onToggle});

  final TypeGroup group;
  final bool folded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = group.isTruncated
        ? '${formatNumber(group.points.length)} of ${formatNumber(group.count)} points'
        : '${formatNumber(group.count)} ${group.count == 1 ? 'point' : 'points'}';
    const motion = ExpressiveMotion.spatialFast;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Semantics(
        button: true,
        expanded: !folded,
        child: InkWell(
          onTap: onToggle,
          borderRadius: ExpressiveShapes.radius(ExpressiveShapes.large),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              spacing: 12,
              children: [
                TypeIcon(type: group.type),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.type.label, style: theme.textTheme.titleLargeEmphasized),
                      Text(count, style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (group.readPermissionDenied)
                  const Tooltip(
                    message: 'Read without the read permission: only the records this app wrote',
                    child: StatusPill(label: 'Own data', tone: StatusTone.warning, icon: Icons.lock_outline),
                  ),
                AnimatedRotation(
                  turns: folded ? -0.25 : 0,
                  duration: motion.duration,
                  curve: motion,
                  child: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
