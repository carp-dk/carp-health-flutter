/// The overview's highlights as a grid of metric tiles, each showing its own read's state.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/widgets/error_dialog.dart';

import '../model/highlight.dart';
import '../model/highlight_display.dart';
import '../overview_controller.dart';
import 'workouts_sheet.dart';

/// A [MetricTile] per [Highlight], two per row on phones and three from [wideBreakpoint] on, every
/// row as tall as its tallest tile.
///
/// Each tile shows its read on its own ([HighlightDisplay]): a loading indicator, the value, a dash
/// with the reason when there is no data, or an error. Tapping opens the newest data point's sheet,
/// lists the week's workouts, shows the full error, or, without access, calls [onAuthorize].
class HighlightsGrid extends StatelessWidget {
  /// Creates the grid of [controller]'s highlights.
  const HighlightsGrid({super.key, required this.controller, required this.onAuthorize});

  /// The overview's state: each highlight's read.
  final OverviewController controller;

  /// Requests access to a highlight's types, for tiles that could not be read without it.
  final ValueChanged<Highlight> onAuthorize;

  /// The width from which the grid has three columns.
  static const double wideBreakpoint = 600;

  /// The space between tiles.
  static const double spacing = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= wideBreakpoint ? 3 : 2;
        const highlights = Highlight.values;
        return Column(
          spacing: spacing,
          children: [
            for (var start = 0; start < highlights.length; start += columns)
              // Intrinsic height: a tile with a two-line footnote makes its row-mates as tall.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing,
                  children: [
                    for (var index = start; index < start + columns; index++)
                      Expanded(
                        child: index < highlights.length
                            ? _HighlightTile(
                                controller: controller,
                                highlight: highlights[index],
                                onAuthorize: onAuthorize,
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The tile of one highlight; its tooltip names the plugin call behind it.
class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.controller, required this.highlight, required this.onAuthorize});

  final OverviewController controller;
  final Highlight highlight;
  final ValueChanged<Highlight> onAuthorize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = controller.highlight(highlight);
    final display = HighlightDisplay.of(highlight, state, platform: controller.platform);
    final (background, foreground) = _iconColors(highlight, scheme);
    return Tooltip(
      message: highlight.method,
      child: MetricTile(
        label: highlight.label,
        value: display.value,
        unit: display.unit,
        icon: highlight.icon,
        shape: highlight.shape,
        iconBackground: background,
        iconForeground: foreground,
        footnote: display.footnote,
        loading: display.loading,
        error: display.error,
        onTap: _action(context, display, state.errorOrNull),
      ),
    );
  }

  /// Varies the icon accent across primary, secondary and tertiary containers for visual rhythm.
  static (Color, Color) _iconColors(Highlight highlight, ColorScheme scheme) => switch (highlight) {
    Highlight.steps || Highlight.workouts => (scheme.primaryContainer, scheme.onPrimaryContainer),
    Highlight.heartRate || Highlight.activeEnergy => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    Highlight.weight || Highlight.sleep => (scheme.secondaryContainer, scheme.onSecondaryContainer),
  };

  /// What tapping the tile does, or null for a static tile.
  VoidCallback? _action(BuildContext context, HighlightDisplay display, Object? error) => switch (display.tap) {
    HighlightTap.none => null,
    HighlightTap.authorize => () => onAuthorize(highlight),
    HighlightTap.showError when error != null => () => showErrorDialog(context, error),
    HighlightTap.showError => null,
    HighlightTap.openPoint => switch (display.point) {
      final point? => () => showDataPointSheet(context, point),
      null => null,
    },
    HighlightTap.openWorkouts => switch (controller.workouts.valueOrNull) {
      final week? => () => showWorkoutsSheet(context, week),
      null => null,
    },
  };
}
