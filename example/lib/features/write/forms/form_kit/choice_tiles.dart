/// A single choice among a few values, each a tile with an icon: a mindfulness session type, a
/// menstrual flow, an activity intensity.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// One choice of [ChoiceTiles]: a [value] shown with a [label] and an [icon].
@immutable
class ChoiceTile<T> {
  /// Creates the choice of [value].
  const ChoiceTile({required this.value, required this.label, required this.icon});

  /// The value [ChoiceTiles.onSelected] reports.
  final T value;

  /// The choice's name, such as "Breathing".
  final String label;

  /// The icon in the tile's shape.
  final IconData icon;
}

/// A grid of selectable tiles, one per choice, as many per row as fit [minTileWidth].
///
/// The selected tile takes the primary container colour, rounds its corners further and morphs its icon
/// from a circle into [selectedShape], all on springs, so the choice reads at a glance.
class ChoiceTiles<T> extends StatelessWidget {
  /// Creates tiles for [choices] with [selected] chosen.
  const ChoiceTiles({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.selectedShape = ExpressiveShape.cookie9,
    this.minTileWidth = 150,
  });

  /// The choices, in order.
  final List<ChoiceTile<T>> choices;

  /// The value of the selected choice.
  final T selected;

  /// Called with the value of the tile the user tapped.
  final ValueChanged<T> onSelected;

  /// The shape the selected tile's icon morphs into.
  final ExpressiveShape selectedShape;

  /// The narrowest a tile gets; fewer tiles share a row on narrow windows.
  final double minTileWidth;

  /// The space between tiles.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = math.max(1, math.min(choices.length, ((width + gap) / (minTileWidth + gap)).floor()));
        final tileWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final choice in choices)
              SizedBox(
                width: tileWidth,
                child: _Tile<T>(
                  choice: choice,
                  selected: choice.value == selected,
                  selectedShape: selectedShape,
                  onTap: () => onSelected(choice.value),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One tile, animating its colours, corners and icon shape.
class _Tile<T> extends StatelessWidget {
  const _Tile({required this.choice, required this.selected, required this.selectedShape, required this.onTap});

  final ChoiceTile<T> choice;
  final bool selected;
  final ExpressiveShape selectedShape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    const motion = ExpressiveMotion.spatialFast;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: selected ? 1 : 0),
        duration: motion.duration,
        curve: motion,
        builder: (context, selection, child) => Material(
          color: Color.lerp(scheme.surfaceContainerHighest, scheme.primaryContainer, selection.clamp(0.0, 1.0)),
          // The spring above animates the corners; Material must not ease them a second time.
          animationDuration: Duration.zero,
          shape: ExpressiveShapes.rounded(math.max(0, ExpressiveShapes.large + 12 * selection)),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              spacing: 12,
              children: [
                ShapedIcon(
                  icon: choice.icon,
                  shape: selected ? selectedShape : ExpressiveShape.circle,
                  size: 40,
                  background: selected ? scheme.primary : scheme.surfaceContainerLow,
                  foreground: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
                Expanded(
                  child: Text(
                    choice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (selected ? theme.textTheme.titleSmallEmphasized : theme.textTheme.titleSmall!).copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
