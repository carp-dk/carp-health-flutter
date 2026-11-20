import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';
import 'package:health_example/shared/visuals/recording_method_visuals.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import '../support/shared_test_app.dart';

void main() {
  group('categories', () {
    test('each has a shape of its own', () {
      expect(TypeCategory.values.map((category) => category.shape).toSet(), hasLength(TypeCategory.values.length));
    });

    test('all take the same calm container colours, so shapes tell them apart', () {
      final scheme = ExpressiveTheme.light().colorScheme;
      for (final category in TypeCategory.values) {
        expect(category.colorsIn(scheme), (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ), reason: category.name);
      }
      expect(TypeCategory.values.map((category) => category.shape).toSet(), hasLength(TypeCategory.values.length));
    });
  });

  group('TypeIcon', () {
    /// The shaped icon that the TypeIcon draws, and the colour scheme it is drawn in.
    (ShapedIcon, ColorScheme) drawn(WidgetTester tester) => (
      tester.widget<ShapedIcon>(find.byType(ShapedIcon)),
      Theme.of(tester.element(find.byType(ShapedIcon))).colorScheme,
    );

    testWidgets('draws a type in the shape and colours of its category', (tester) async {
      const type = HealthDataType.HEART_RATE;
      await tester.pumpWidget(sharedTestApp(TypeIcon(type: type, size: 56)));

      final (icon, scheme) = drawn(tester);
      expect((icon.icon, icon.shape, icon.size), (type.icon, type.category.shape, 56));
      expect((icon.background, icon.foreground), type.category.colorsIn(scheme));
    });

    testWidgets('draws a category with its own icon', (tester) async {
      await tester.pumpWidget(sharedTestApp(TypeIcon.category(category: TypeCategory.sleep)));

      final (icon, _) = drawn(tester);
      expect((icon.icon, icon.shape), (TypeCategory.sleep.icon, TypeCategory.sleep.shape));
    });
  });

  test('recording methods: measured data reads as success, entered data as information', () {
    expect(RecordingMethod.values.map((method) => method.label).toSet(), hasLength(RecordingMethod.values.length));
    expect(RecordingMethod.automatic.tone, StatusTone.success);
    expect(RecordingMethod.active.tone, StatusTone.success);
    expect(RecordingMethod.manual.tone, StatusTone.info);
    expect(RecordingMethod.unknown.tone, StatusTone.neutral);
  });

  test('monospace keeps the style and falls back to fonts that iOS has', () {
    const style = TextStyle(fontSize: 12, color: Color(0xFF123456));

    final monospace = style.monospace;
    expect(monospace.fontFamily, 'monospace');
    expect(monospace.fontFamilyFallback, ['Menlo', 'Courier']);
    expect((monospace.fontSize, monospace.color), (12, const Color(0xFF123456)));
  });
}
