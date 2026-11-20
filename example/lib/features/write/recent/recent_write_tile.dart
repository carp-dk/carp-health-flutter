/// One entry of the Write page's recent writes, with its View and Delete actions.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/open_by_uuid.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

/// A [write]: its type's icon, what was written, when, and the id it can be found by (its UUID or, when
/// it has none, its client record id). View reads the record back with `getHealthDataByUUID`; Delete
/// runs [onDelete], which confirms and deletes. While the delete runs ([deleteState]) a loading indicator
/// stands in for its button; a refused or failed delete is said in the subtitle.
class RecentWriteTile extends StatelessWidget {
  /// Creates the row of [write].
  const RecentWriteTile({
    super.key,
    required this.write,
    required this.deleteState,
    required this.deleteMethod,
    this.onDelete,
  });

  /// The write.
  final RecentWrite write;

  /// The state of the last delete of [write].
  final AsyncValue<bool> deleteState;

  /// The plugin method that deletes the record, such as `deleteByUUID`.
  final String deleteMethod;

  /// Confirms and deletes the record; null when it cannot be deleted here.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant);
    final uuid = write.uuid;
    final problem = switch (deleteState) {
      AsyncData(value: false) => 'Not deleted',
      AsyncError(:final error) => ErrorInfo.from(error).title,
      _ => null,
    };
    return ListTile(
      leading: TypeIcon(type: write.type, size: 40),
      title: Text(write.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${write.type.label} · ${formatRelative(write.at)}', style: small),
          if (problem != null) Text(problem, style: small.copyWith(color: scheme.error)),
        ],
      ),
      onTap: uuid == null ? null : () => openDataPointByUuid(context, uuid: uuid, type: write.type),
      trailing: onDelete != null ? _deleteButton() : (uuid != null ? const Icon(Icons.chevron_right) : null),
    );
  }

  /// Delete, or a loading indicator while the delete runs.
  Widget _deleteButton() {
    const motion = ExpressiveMotion.spatialFast;
    return AnimatedSwitcher(
      duration: motion.duration,
      switchInCurve: motion,
      child: deleteState.isLoading
          ? const Padding(
              key: ValueKey('deleting'),
              padding: EdgeInsets.all(8),
              child: ExpressiveLoadingIndicator(size: 32, semanticsLabel: 'Deleting'),
            )
          : IconButton(
              key: const ValueKey('delete'),
              tooltip: 'Delete ($deleteMethod)',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
    );
  }
}
