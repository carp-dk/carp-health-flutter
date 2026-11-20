/// The card of Read > Changes that fetches the changes with `getChanges` and shows what each sync did.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../../widgets/card_title.dart';
import '../../widgets/fact_pill.dart';
import '../changes_controller.dart';
import '../changes_summary.dart';
import 'changes_counters.dart';
import 'sync_notes.dart';
import 'token_expired_notice.dart';

/// Syncing: the records in the local copy, the Fetch changes button and what the last sync did.
///
/// Fetch changes calls `getChanges` with the current token, and again with each `nextChangesToken` while
/// `hasMore` (at most [ChangesController.maxCallsPerSync] calls). While it runs, the loading indicator,
/// a wavy progress bar and the [ChangesCounters] follow it page by page; afterwards the counters, the
/// calls and changes it took, and [SyncNotes] on what the plugin reported stay. An error before the
/// first page shows as an `ErrorCard`. An expired token shows the [TokenExpiredNotice] with the full
/// resync advice, whose read [onReadInQuery] opens.
class ChangesSyncCard extends StatelessWidget {
  /// Creates the card of [controller].
  const ChangesSyncCard({super.key, required this.controller, required this.onReadInQuery});

  /// The Changes section's controller.
  final ChangesController controller;

  /// Opens Query set up to read the followed types again, for a full resync.
  final VoidCallback onReadInQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sync = controller.sync;
    final summary = sync.valueOrNull;
    final syncing = sync.isLoading;
    const motion = ExpressiveMotion.spatialDefault;
    final ready = controller.token != null && !controller.tokenExpired;
    return ExpressiveCard(
      variant: ready ? ExpressiveCardVariant.vibrant : ExpressiveCardVariant.filled,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardTitle(
              icon: Icons.sync,
              shape: ExpressiveShape.cookie6,
              title: 'Sync',
              trailing: _status(summary, syncing),
            ),
            const SizedBox(height: 16),
            _LocalCopy(records: controller.records.recordCount, points: controller.records.pointCount),
            AnimatedSize(
              duration: motion.duration,
              curve: motion,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (summary != null) ...[
                    const SizedBox(height: 16),
                    ChangesCounters(summary: summary),
                    const SizedBox(height: 12),
                    _Facts(summary: summary, lastSyncAt: syncing ? null : controller.lastSyncAt),
                    if (!syncing) SyncNotes(summary: summary, controller: controller),
                  ],
                  if (syncing) ...[const SizedBox(height: 16), _Progress(calls: summary?.calls ?? 0)],
                  if (sync case AsyncError(:final error)) ...[
                    const SizedBox(height: 16),
                    ErrorCard(error: error, onRetry: controller.canSync ? controller.fetchChanges : null),
                  ],
                  if (controller.tokenExpired) ...[
                    const SizedBox(height: 16),
                    TokenExpiredNotice(
                      onNewToken: controller.canCreateToken ? controller.createToken : null,
                      onReadInQuery: onReadInQuery,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: controller.canSync ? controller.fetchChanges : null,
                  icon: syncing
                      ? ExpressiveLoadingIndicator(size: 24, color: scheme.primary, semanticsLabel: 'Fetching changes')
                      : const Icon(Icons.sync),
                  label: Text(syncing ? 'Fetching…' : 'Fetch changes'),
                ),
                TextButton.icon(
                  style: ready ? TextButton.styleFrom(foregroundColor: scheme.onPrimaryContainer) : null,
                  onPressed: controller.canClearLocalCopy ? controller.clearLocalCopy : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Clear'),
                ),
              ],
            ),
            if (controller.token == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Create a token first.',
                  style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A pill that says how the copy stands: syncing, more changes waiting, or up to date.
  static Widget? _status(ChangesSummary? summary, bool syncing) => switch (summary) {
    _ when syncing => const StatusPill(label: 'Syncing', tone: StatusTone.info),
    ChangesSummary(tokenExpired: true) => null,
    ChangesSummary(hasMore: true) => const StatusPill(label: 'More waiting', tone: StatusTone.warning),
    ChangesSummary(error: null) => const StatusPill(label: 'Up to date', tone: StatusTone.success, icon: Icons.check),
    _ => null,
  };
}

/// The size of the local copy: records in big type, and their data points.
class _LocalCopy extends StatelessWidget {
  const _LocalCopy({required this.records, required this.points});

  final int records;
  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: 10,
      children: [
        Text(formatNumber(records), style: theme.textTheme.displaySmallEmphasized.tabular),
        Expanded(
          child: Text(
            '${records == 1 ? 'record' : 'records'} · ${formatNumber(points)} ${points == 1 ? 'point' : 'points'}',
            style: theme.textTheme.bodyMedium!.copyWith(color: DefaultTextStyle.of(context).style.color?.withValues(alpha: 0.8)),
          ),
        ),
      ],
    );
  }
}

/// The calls, changes and time a sync took, as fact pills.
class _Facts extends StatelessWidget {
  const _Facts({required this.summary, required this.lastSyncAt});

  final ChangesSummary summary;
  final DateTime? lastSyncAt;

  @override
  Widget build(BuildContext context) {
    final calls = summary.calls;
    final upserts = summary.upserts;
    final deletes = summary.deletes;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FactPill(icon: Icons.sync_alt, text: '$calls ${calls == 1 ? 'call' : 'calls'}'),
        FactPill(icon: Icons.list_alt, text: '+$upserts / -$deletes'),
        FactPill(icon: Icons.timer_outlined, text: '${formatNumber(summary.elapsed.inMilliseconds)} ms'),
        if (lastSyncAt case final at?) FactPill(icon: Icons.history, text: formatRelative(at)),
      ],
    );
  }
}

/// A running sync: the loading indicator, the pages fetched so far and a wavy progress bar.
class _Progress extends StatelessWidget {
  const _Progress({required this.calls});

  final int calls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          spacing: 12,
          children: [
            const ExpressiveLoadingIndicator(size: 36, contained: true, semanticsLabel: 'Fetching changes'),
            Expanded(child: Text(calls == 0 ? 'Fetching changes…' : 'Page $calls…')),
          ],
        ),
        const WavyProgressIndicator(semanticsLabel: 'Fetching changes'),
      ],
    );
  }
}
