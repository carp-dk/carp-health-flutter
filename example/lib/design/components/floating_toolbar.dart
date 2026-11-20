/// The Material 3 Expressive floating toolbar: a pill of actions that floats above the content.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import '../theme/expressive_shapes.dart';

/// A floating toolbar for the actions on what a screen shows (for example sorting or clearing results).
///
/// It is a quiet surface-coloured pill by default, or a vibrant one (primary container colour), with
/// the [children] in a row: plain `IconButton`s, which take the toolbar's content colour (as icon buttons
/// in an app bar do), and optionally an `IconButton.filledTonal` for the main action. It springs up into
/// place when it first appears. Place it over the content, for example as a
/// `Scaffold.floatingActionButton` with `FloatingActionButtonLocation.centerFloat`.
class FloatingToolbar extends StatelessWidget {
  /// Creates a floating toolbar.
  const FloatingToolbar({super.key, required this.children, this.vibrant = true});

  /// The actions, in reading order.
  final List<Widget> children;

  /// Whether to use the vibrant primary container colours rather than the surface container ones.
  final bool vibrant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = vibrant ? scheme.primaryContainer : scheme.surfaceContainerHigh;
    final foreground = vibrant ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    const motion = ExpressiveMotion.spatialDefault;
    final duration = ExpressiveMotion.reduceMotion(context) ? Duration.zero : motion.duration;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: motion,
      builder: (context, entrance, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - entrance)),
        child: Opacity(opacity: entrance.clamp(0.0, 1.0), child: child),
      ),
      child: Material(
        color: background,
        elevation: 3,
        shadowColor: scheme.shadow,
        shape: ExpressiveShapes.stadium,
        child: Padding(
          padding: const EdgeInsets.all(8),
          // Icon buttons take a non-default ambient icon colour as their foreground colour.
          child: IconTheme.merge(
            data: IconThemeData(color: foreground),
            child: Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: children),
          ),
        ),
      ),
    );
  }
}
