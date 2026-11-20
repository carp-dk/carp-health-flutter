/// The options card of Read > Query: read mode upfront and progressive disclosure for filters and limits.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/recording_method_filter.dart';

import '../widgets/adaptive_pair.dart';
import '../widgets/option_block.dart';
import 'query_controller.dart';
import 'query_options.dart';

/// Compact read options: the mode selector (`All at once` / `Page by page`) always accessible, with
/// `limit` / `pageSize`, `recordingMethodsToFilter`, `preferredUnits` and `appendResults` behind a
/// spring-animated disclosure row showing active non-default choices.
class QueryOptionsCard extends StatefulWidget {
  /// Creates the options card of [controller]'s query.
  const QueryOptionsCard({super.key, required this.controller, required this.settings});

  /// The Query section's controller, which holds the options.
  final QueryController controller;

  /// The plugin settings, whose page size page by page reads use.
  final PluginSettings settings;

  @override
  State<QueryOptionsCard> createState() => _QueryOptionsCardState();
}

class _QueryOptionsCardState extends State<QueryOptionsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = widget.controller.options;
    void update(QueryOptions next) => widget.controller.options = next;
    final reduced = ExpressiveMotion.reduceMotion(context);
    final duration = reduced ? Duration.zero : ExpressiveMotion.spatialDefault.duration;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectedButtonGroup<QueryMode>(
            segments: [
              for (final mode in QueryMode.values) ButtonGroupSegment(value: mode, label: mode.label, icon: mode.icon),
            ],
            selected: options.mode,
            onSelected: (mode) => update(options.copyWith(mode: mode)),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) {
              final summary = _summary(options, widget.settings.pageSize);
              return InkWell(
                borderRadius: ExpressiveShapes.radius(ExpressiveShapes.medium),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Row(
                    spacing: 8,
                    children: [
                      Icon(Icons.tune, size: 18, color: scheme.primary),
                      Expanded(
                        child: Text(
                          'Filters & limits',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmallEmphasized,
                        ),
                      ),
                      if (summary.isNotEmpty)
                        Flexible(
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: duration,
                        curve: ExpressiveMotion.spatialFast,
                        child: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          AnimatedSize(
            duration: duration,
            curve: ExpressiveMotion.spatialDefault,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: AdaptivePair(
                      spacing: 20,
                      first: options.mode == QueryMode.allAtOnce ? _limit(options, update) : _pageSize(),
                      second: _filters(options, update),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _filters(QueryOptions options, ValueChanged<QueryOptions> update) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RecordingMethodFilter(
        filtered: options.recordingMethodsToFilter,
        onChanged: (methods) => update(options.copyWith(recordingMethodsToFilter: methods)),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Imperial units (°F, lb, in)'),
        value: options.imperialUnits,
        onChanged: (on) => update(options.copyWith(imperialUnits: on)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Add to results'),
        value: options.appendResults,
        onChanged: (on) => update(options.copyWith(appendResults: on)),
      ),
    ],
  );

  /// The `limit` of a read all at once.
  Widget _limit(QueryOptions options, ValueChanged<QueryOptions> update) => OptionBlock(
    key: const ValueKey('limit'),
    label: 'Limit per type',
    child: ConnectedButtonGroup<int>(
      segments: [
        for (final limit in QueryOptions.limits)
          ButtonGroupSegment(value: limit, label: limit == 0 ? 'None' : '$limit'),
      ],
      selected: options.limit,
      onSelected: (limit) => update(options.copyWith(limit: limit)),
    ),
  );

  /// The `pageSize` of a read page by page: the plugin's `Health.pageSize`, which Setup also changes.
  Widget _pageSize() => ListenableBuilder(
    key: const ValueKey('pageSize'),
    listenable: widget.settings,
    builder: (context, _) {
      final current = widget.settings.pageSize;
      // A size set on the Setup page's slider gets a segment of its own.
      final sizes = {...PluginSettings.pageSizePresets, current}.toList()..sort();
      return OptionBlock(
        label: 'Points per page',
        child: ConnectedButtonGroup<int>(
          segments: [for (final size in sizes) ButtonGroupSegment(value: size, label: _compact(size))],
          selected: current,
          onSelected: (size) => widget.settings.pageSize = size,
        ),
      );
    },
  );

  /// Compact summary of non-default options shown while collapsed.
  static String _summary(QueryOptions options, int pageSize) {
    final parts = <String>[
      if (options.mode == QueryMode.allAtOnce && options.limit > 0) 'Limit ${options.limit}',
      if (options.mode == QueryMode.pages) '${_compact(pageSize)}/page',
      if (options.recordingMethodsToFilter.isNotEmpty) '${options.recordingMethodsToFilter.length} filtered',
      if (options.imperialUnits) 'Imperial',
      if (options.appendResults) 'Append',
    ];
    return parts.join(' · ');
  }

  /// [size] in thousands, such as "20k", to fit a segment.
  static String _compact(int size) => size < 1000 ? '$size' : '${formatNumber(size / 1000, maxDecimals: 1)}k';
}
