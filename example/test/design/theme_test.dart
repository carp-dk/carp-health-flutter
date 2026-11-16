import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

void main() {
  group('ExpressiveMotion springs', () {
    List<double> samples(Curve curve) => [for (var i = 0; i <= 100; i++) curve.transform(i / 100)];

    test('start at 0 and end exactly at 1', () {
      for (final spring in [
        ExpressiveMotion.spatialFast,
        ExpressiveMotion.spatialDefault,
        ExpressiveMotion.spatialSlow,
        ExpressiveMotion.effectsFast,
        ExpressiveMotion.effectsDefault,
        ExpressiveMotion.effectsSlow,
      ]) {
        expect(spring.transform(0), 0, reason: '$spring');
        expect(spring.transform(1), 1, reason: '$spring');
        // No jump just before the end: the spring has settled.
        expect(spring.transform(0.99), moreOrLessEquals(1, epsilon: 0.01), reason: '$spring');
      }
    });

    test('spatial springs overshoot, effects springs never do', () {
      expect(samples(ExpressiveMotion.spatialFast).reduce((a, b) => a > b ? a : b), greaterThan(1.05));
      for (final spring in [
        ExpressiveMotion.effectsFast,
        ExpressiveMotion.effectsDefault,
        ExpressiveMotion.effectsSlow,
      ]) {
        final values = samples(spring);
        for (var i = 1; i < values.length; i++) {
          expect(values[i], greaterThanOrEqualTo(values[i - 1] - 1e-9), reason: '$spring rises monotonically');
          expect(values[i], lessThanOrEqualTo(1 + 1e-9), reason: '$spring stays below 1');
        }
      }
    });

    test('simulations snap exactly to their end', () {
      final simulation = ExpressiveMotion.spatialDefault.simulation(from: 0.2, to: 1, velocity: 3);
      expect(simulation.x(0), moreOrLessEquals(0.2));
      expect(simulation.x(5), 1);
    });

    test('clampToUnit keeps an overshooting value within 0..1', () {
      expect(ExpressiveMotion.clampToUnit.transform(1.08), 1);
      expect(ExpressiveMotion.clampToUnit.transform(-0.02), 0);
      expect(ExpressiveMotion.clampToUnit.transform(0.4), 0.4);
    });
  });

  group('ExpressiveTypography', () {
    test('emphasizes by two weight steps and tightens big type', () {
      const headline = TextStyle(fontSize: 32, fontWeight: FontWeight.w400);
      expect(ExpressiveTypography.emphasized(headline).fontWeight, FontWeight.w600);
      expect(ExpressiveTypography.emphasized(headline).letterSpacing, lessThan(0));

      const label = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1);
      expect(ExpressiveTypography.emphasized(label).fontWeight, FontWeight.w700);
      expect(ExpressiveTypography.emphasized(label).letterSpacing, 0.1);
      expect(ExpressiveTypography.heavier(FontWeight.w800), FontWeight.w900);
    });

    test('builds a complete text theme with sizes', () {
      final text = ExpressiveTypography.textTheme(ExpressiveColors.scheme(Brightness.light));
      expect(text.headlineLarge!.fontSize, 32);
      expect(text.labelMedium!.fontSize, 12);
      expect(text.headlineLargeEmphasized.fontWeight, FontWeight.w600);
    });
  });

  group('ExpressiveTheme', () {
    test('has light and dark expressive schemes with status colours', () {
      final light = ExpressiveTheme.light();
      final dark = ExpressiveTheme.dark();

      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.extension<ExpressiveStatusColors>(), isNotNull);
      expect(
        dark.extension<ExpressiveStatusColors>()!.success,
        isNot(light.extension<ExpressiveStatusColors>()!.success),
      );
    });

    test('wires the expressive shapes into the components', () {
      final theme = ExpressiveTheme.light();
      final buttonShape = theme.filledButtonTheme.style!.shape!;

      expect(buttonShape.resolve({}), isA<StadiumBorder>());
      expect(buttonShape.resolve({WidgetState.pressed}), ExpressiveShapes.rounded(ExpressiveShapes.medium));
      expect(theme.cardTheme.shape, ExpressiveShapes.rounded(ExpressiveShapes.extraLarge));
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.navigationBarTheme.indicatorShape, isA<StadiumBorder>());
      expect(theme.chipTheme.shape, isA<StadiumBorder>());
    });
  });

  testWidgets('status colours fall back to the scheme without the theme extension', (tester) async {
    late ExpressiveStatusColors colors;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            colors = ExpressiveStatusColors.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(colors.error, ThemeData().colorScheme.errorContainer);
  });
}
