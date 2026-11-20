/// The Material 3 Expressive shape library as polar outlines, so that any two shapes can morph into each
/// other.
///
/// Every [ExpressiveShape] is star-shaped around its centre, so its outline is fully described by its
/// radius in each direction. The radii are sampled once, at [ExpressiveShape.sampleCount] evenly spaced
/// angles, and cached. Morphing two shapes ([lerpRadii]) interpolates the radii angle by angle, which
/// always gives a smooth outline in between, and [polarPath] turns radii into a [Path].
library;

import 'dart:math' as math;
import 'dart:ui';

/// The shapes of the Material 3 Expressive shape library that the app uses for shaped icons and the
/// loading indicator.
enum ExpressiveShape {
  /// A circle.
  circle,

  /// A rounded square of four soft lobes ("4-sided cookie").
  cookie4,

  /// Six shallow scallops ("6-sided cookie").
  cookie6,

  /// Seven shallow scallops ("7-sided cookie").
  cookie7,

  /// Nine shallow scallops ("9-sided cookie"), the default of shaped icons.
  cookie9,

  /// Twelve shallow scallops ("12-sided cookie").
  cookie12,

  /// An eight-pointed star with very round points.
  sunny,

  /// An eight-pointed star with pronounced points.
  verySunny,

  /// Four round leaves.
  clover4,

  /// Eight round leaves.
  clover8,

  /// A ten-pointed burst with rounded points.
  softBurst,

  /// A pentagon with rounded corners.
  pentagon,

  /// A diagonal capsule.
  pill,

  /// A diagonal ellipse.
  oval,

  /// Eight petals.
  flower,

  /// A cloud of six puffs.
  puffy;

  /// The number of directions each outline is sampled in: every 2 degrees.
  static const int sampleCount = 180;

  static final List<List<double>?> _cache = List.filled(values.length, null);

  /// The outline's radius in each of [sampleCount] directions, clockwise from the positive x axis, scaled
  /// so that the largest radius is 1. Computed on first use and cached.
  List<double> get radii => _cache[index] ??= List.unmodifiable(_sample(_outline));

  _Outline get _outline => switch (this) {
    ExpressiveShape.circle => const _Circle(),
    ExpressiveShape.cookie4 => const _Lobes(count: 4, depth: 0.14, softness: 0.5, phase: math.pi / 4),
    ExpressiveShape.cookie6 => const _Lobes(count: 6, depth: 0.12, softness: 0.6),
    ExpressiveShape.cookie7 => const _Lobes(count: 7, depth: 0.11, softness: 0.6),
    ExpressiveShape.cookie9 => const _Lobes(count: 9, depth: 0.1, softness: 0.55),
    ExpressiveShape.cookie12 => const _Lobes(count: 12, depth: 0.08, softness: 0.55),
    ExpressiveShape.sunny => const _Lobes(count: 8, depth: 0.1, softness: 0.6, pointed: true),
    ExpressiveShape.verySunny => const _Lobes(count: 8, depth: 0.2, softness: 0.4, pointed: true),
    ExpressiveShape.clover4 => const _Lobes(count: 4, depth: 0.42, softness: 0.08, sharpness: 0.6, phase: math.pi / 4),
    ExpressiveShape.clover8 => const _Lobes(count: 8, depth: 0.26, softness: 0.08, sharpness: 0.7),
    ExpressiveShape.softBurst => const _Lobes(count: 10, depth: 0.14, softness: 0.75, pointed: true),
    ExpressiveShape.pentagon => const _RoundedPolygon(sides: 5, rounding: 0.22),
    ExpressiveShape.pill => const _Capsule(halfLength: 0.42, radius: 0.58, phase: math.pi / 4),
    ExpressiveShape.oval => const _Ellipse(ratio: 0.72, phase: -math.pi / 4),
    ExpressiveShape.flower => const _Lobes(count: 8, depth: 0.32, softness: 0.4, sharpness: 0.9),
    ExpressiveShape.puffy => const _Lobes(count: 6, depth: 0.22, softness: 0.1, sharpness: 0.6),
  };
}

/// The morph from outline [a] to outline [b] (both [ExpressiveShape.radii]-style lists of equal length)
/// at [t], interpolated direction by direction. [t] may overshoot 0..1 a little, as spring curves do;
/// the radii never go below zero.
List<double> lerpRadii(List<double> a, List<double> b, double t) => [
  for (var i = 0; i < a.length; i++) math.max(0.0, a[i] + (b[i] - a[i]) * t),
];

/// The closed outline with [radii] fitted into [rect] (a radius of 1 reaches its edges), turned
/// clockwise by [rotation] radians. Quadratic curves through the midpoints between the samples smooth
/// the outline, so it stays round even when drawn large.
Path polarPath(List<double> radii, Rect rect, {double rotation = 0}) {
  final count = radii.length;
  final center = rect.center;
  Offset point(int i) {
    final angle = rotation + 2 * math.pi * i / count;
    return center + Offset(math.cos(angle) * radii[i] * rect.width / 2, math.sin(angle) * radii[i] * rect.height / 2);
  }

  final path = Path();
  var current = point(0);
  final start = Offset.lerp(point(count - 1), current, 0.5)!;
  path.moveTo(start.dx, start.dy);
  for (var i = 1; i <= count; i++) {
    final next = point(i % count);
    final middle = Offset.lerp(current, next, 0.5)!;
    path.quadraticBezierTo(current.dx, current.dy, middle.dx, middle.dy);
    current = next;
  }
  return path..close();
}

