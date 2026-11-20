/// What Read > Changes explains about a finished sync.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../../widgets/note_line.dart';
import '../changes_controller.dart';
import '../changes_summary.dart';

/// Notes on the finished sync [summary]: more changes waiting (`hasMore` when the sync stopped at its
/// call limit), nothing changed, deletions of records the copy never had, changes that could not be
/// applied, and an error that ended the sync after some pages (with an `ErrorCard` that retries through
/// [controller]). Shows nothing when there is nothing to say.
class SyncNotes extends StatelessWidget {
  /// Creates the notes on [summary].
  const SyncNotes({super.key, required this.summary, required this.controller});

  /// The finished sync.
  final ChangesSummary summary;

  /// The Changes section's controller, for the retry of a failed sync.
  final ChangesController controller;

  @override
  Widget build(BuildContext context) {
    final error = summary.error;
    final unknown = summary.unknownDeletes;
    final skipped = summary.skipped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.hasMore && !summary.tokenExpired)
          const NoteLine(icon: Icons.more_horiz, text: 'More changes waiting — fetch again'),
        if (summary.calls > 0 && summary.changes == 0 && error == null && !summary.tokenExpired)
          NoteLine(
            icon: Icons.check_circle_outline,
            text: controller.includeSelf ? 'No changes since last sync' : 'No external changes',
          ),
        if (unknown > 0)
          NoteLine(
            icon: Icons.delete_sweep_outlined,
            text: '${formatNumber(unknown)} deleted outside local copy',
          ),
        if (skipped > 0) NoteLine(icon: Icons.block, text: '${formatNumber(skipped)} skipped'),
        if (error != null) ...[
          NoteLine(
            icon: Icons.warning_amber_rounded,
            text: 'Stopped after ${summary.calls} ${summary.calls == 1 ? 'call' : 'calls'}',
          ),
          const SizedBox(height: 12),
          ErrorCard(error: error, onRetry: controller.canSync ? controller.fetchChanges : null),
        ],
      ],
    );
  }
}
