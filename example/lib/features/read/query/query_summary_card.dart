/// The summary at the top of a query's results: how much was read, how, and what the plugin reported
/// about it.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../widgets/fact_pill.dart';
import '../widgets/note_line.dart';
import 'page_accumulator.dart';
import 'query_result.dart';

/// Summarizes [result]: the number of points and types, facts on the read (mode, time, pages, limit, reads
/// added up), then a short line for each thing the plugin reported: a cancel, an error that ended a page
/// by page read early, the types read without their read permission (`HealthDataPage.readPermissionDenied`,
/// Android only), the types without data, the points not kept, and what `removeDuplicates` removed. An info
/// button explains these for the platform. "Remove duplicates" runs [onRemoveDuplicates].
class QuerySummaryCard extends StatelessWidget {
  /// Creates the summary of [result].
  const QuerySummaryCard({super.key, required this.result, required this.onRemoveDuplicates, required this.isAndroid});

  /// What the query read.
  final QueryResult result;

  /// Removes the duplicate points with `Health.removeDuplicates`.
  final VoidCallback onRemoveDuplicates;

  /// Whether the app runs on Android, where page reads report types read without the read permission.
  final bool isAndroid;

  @override
  Widget build(BuildContext context) {
    return ExpressiveCard(
      variant: ExpressiveCardVariant.vibrant,
      // Built inside the card, so that text styled from the theme takes the card's colours.
      child: Builder(builder: _content),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final denied = result.readPermissionDenied.map((type) => type.label).join(', ');
    final empty = result.typesWithoutData;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 10,
          children: [
            Text(formatNumber(result.total), style: theme.textTheme.displaySmallEmphasized.tabular),
            Expanded(
              child: Text(
                '${result.total == 1 ? 'point' : 'points'} · ${result.types.length} '
                '${result.types.length == 1 ? 'type' : 'types'}',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FactPill(icon: result.mode.icon, text: result.mode.label),
            FactPill(icon: Icons.timer_outlined, text: '${formatNumber(result.elapsed.inMilliseconds)} ms'),
            if (result.pages case final pages?) FactPill(icon: Icons.view_agenda_outlined, text: _pages(pages)),
            if (result.limit case final limit?) FactPill(icon: Icons.filter_list, text: 'limit $limit'),
            if (result.reads > 1) FactPill(icon: Icons.library_add_outlined, text: '${result.reads} reads'),
            if (result.cancelled)
              FactPill(
                icon: Icons.stop_circle_outlined,
                text: result.reads == 1 ? 'Cancelled (${_pages(result.pages)})' : 'Cancelled',
              ),
            if (result.removedDuplicates case final removed?)
              FactPill(
                icon: Icons.layers_clear_outlined,
                text: removed == 0 ? 'No duplicates' : '-${formatNumber(removed)} dupes',
              ),
          ],
        ),
        if (result.error case final error?) ...[
          const SizedBox(height: 12),
          ErrorCard(error: error),
        ],
        if (denied.isNotEmpty) NoteLine(icon: Icons.lock_outline, text: 'Own data only: $denied'),
        if (empty.isNotEmpty)
          NoteLine(icon: Icons.inbox_outlined, text: 'Empty: ${empty.map((type) => type.label).join(', ')}'),
        if (result.isTruncated)
          NoteLine(
            icon: Icons.content_cut,
            text: 'Showing latest ${formatNumber(PageAccumulator.defaultKeepPerType)} per type',
          ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: result.points.isEmpty ? null : onRemoveDuplicates,
            icon: const Icon(Icons.layers_clear_outlined),
            label: const Text('Remove duplicates'),
          ),
        ),
      ],
    );
  }

  /// "1 page" or "N pages" ("0 pages" when unknown).
  static String _pages(int? count) => '${formatNumber(count ?? 0)} ${count == 1 ? 'page' : 'pages'}';
}
