/// The Material 3 Expressive FAB menu: a floating action button that opens a stack of labelled actions.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import '../theme/expressive_shapes.dart';

/// One action of a [FabMenu].
@immutable
class FabMenuItem {
  /// Creates an action shown with [icon] and [label] that runs [onPressed].
  const FabMenuItem({required this.icon, required this.label, required this.onPressed});

  /// The icon before the label.
  final IconData icon;

  /// What the action does, in a few words.
  final String label;

  /// Runs the action; the menu has closed by then.
  final VoidCallback onPressed;
}

/// A floating action button that expands into a stack of labelled pill buttons ([items]) above it.
///
/// Opening morphs the button into a round close button in the primary colour (its [icon] turns into a
/// close icon) while the items spring in from the button, nearest first. Choosing an item closes the menu
/// and runs it; so do tapping outside the menu and the back gesture. Use it as a
/// `Scaffold.floatingActionButton`.
class FabMenu extends StatefulWidget {
  /// Creates a FAB menu.
  const FabMenu({super.key, required this.items, this.icon = Icons.add, this.tooltip});

  /// The actions, top to bottom.
  final List<FabMenuItem> items;

  /// The icon of the closed button.
  final IconData icon;

  /// The tooltip and accessibility label of the closed button.
  final String? tooltip;

  @override
  State<FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<FabMenu> with SingleTickerProviderStateMixin {
  // Unbounded, so that the spring can overshoot: the items bounce a little past their place.
  late final AnimationController _progress = AnimationController.unbounded(vsync: this);
  bool _open = false;

  static const double _buttonSize = 56;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (open == _open) return;
    setState(() => _open = open);
    final spring = open ? ExpressiveMotion.spatialDefault : ExpressiveMotion.spatialFast;
    // Starting from the current value and velocity keeps the motion continuous when interrupted.
    _progress.animateWith(spring.simulation(from: _progress.value, to: open ? 1 : 0, velocity: _progress.velocity));
  }

  void _run(FabMenuItem item) {
    _setOpen(false);
    item.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // While open, the back gesture closes the menu instead of leaving the page.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setOpen(false);
      },
      child: TapRegion(
        onTapOutside: _open ? (_) => _setOpen(false) : null,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_progress.value > 0.001)
                IgnorePointer(
                  ignoring: !_open,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 4,
                      children: [for (var i = 0; i < widget.items.length; i++) _item(i)],
                    ),
                  ),
                ),
              _toggle(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Item [index] (from the top), springing in with a short delay per step away from the button.
  Widget _item(int index) {
    final stepsFromButton = widget.items.length - 1 - index;
    final delay = math.min(0.5, 0.08 * stepsFromButton);
    final shown = (_progress.value - delay) / (1 - delay);
    return Opacity(
      opacity: shown.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - shown)),
        child: Transform.scale(
          scale: 0.6 + 0.4 * shown,
          alignment: AlignmentDirectional.centerEnd,
          child: _FabMenuItemButton(item: widget.items[index], onPressed: () => _run(widget.items[index])),
        ),
      ),
    );
  }

  /// The button, morphing from a rounded square in the primary container colour into a round close
  /// button in the primary colour as the menu opens.
  Widget _toggle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = _progress.value;
    final tint = open.clamp(0.0, 1.0);
    final foreground = Color.lerp(scheme.onPrimaryContainer, scheme.onPrimary, tint)!;
    final label = _open ? 'Close menu' : (widget.tooltip ?? 'Open menu');
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        expanded: _open,
        child: Material(
          color: Color.lerp(scheme.primaryContainer, scheme.primary, tint),
          elevation: 3,
          shadowColor: scheme.shadow,
          animationDuration: Duration.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(lerpDouble(16, _buttonSize / 2, open)!.clamp(8.0, _buttonSize / 2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _setOpen(!_open),
            child: SizedBox.square(
              dimension: _buttonSize,
              // The icon turns a quarter while it cross-fades into the close icon.
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 1 - tint,
                    child: Transform.rotate(
                      angle: open * math.pi / 2,
                      child: Icon(widget.icon, color: foreground),
                    ),
                  ),
                  Opacity(
                    opacity: tint,
                    child: Transform.rotate(
                      angle: (open - 1) * math.pi / 2,
                      child: Icon(Icons.close, color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill button of one [FabMenuItem], in the primary container colours.
class _FabMenuItemButton extends StatelessWidget {
  const _FabMenuItemButton({required this.item, required this.onPressed});

  final FabMenuItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer,
      elevation: 2,
      shadowColor: scheme.shadow,
      shape: ExpressiveShapes.stadium,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 24, 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Icon(item.icon, color: scheme.onPrimaryContainer),
              Text(item.label, style: theme.textTheme.titleMedium!.copyWith(color: scheme.onPrimaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}
