/// One entry of the recent changes in Read > Changes: a record and what a sync did to it.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/visuals/monospace.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import '../synced_records.dart';
import 'change_outcome_visuals.dart';

/// A list tile for [entry]: the record's type icon, its value (`formatPointValue` of its first data
/// point, with the count of values of a series or blood pressure record), the outcome, its type and
/// when it came, and the Health Connect record id. The outcome also shows as a small shaped icon at
/// the end.
///
/// Tapping opens the record's first data point in the data point sheet; a deleted record shows the
/// points the copy had, and the deletion of a record the copy never had cannot be opened (Health Connect
/// reports only the id of a deleted record).
class ChangeEntryTile extends StatelessWidget {
  /// Creates the tile of [entry].
  const ChangeEntryTile({super.key, required this.entry});

  /// The record and what happened to it.
  final ChangeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outcome = entry.outcome;
    final type = entry.type;
    final first = entry.points.firstOrNull;
    final count = entry.points.length;
    final title = switch (first) {
      null => 'Deleted record',
      final point when count > 1 => '${formatPointValue(point)} · ${formatNumber(count)} values',
      final point => formatPointValue(point),
    };
    final (background, foreground) = outcome.tone.colorsIn(ExpressiveStatusColors.of(context));
    final outcomeIcon = ShapedIcon(
      icon: outcome.icon,
      shape: outcome.shape,
      size: type == null ? 40 : 32,
      background: background,
      foreground: foreground,
    );
    return ListTile(
      onTap: first == null ? null : () => showDataPointSheet(context, first),
      leading: type == null ? outcomeIcon : TypeIcon(type: type),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMediumEmphasized.copyWith(color: scheme.onSurface),
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${outcome.label} · ${type?.label ?? 'Unknown type'} · ${formatRelative(entry.at)}\n'),
            TextSpan(text: entry.recordId, style: const TextStyle().monospace),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      // The leading icon shows the outcome when the type is unknown; otherwise it goes at the end.
      trailing: type == null ? null : Tooltip(message: outcome.label, child: outcomeIcon),
    );
  }
}
