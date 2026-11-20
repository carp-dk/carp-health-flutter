import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

import 'design_test_app.dart';

void main() {
  test('every shape is sampled in every direction and scaled to a largest radius of 1', () {
    for (final shape in ExpressiveShape.values) {
      final radii = shape.radii;
      expect(radii, hasLength(ExpressiveShape.sampleCount), reason: shape.name);
      expect(radii.reduce(math.max), moreOrLessEquals(1), reason: shape.name);
      expect(radii.reduce(math.min), greaterThan(0.5), reason: '${shape.name} stays a solid shape');
    }
  });

  test('a morph starts at one shape and ends at the other', () {
    final from = ExpressiveShape.cookie9.radii;
    final to = ExpressiveShape.pentagon.radii;

    expect(lerpRadii(from, to, 0), from);
    expect(lerpRadii(from, to, 1), to);
    final halfway = lerpRadii(from, to, 0.5);
    for (var i = 0; i < halfway.length; i++) {
      expect(halfway[i], moreOrLessEquals((from[i] + to[i]) / 2));
    }
  });

  test('a morph never turns radii negative when a spring overshoots', () {
    final overshoot = lerpRadii(ExpressiveShape.circle.radii, ExpressiveShape.clover4.radii, 3);
    expect(overshoot.every((radius) => radius >= 0), isTrue);
  });

  test('outlines fit their rect', () {
    const rect = Rect.fromLTWH(10, 20, 100, 100);
    for (final shape in ExpressiveShape.values) {
      final bounds = polarPath(shape.radii, rect, rotation: 0.3).getBounds();
      expect(rect.inflate(0.5).contains(bounds.topLeft), isTrue, reason: shape.name);
      expect(rect.inflate(0.5).contains(bounds.bottomRight), isTrue, reason: shape.name);
    }
  });

  test('borders of two shapes interpolate into a morph', () {
    const from = ExpressiveShapeBorder(shape: ExpressiveShape.cookie9);
    const to = ExpressiveShapeBorder(shape: ExpressiveShape.pill);

    final halfway = ShapeBorder.lerp(from, to, 0.5)! as ExpressiveShapeBorder;

    expect(halfway.shape, ExpressiveShape.pill);
    expect(halfway.radii, lerpRadii(from.radii, to.radii, 0.5));
    expect(ShapeBorder.lerp(from, to, 1), to);
  });

  testWidgets('ShapedIcon morphs its shape when it changes', (tester) async {
    Widget icon(ExpressiveShape shape) => designTestApp(ShapedIcon(icon: Icons.favorite, shape: shape));
    List<double> radii() =>
        ((tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration! as ShapeDecoration).shape
                as ExpressiveShapeBorder)
            .radii;
    ShapeBorder painted() =>
        (tester
                    .renderObject<RenderDecoratedBox>(
                      find.descendant(of: find.byType(ShapedIcon), matching: find.byType(DecoratedBox)),
                    )
                    .decoration
                as ShapeDecoration)
            .shape;

    await tester.pumpWidget(icon(ExpressiveShape.cookie9));
    await tester.pumpWidget(icon(ExpressiveShape.sunny));
    await tester.pump(const Duration(milliseconds: 80));

    // Mid-morph the painted outline is neither shape; at the end it is the new one.
    final midway = (painted() as ExpressiveShapeBorder).radii;
    expect(midway, isNot(ExpressiveShape.cookie9.radii));
    expect(midway, isNot(ExpressiveShape.sunny.radii));
    await tester.pumpAndSettle();
    expect((painted() as ExpressiveShapeBorder).radii, ExpressiveShape.sunny.radii);
    expect(radii(), ExpressiveShape.sunny.radii);
  });
}