List<double> _sample(_Outline outline) {
  const count = ExpressiveShape.sampleCount;
  final radii = [for (var i = 0; i < count; i++) outline.radiusAt(2 * math.pi * i / count)];
  final largest = radii.reduce(math.max);
  return [for (final radius in radii) radius / largest];
}

/// A polar outline: the distance from the centre to the edge in each direction.
abstract class _Outline {
  const _Outline();

  /// The radius in direction [angle] (radians, clockwise from the positive x axis), in any unit.
  double radiusAt(double angle);
}

class _Circle extends _Outline {
  const _Circle();

  @override
  double radiusAt(double angle) => 1;
}

/// [count] lobes around the edge, the first centred at [phase]. Between lobes the edge dips by [depth]
/// (a fraction of the radius) into a crease that [softness] rounds off. [sharpness] above 1 narrows the
/// lobes, below 1 fattens them. [pointed] gives the lobes rounded points and the creases round bottoms,
/// turning scallops into a star or burst.
class _Lobes extends _Outline {
  const _Lobes({
    required this.count,
    required this.depth,
    required this.softness,
    this.sharpness = 1,
    this.pointed = false,
    this.phase = -math.pi / 2,
  });

  final int count;
  final double depth, softness, sharpness, phase;
  final bool pointed;

  @override
  double radiusAt(double angle) {
    final x = count * (angle - phase) / 2;
    // 1 at the centre of a lobe, 0 in a crease; |cos| has its kink in the crease, |sin| at the tip.
    final wave = pointed ? 1 - _soften(math.sin(x).abs()) : _soften(math.cos(x).abs());
    return 1 - depth * (1 - math.pow(wave, sharpness));
  }

  /// [u] from 0 to 1, with the kink of the absolute value at 0 rounded off by [softness].
  double _soften(double u) =>
      (math.sqrt(u * u + softness * softness) - softness) / (math.sqrt(1 + softness * softness) - softness);
}

/// A regular polygon of [sides] sides with a corner at the top and corners rounded by [rounding] (a
/// fraction of its radius): every point within [rounding] of the polygon shrunk by [rounding].
class _RoundedPolygon extends _Outline {
  const _RoundedPolygon({required this.sides, required this.rounding});

  final int sides;
  final double rounding;

  static const double phase = -math.pi / 2;

  @override
  double radiusAt(double angle) => _rayToEdge(angle, (x, y) {
    final corner = 1 - rounding;
    final apothem = corner * math.cos(math.pi / sides);
    var inside = true;
    var nearest = double.infinity;
    for (var i = 0; i < sides; i++) {
      final a = phase + 2 * math.pi * i / sides;
      final b = phase + 2 * math.pi * (i + 1) / sides;
      if (x * math.cos((a + b) / 2) + y * math.sin((a + b) / 2) > apothem) inside = false;
      final edge = _distanceToSegment(
        x,
        y,
        corner * math.cos(a),
        corner * math.sin(a),
        corner * math.cos(b),
        corner * math.sin(b),
      );
      nearest = math.min(nearest, edge);
    }
    return inside || nearest <= rounding;
  });
}

/// A capsule along direction [phase]: every point within [radius] of a segment of half length
/// [halfLength] through the centre.
class _Capsule extends _Outline {
  const _Capsule({required this.halfLength, required this.radius, required this.phase});

  final double halfLength, radius, phase;

  @override
  double radiusAt(double angle) =>
      _rayToEdge(angle - phase, (x, y) => _distanceToSegment(x, y, -halfLength, 0, halfLength, 0) <= radius);
}

/// An ellipse whose long axis points along [phase], with the short axis [ratio] times the long one.
class _Ellipse extends _Outline {
  const _Ellipse({required this.ratio, required this.phase});

  final double ratio, phase;

  @override
  double radiusAt(double angle) {
    final along = math.cos(angle - phase), across = math.sin(angle - phase) / ratio;
    return 1 / math.sqrt(along * along + across * across);
  }
}

/// The distance from the centre to the edge of a region containing the centre and star-shaped around
/// it, along direction [angle], found by bisection on [contains].
double _rayToEdge(double angle, bool Function(double x, double y) contains) {
  final dx = math.cos(angle), dy = math.sin(angle);
  var inside = 0.0, outside = 2.0;
  for (var i = 0; i < 30; i++) {
    final middle = (inside + outside) / 2;
    if (contains(dx * middle, dy * middle)) {
      inside = middle;
    } else {
      outside = middle;
    }
  }
  return inside;
}

double _distanceToSegment(double px, double py, double ax, double ay, double bx, double by) {
  final abx = bx - ax, aby = by - ay;
  final t = (((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby)).clamp(0.0, 1.0);
  final cx = ax + abx * t - px, cy = ay + aby * t - py;
  return math.sqrt(cx * cx + cy * cy);
}
