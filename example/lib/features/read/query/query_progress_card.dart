/// The card that shows a running query: how far a page by page read has come, with its Cancel button,
/// or that a read all at once is under way.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';

import 'query_controller.dart';
import 'query_options.dart';

/// Shows the read [controller] is running, and nothing when none is.
///
/// A page by page read (`getHealthDataPages`) shows its pages and points so far, the type it reads, a
/// wavy progress bar (determinate by types done when several types are read) and Cancel, which cancels
/// the stream subscription. A read all at once (`getHealthDataFromTypes`) cannot be cancelled and reports
/// nothing until it returns, so it shows the loading indicator and the time it has taken. The time ticks
/// while the card is visible; an info button names the method and explains Cancel, or why there is none.
class QueryProgressCard extends StatefulWidget {
  /// Creates the card for [controller]'s running read.
  const QueryProgressCard({super.key, required this.controller});

  /// The Query section's controller.
  final QueryController controller;

  @override
  State<QueryProgressCard> createState() => _QueryProgressCardState();
}

/// Rebuilds about ten times a second while a read runs, so the time taken ticks.
class _QueryProgressCardState extends State<QueryProgressCard> with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_tick);
  int _shownTenths = -1;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration _) {
    final tenths = (widget.controller.readingFor?.inMilliseconds ?? 0) ~/ 100;
    if (tenths != _shownTenths) setState(() => _shownTenths = tenths);
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.controller.readingWith;
    if (options == null) return const SizedBox.shrink();
    return ExpressiveCard(
      variant: ExpressiveCardVariant.tonal,
      // Built inside the card, so that text styled from the theme takes the card's colours.
      child: Builder(builder: (context) => _content(context, options)),
    );
  }

  Widget _content(BuildContext context, QueryOptions options) {
    final theme = Theme.of(context);
    final elapsed = widget.controller.readingFor ?? Duration.zero;
    final paged = options.mode == QueryMode.pages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 16,
          children: [
            const ExpressiveLoadingIndicator(size: 48, contained: true, semanticsLabel: 'Reading'),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(paged ? 'Reading pages…' : 'Reading…', style: theme.textTheme.titleMediumEmphasized),
                  Text(_seconds(elapsed), style: theme.textTheme.bodySmall!.tabular),
                ],
              ),
            ),
          ],
        ),
        if (paged) ...[const SizedBox(height: 16), ..._pagesProgress(context)],
      ],
    );
  }

  /// The pages and points so far, the progress bar and Cancel.
  List<Widget> _pagesProgress(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final progress = controller.progress;
    final current = progress?.currentType;
    final pages = progress?.pages ?? 0;
    final points = progress?.points ?? 0;
    final typesTotal = progress?.typesTotal ?? 0;
    return [
      Row(
        children: [
          Expanded(
            child: _Count(value: pages, label: pages == 1 ? 'page' : 'pages'),
          ),
          Expanded(
            child: _Count(value: points, label: points == 1 ? 'point' : 'points'),
          ),
          Expanded(
            child: _Count(value: progress?.typesDone ?? 0, label: 'of $typesTotal types'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      WavyProgressIndicator(value: progress?.fraction, semanticsLabel: 'Types read'),
      if (current != null) ...[
        const SizedBox(height: 8),
        Text(current.label, style: theme.textTheme.labelMedium),
      ],
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          onPressed: controller.canCancel ? controller.cancel : null,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(controller.isCancelling ? 'Cancelling…' : 'Cancel'),
        ),
      ),
    ];
  }

  /// [elapsed] in seconds with one decimal, such as "2.4 s".
  static String _seconds(Duration elapsed) => '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} s';
}

/// A big emphasized number over a small label.
class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(formatNumber(value), maxLines: 1, style: theme.textTheme.headlineMediumEmphasized.tabular),
        ),
        Text(label, maxLines: 2, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
