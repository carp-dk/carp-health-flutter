/// The counters of a sync in Read > Changes: what the changes did to the local copy.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';

import '../changes_summary.dart';
import '../synced_records.dart';
import 'change_outcome_visuals.dart';

/// Four counters of [summary]: the records the sync inserted into the local copy, updated, removed and
/// found unchanged. They follow a running sync page by page.
///
/// The numbers count to each new value on the slow effects spring, which never overshoots, so a counter
/// never shows more than it counts. Four in a row on wide cards, two by two on phones.
class ChangesCounters extends StatelessWidget {
  /// Creates the counters of [summary].
  const ChangesCounters({super.key, required this.summary});

  /// The sync whose counts to show.
  final ChangesSummary summary;

  /// The narrowest width at which the four counters share one row.
  static const double rowBreakpoint = 440;

  @override
  Widget build(BuildContext context) {
    final counters = [
      _Counter(outcome: ChangeOutcome.inserted, value: summary.inserted),
      _Counter(outcome: ChangeOutcome.updated, value: summary.updated),
      _Counter(outcome: ChangeOutcome.removed, value: summary.removed),
      _Counter(outcome: ChangeOutcome.unchanged, value: summary.unchanged),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= rowBreakpoint) {
          return Row(spacing: 8, children: [for (final counter in counters) Expanded(child: counter)]);
        }
        return Column(
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(child: counters[0]),
                Expanded(child: counters[1]),
              ],
            ),
            Row(
              spacing: 8,
              children: [
                Expanded(child: counters[2]),
                Expanded(child: counters[3]),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// One counter: the outcome's icon in its shape and colours, the count and the outcome's name.
class _Counter extends StatelessWidget {
  const _Counter({required this.outcome, required this.value});

  final ChangeOutcome outcome;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = outcome.tone.colorsIn(ExpressiveStatusColors.of(context));
    const motion = ExpressiveMotion.effectsSlow;
    return Semantics(
      label: '${outcome.label}: $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerLow,
          shape: ExpressiveShapes.rounded(ExpressiveShapes.largeIncreased),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            spacing: 12,
            children: [
              ShapedIcon(
                icon: outcome.icon,
                shape: outcome.shape,
                size: 36,
                background: background,
                foreground: foreground,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Counts up from 0 when it first shows, then from the old value to each new one.
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: value.toDouble()),
                      duration: motion.duration,
                      curve: motion,
                      builder: (context, shown, _) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          formatNumber(shown.round()),
                          maxLines: 1,
                          style: theme.textTheme.headlineSmallEmphasized.tabular.copyWith(color: scheme.onSurface),
                        ),
                      ),
                    ),
                    Text(
                      outcome.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
