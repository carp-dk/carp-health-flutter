/// An icon set in one of the Material 3 Expressive shapes, which morphs when the shape changes.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import 'expressive_shape_border.dart';
import 'polygon_shapes.dart';

export 'polygon_shapes.dart' show ExpressiveShape;

/// An [icon] centred in a filled [shape], as the app shows data type categories, metrics and empty states.
///
/// Changing [shape], [size] or the colours animates: the outline morphs into the new shape on the default
/// spatial spring. The colours default to the primary container pair.
class ShapedIcon extends StatelessWidget {
  /// Creates a shaped icon.
  const ShapedIcon({
    super.key,
    required this.icon,
    this.shape = ExpressiveShape.cookie9,
    this.size = 48,
    this.background,
    this.foreground,
  });

  /// The icon in the middle, half as large as the shape.
  final IconData icon;

  /// The outline behind the icon.
  final ExpressiveShape shape;

  /// The width and height of the shape.
  final double size;

  /// The shape's colour; the primary container colour by default.
  final Color? background;

  /// The icon's colour; the on-primary-container colour by default.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const motion = ExpressiveMotion.spatialDefault;
    final duration = ExpressiveMotion.reduceMotion(context) ? Duration.zero : motion.duration;
    return AnimatedContainer(
      duration: duration,
      curve: motion,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: background ?? scheme.primaryContainer,
        shape: ExpressiveShapeBorder(shape: shape),
      ),
      child: Icon(icon, size: size / 2, color: foreground ?? scheme.onPrimaryContainer),
    );
  }
}
