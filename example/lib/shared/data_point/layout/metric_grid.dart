/// A grid of big numbers for the headline figures of a typed value, such as a workout's totals.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// A formatted amount such as "5.2 km" split into its number and its unit, which a [MetricTile] shows in
/// two sizes. Anything else, such as "420" or "1 h 35 min", stays whole as the number; null gives nulls.
(String? value, String? unit) splitAmount(String? formatted) {
  if (formatted == null) return (null, null);
  final match = RegExp(r'^([-\d.,]+) ([^\d\s]+)$').firstMatch(formatted);
  return match == null ? (formatted, null) : (match[1], match[2]);
}

/// Lays [tiles] (usually [MetricTile]s) out in equally wide columns: two on phones, three from
/// [wideBreakpoint] on. Tiles keep their own height.
class MetricGrid extends StatelessWidget {
  /// Creates a grid of [tiles].
  const MetricGrid({super.key, required this.tiles});

  /// The tiles, in reading order.
  final List<Widget> tiles;

  /// The width from which the grid has three columns.
  static const double wideBreakpoint = 560;

  /// The space between tiles.
  static const double spacing = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= wideBreakpoint ? 3 : 2;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
        );
      },
    );
  }
}
