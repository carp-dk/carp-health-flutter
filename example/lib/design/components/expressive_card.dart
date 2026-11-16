/// The app's card: a rounded container in one of four colour styles that morphs when pressed.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import '../theme/expressive_shapes.dart';

/// The colour styles of an [ExpressiveCard].
enum ExpressiveCardVariant {
  /// The highest surface container colour: the default for content blocks.
  filled,

  /// The secondary container colour: related, secondary content.
  tonal,

  /// The page's surface colour with an outline: quiet, optional content.
  outlined,

  /// The primary container colour: hero content and calls to action.
  vibrant;

  /// The container colour of this style in [scheme].
  Color backgroundIn(ColorScheme scheme) => switch (this) {
    filled => scheme.surfaceContainerHighest,
    tonal => scheme.secondaryContainer,
    outlined => scheme.surface,
    vibrant => scheme.primaryContainer,
  };

  /// The colour of text and icons on this style in [scheme].
  Color foregroundIn(ColorScheme scheme) => switch (this) {
    filled || outlined => scheme.onSurface,
    tonal => scheme.onSecondaryContainer,
    vibrant => scheme.onPrimaryContainer,
  };
}

/// A card with [ExpressiveShapes.extraLarge] corners (or [radius]) in one of the [ExpressiveCardVariant]
/// colour styles.
///
/// Text and icons inside take the variant's content colour, including text styled from the theme's text
/// theme. With [onTap] the card is a button: it shows an ink ripple and, while pressed, shrinks slightly
/// and tightens its corners, springing back when released.
class ExpressiveCard extends StatefulWidget {
  /// Creates a card around [child].
  const ExpressiveCard({
    super.key,
    required this.child,
    this.variant = ExpressiveCardVariant.filled,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.radius,
  });

  /// The content.
  final Widget child;

  /// The colour style.
  final ExpressiveCardVariant variant;

  /// The space around [child].
  final EdgeInsetsGeometry padding;

  /// Called when the card is tapped; null makes the card static.
  final VoidCallback? onTap;

  /// The corner radius; [ExpressiveShapes.extraLarge] by default.
  final double? radius;

  @override
  State<ExpressiveCard> createState() => _ExpressiveCardState();
}

class _ExpressiveCardState extends State<ExpressiveCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = widget.variant.foregroundIn(scheme);
    final radius = widget.radius ?? ExpressiveShapes.extraLarge;
    final side = widget.variant == ExpressiveCardVariant.outlined
        ? BorderSide(color: scheme.outlineVariant)
        : BorderSide.none;

    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (foreground != scheme.onSurface) {
      // Text styled from the text theme carries the theme's onSurface colour, which would override an
      // ambient default; recolouring the text theme reaches it too.
      content = Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(bodyColor: foreground, displayColor: foreground),
          iconTheme: theme.iconTheme.copyWith(color: foreground),
        ),
        child: content,
      );
    }
    content = DefaultTextStyle.merge(
      style: TextStyle(color: foreground),
      child: IconTheme.merge(
        data: IconThemeData(color: foreground),
        child: content,
      ),
    );
    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        child: content,
      );
    }

    const motion = ExpressiveMotion.spatialFast;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _pressed ? 1 : 0),
      duration: motion.duration,
      curve: motion,
      child: content,
      builder: (context, press, child) => Transform.scale(
        scale: 1 - 0.02 * press,
        child: Material(
          color: widget.variant.backgroundIn(scheme),
          // The spring above animates the corners; Material must not ease them a second time.
          animationDuration: Duration.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(math.max(0, radius * (1 - 0.3 * press))),
            side: side,
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}
