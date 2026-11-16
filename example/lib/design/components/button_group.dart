/// The Material 3 Expressive connected button group: a single-select row of segments that replaces the
/// segmented button.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import '../theme/expressive_shapes.dart';

/// One segment of a [ConnectedButtonGroup].
@immutable
class ButtonGroupSegment<T> {
  /// Creates a segment for [value], shown with [label] and an optional [icon].
  const ButtonGroupSegment({required this.value, required this.label, this.icon, this.enabled = true});

  /// The value [ConnectedButtonGroup.onSelected] reports when this segment is chosen.
  final T value;

  /// The segment's text.
  final String label;

  /// An icon before the label.
  final IconData? icon;

  /// Whether the segment can be chosen.
  final bool enabled;
}

/// A connected button group: segments 2 dp apart whose outer corners are fully round and whose inner
/// corners are small, so the row reads as one control.
///
/// The selected segment fills with the primary colour and morphs into a full pill; a pressed segment
/// widens a little, squeezing its neighbours, and springs back when released. Exactly one value is
/// selected; tapping another segment reports it through [onSelected] (the caller stores it and rebuilds
/// with the new [selected]).
class ConnectedButtonGroup<T> extends StatelessWidget {
  /// Creates a connected button group.
  const ConnectedButtonGroup({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.expand = true,
  });

  /// The segments, in order.
  final List<ButtonGroupSegment<T>> segments;

  /// The value of the selected segment.
  final T selected;

  /// Called with the value of the segment the user chose.
  final ValueChanged<T> onSelected;

  /// Whether the group fills the available width with equally wide segments; otherwise each segment is
  /// as wide as its content.
  final bool expand;

  /// The height of the segments.
  static const double height = 48;

  /// The space between segments.
  static const double gap = 2;

  /// The radius of the corners between two unselected segments.
  static const double innerRadius = ExpressiveShapes.small;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      spacing: gap,
      children: [
        for (var i = 0; i < segments.length; i++)
          _Segment<T>(
            segment: segments[i],
            selected: segments[i].value == selected,
            isFirst: i == 0,
            isLast: i == segments.length - 1,
            expand: expand,
            onTap: () => onSelected(segments[i].value),
          ),
      ],
    );
  }
}

/// One segment, animating its width, corners and colours with springs.
class _Segment<T> extends StatefulWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.expand,
    required this.onTap,
  });

  final ButtonGroupSegment<T> segment;
  final bool selected, isFirst, isLast, expand;
  final VoidCallback onTap;

  @override
  State<_Segment<T>> createState() => _SegmentState<T>();
}

class _SegmentState<T> extends State<_Segment<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const motion = ExpressiveMotion.spatialFast;
    // Two springs: one for the press (width), one for the selection (shape and colour).
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _pressed ? 1 : 0),
      duration: motion.duration,
      curve: motion,
      builder: (context, press, _) => _sized(
        press,
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: widget.selected ? 1 : 0),
          duration: motion.duration,
          curve: motion,
          builder: (context, selection, _) => _segment(context, press, selection),
        ),
      ),
    );
  }

  /// Gives the segment its width: a flex share that grows by 15 % while pressed, or extra padding when
  /// the group does not expand.
  Widget _sized(double press, Widget child) {
    if (widget.expand) return Expanded(flex: (1000 * (1 + 0.15 * press)).round(), child: child);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6 * math.max(0, press)),
      child: child,
    );
  }

  Widget _segment(BuildContext context, double press, double selection) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = widget.segment.enabled;
    // Colours follow the selection without the spring's overshoot.
    final tint = selection.clamp(0.0, 1.0);
    final background = enabled
        ? Color.lerp(scheme.surfaceContainerHighest, scheme.primary, tint)!
        : scheme.onSurface.withValues(alpha: 0.12);
    final foreground = enabled
        ? Color.lerp(scheme.onSurfaceVariant, scheme.onPrimary, tint)!
        : scheme.onSurface.withValues(alpha: 0.38);
    // Outer corners stay fully round; inner corners round out into a pill as the segment is selected,
    // and tighten a little while it is pressed.
    const full = ConnectedButtonGroup.height / 2;
    final inner = (lerpDouble(ConnectedButtonGroup.innerRadius, full, selection)! - 4 * press).clamp(2.0, full);
    final radius = BorderRadiusDirectional.horizontal(
      start: Radius.circular(widget.isFirst ? full : inner),
      end: Radius.circular(widget.isLast ? full : inner),
    );
    final label = Text(
      widget.segment.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelLarge!.copyWith(
        color: foreground,
        fontWeight: FontWeight.lerp(FontWeight.w500, FontWeight.w700, tint),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: background,
        // The springs above animate the shape; Material must not ease it a second time.
        animationDuration: Duration.zero,
        shape: RoundedRectangleBorder(borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? widget.onTap : null,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          splashColor: foreground.withValues(alpha: 0.12),
          highlightColor: foreground.withValues(alpha: 0.08),
          child: SizedBox(
            height: ConnectedButtonGroup.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  if (widget.segment.icon case final icon?) Icon(icon, size: 18, color: foreground),
                  Flexible(child: label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
