/// An [OutlinedBorder] in the outline of an [ExpressiveShape], which morphs into other expressive shapes
/// whenever Flutter animates a shape (`AnimatedContainer`, `Material`, `ShapeBorderTween`).
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'polygon_shapes.dart';

/// A border in the outline of [shape], turned clockwise by [rotation] radians.
///
/// Interpolating two of these borders morphs one outline into the other ([lerpRadii]), so changing the
/// shape of a `ShapeDecoration` inside an `AnimatedContainer` animates the morph for free.
@immutable
class ExpressiveShapeBorder extends OutlinedBorder {
  /// A border in the outline of [shape], optionally turned by [rotation] and outlined by [side].
  const ExpressiveShapeBorder({this.shape = ExpressiveShape.circle, this.rotation = 0, super.side}) : _radii = null;

  /// A border part way through a morph, with explicit [radii]; [shape] is the shape it morphs towards.
  const ExpressiveShapeBorder._morph(List<double> radii, {required this.shape, required this.rotation, super.side})
    : _radii = radii;

  /// The shape of the outline (while morphing: the shape it is heading to).
  final ExpressiveShape shape;

  /// How far the outline is turned, clockwise, in radians.
  final double rotation;

  final List<double>? _radii;

  /// The outline's radii: the [shape]'s, or the in-between radii of a morph.
  List<double> get radii => _radii ?? shape.radii;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      polarPath(radii, rect.deflate(side.strokeInset), rotation: rotation);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => polarPath(radii, rect, rotation: rotation);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    // The stroke's centre line lies strokeOffset / 2 outside the rect (inside for the default alignment).
    canvas.drawPath(polarPath(radii, rect.inflate(side.strokeOffset / 2), rotation: rotation), side.toPaint());
  }

  @override
  ExpressiveShapeBorder scale(double t) =>
      ExpressiveShapeBorder._morph(radii, shape: shape, rotation: rotation, side: side.scale(t));

  @override
  ExpressiveShapeBorder copyWith({BorderSide? side, ExpressiveShape? shape, double? rotation}) =>
      shape == null && _radii != null
      ? ExpressiveShapeBorder._morph(
          _radii,
          shape: this.shape,
          rotation: rotation ?? this.rotation,
          side: side ?? this.side,
        )
      : ExpressiveShapeBorder(shape: shape ?? this.shape, rotation: rotation ?? this.rotation, side: side ?? this.side);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is ExpressiveShapeBorder) return _between(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is ExpressiveShapeBorder) return _between(this, b, t);
    return super.lerpTo(b, t);
  }

  /// The morph from [a] to [b] at [t]; exactly [a] or [b] at the ends, so a finished animation rests on
  /// the plain shape rather than on recomputed (and slightly rounded) radii.
  static ExpressiveShapeBorder _between(ExpressiveShapeBorder a, ExpressiveShapeBorder b, double t) {
    if (t == 0) return a;
    if (t == 1) return b;
    return ExpressiveShapeBorder._morph(
      lerpRadii(a.radii, b.radii, t),
      shape: b.shape,
      rotation: lerpDouble(a.rotation, b.rotation, t)!,
      side: BorderSide.lerp(a.side, b.side, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExpressiveShapeBorder &&
      other.shape == shape &&
      other.rotation == rotation &&
      other.side == side &&
      listEquals(other._radii, _radii);

  @override
  int get hashCode => Object.hash(shape, rotation, side, _radii == null ? null : Object.hashAll(_radii));

  @override
  String toString() => 'ExpressiveShapeBorder(${shape.name}${_radii == null ? '' : ', morphing'})';
}
