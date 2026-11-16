import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

import 'design_test_app.dart';

void main() {
  group('ExpressiveLoadingIndicator', () {
    testWidgets('morphs through a whole cycle without errors, plain and contained', (tester) async {
      await tester.pumpWidget(
        designTestApp(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [ExpressiveLoadingIndicator(), ExpressiveLoadingIndicator(contained: true, size: 96)],
          ),
        ),
      );

      // One cycle visits every shape of the sequence; run a little more than one.
      final cycle = ExpressiveLoadingIndicator.morphDuration * ExpressiveLoadingIndicator.sequence.length;
      for (var elapsed = Duration.zero; elapsed < cycle * 1.2; elapsed += const Duration(milliseconds: 50)) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Loading'), findsNWidgets(2));
      expect(tester.getSize(find.byType(ExpressiveLoadingIndicator).last), const Size.square(96));
    });

    testWidgets('stops its animation when removed', (tester) async {
      await tester.pumpWidget(designTestApp(const ExpressiveLoadingIndicator()));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(designTestApp(const SizedBox()));

      // pumpAndSettle fails if any animation keeps going: the indicator's ticker must have stopped.
      await tester.pumpAndSettle();
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    });
  });

  group('WavyProgressIndicator', () {
    testWidgets('shows determinate progress from 0 to 100 % without errors', (tester) async {
      for (final value in [0.0, 0.04, 0.5, 0.96, 1.0]) {
        await tester.pumpWidget(designTestApp(SizedBox(width: 300, child: WavyProgressIndicator(value: value))));
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('announces the percentage', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        designTestApp(const SizedBox(width: 300, child: WavyProgressIndicator(value: 0.5, semanticsLabel: 'Pages'))),
      );

      expect(tester.getSemantics(find.byType(WavyProgressIndicator)), isSemantics(label: 'Pages', value: '50%'));
      semantics.dispose();
    });

    testWidgets('runs indeterminately through a whole cycle without errors', (tester) async {
      await tester.pumpWidget(designTestApp(const SizedBox(width: 300, child: WavyProgressIndicator())));

      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(WavyProgressIndicator)), const Size(300, 12));
    });
  });
}
