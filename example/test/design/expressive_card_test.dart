import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

import 'design_test_app.dart';

void main() {
  testWidgets('calls onTap when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(designTestApp(ExpressiveCard(onTap: () => taps++, child: const Text('Steps'))));

    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('tightens its corners while pressed and springs back', (tester) async {
    await tester.pumpWidget(designTestApp(ExpressiveCard(onTap: () {}, child: const Text('Steps'))));
    double radius() =>
        ((materialShapeAround(find.text('Steps'))! as RoundedRectangleBorder).borderRadius as BorderRadius).topLeft.x;
    expect(radius(), ExpressiveShapes.extraLarge);

    final press = await tester.startGesture(tester.getCenter(find.text('Steps')));
    await tester.pump(); // the press starts the spring
    await tester.pump(const Duration(milliseconds: 400));
    expect(radius(), lessThan(ExpressiveShapes.extraLarge));

    await press.up();
    await tester.pumpAndSettle();
    expect(radius(), moreOrLessEquals(ExpressiveShapes.extraLarge));
  });

  testWidgets('is not a button without onTap', (tester) async {
    await tester.pumpWidget(designTestApp(const ExpressiveCard(child: Text('Static'))));

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('colours itself and its text for each variant', (tester) async {
    final scheme = ExpressiveTheme.light().colorScheme;
    for (final variant in ExpressiveCardVariant.values) {
      await tester.pumpWidget(
        designTestApp(
          ExpressiveCard(
            variant: variant,
            // Styled from the text theme, as feature code does: the card must still recolour it.
            child: Builder(builder: (context) => Text('Label', style: Theme.of(context).textTheme.titleMedium)),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.ancestor(of: find.text('Label'), matching: find.byType(Material)).first,
      );
      expect(material.color, variant.backgroundIn(scheme), reason: variant.name);
      final text = tester.widget<RichText>(find.descendant(of: find.text('Label'), matching: find.byType(RichText)));
      expect(text.text.style!.color, variant.foregroundIn(scheme), reason: variant.name);
    }
  });
}
