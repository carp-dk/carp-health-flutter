/// A small map-less drawing of a workout route, and the route's length.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

/// The length of the route through [locations] in meters: the sum of the great-circle (haversine)
/// distances between consecutive locations.
double routeDistance(List<WorkoutRouteLocation> locations) {
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  var meters = 0.0;
  for (var i = 1; i < locations.length; i++) {
    final from = locations[i - 1], to = locations[i];
    final dLatitude = radians(to.latitude - from.latitude);
    final dLongitude = radians(to.longitude - from.longitude);
    final a =
        math.pow(math.sin(dLatitude / 2), 2) +
        math.cos(radians(from.latitude)) * math.cos(radians(to.latitude)) * math.pow(math.sin(dLongitude / 2), 2);
    meters += 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
  }
  return meters;
}

/// Draws the route through [locations] as a line fitted into the space it is given, north up, with a
/// dot at the start and a ringed dot at the end. Without a map it shows the route's shape only.
class RoutePreview extends StatelessWidget {
  /// Creates a drawing of the route through [locations].
  const RoutePreview({super.key, required this.locations});

  /// The route's locations, in order.
  final List<WorkoutRouteLocation> locations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Route of ${locations.length} locations',
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RoutePainter(locations, line: scheme.primary, start: scheme.tertiary, surface: scheme.surface),
        ),
      ),
    );
  }
}

/// Paints [locations] fitted into the canvas: the route in [line], a dot in [start] where it begins and a
/// ring with a [surface] centre where it ends.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.locations, {required this.line, required this.start, required this.surface});

  final List<WorkoutRouteLocation> locations;
  final Color line, start, surface;

  @override
  void paint(Canvas canvas, Size size) {
    if (locations.isEmpty) return;
    // An equirectangular projection, with longitudes shrunk by the cosine of the latitude, is true to
    // shape for the few kilometres of a workout.
    final latitude = locations.map((location) => location.latitude).reduce((a, b) => a + b) / locations.length;
    final shrink = math.cos(latitude * math.pi / 180);
    final points = [for (final location in locations) Offset(location.longitude * shrink, -location.latitude)];
    final bounds = points.skip(1).fold(Rect.fromPoints(points.first, points.first), (rect, point) {
      return rect.expandToInclude(Rect.fromPoints(point, point));
    });
    const margin = 12.0;
    final scale = math.min(
      (size.width - 2 * margin) / math.max(bounds.width, 1e-9),
      (size.height - 2 * margin) / math.max(bounds.height, 1e-9),
    );
    // Centre the route; a single location (no extent) lands in the middle.
    final offset = size.center(Offset.zero) - bounds.center * scale;
    final placed = [for (final point in points) point * scale + offset];

    final path = Path()..addPolygon(placed, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(placed.first, 7, Paint()..color = start);
    canvas.drawCircle(placed.last, 8, Paint()..color = line);
    canvas.drawCircle(placed.last, 4, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.locations != locations || oldDelegate.line != line || oldDelegate.start != start;
}
