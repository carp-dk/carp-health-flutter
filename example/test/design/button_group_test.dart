import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

import 'design_test_app.dart';

void main() {
  const full = Radius.circular(ConnectedButtonGroup.height / 2);
  const inner = Radius.circular(ConnectedButtonGroup.innerRadius);

  List<ButtonGroupSegment<String>> segments({bool changesEnabled = true}) => [
    const ButtonGroupSegment(value: 'query', label: 'Query', icon: Icons.search),
    const ButtonGroupSegment(value: 'lookup', label: 'Lookup'),
    ButtonGroupSegment(value: 'changes', label: 'Changes', enabled: changesEnabled),
  ];

  Widget group(String selected, {ValueChanged<String>? onSelected, bool changesEnabled = true}) => designTestApp(
    SizedBox(
      width: 360,
      child: ConnectedButtonGroup<String>(
        segments: segments(changesEnabled: changesEnabled),
        selected: selected,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  );

  BorderRadiusGeometry radiusOf(String label) =>
      (materialShapeAround(find.text(label))! as RoundedRectangleBorder).borderRadius;

  testWidgets('reports the tapped segments', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(group('query', onSelected: picked.add));

    await tester.tap(find.text('Lookup'));
    await tester.tap(find.text('Changes'));

    expect(picked, ['lookup', 'changes']);
  });

  testWidgets('ignores taps on disabled segments', (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(group('query', onSelected: picked.add, changesEnabled: false));

    await tester.tap(find.text('Changes'));

    expect(picked, isEmpty);
  });

  testWidgets('marks only the selected segment as selected for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(group('lookup'));

    expect(
      tester.getSemantics(find.text('Lookup')),
      isSemantics(isButton: true, isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    expect(tester.getSemantics(find.text('Query')), isSemantics(isButton: true, isSelected: false));
    semantics.dispose();
  });

  testWidgets('connects the segments: outer corners full, inner corners small', (tester) async {
    await tester.pumpWidget(group('query'));

    // The selected first segment is a full pill; the others keep small corners towards their neighbours.
    expect(radiusOf('Query'), const BorderRadiusDirectional.horizontal(start: full, end: full));
    expect(radiusOf('Lookup'), const BorderRadiusDirectional.horizontal(start: inner, end: inner));
    expect(radiusOf('Changes'), const BorderRadiusDirectional.horizontal(start: inner, end: full));
  });

  testWidgets('morphs a newly selected segment into a pill', (tester) async {
    await tester.pumpWidget(group('query'));
    await tester.pumpWidget(group('lookup'));

    // Part way through the spring the corners are between the two shapes.
    await tester.pump(const Duration(milliseconds: 60));
    final halfway = radiusOf('Lookup') as BorderRadiusDirectional;
    expect(halfway.topStart.x, greaterThan(inner.x));
    expect(halfway.topStart.x, lessThan(full.x));

    await tester.pumpAndSettle();
    expect(radiusOf('Lookup'), const BorderRadiusDirectional.horizontal(start: full, end: full));
    expect(radiusOf('Query'), const BorderRadiusDirectional.horizontal(start: full, end: inner));
  });

  testWidgets('widens a pressed segment and springs back on release', (tester) async {
    await tester.pumpWidget(group('query'));
    final segment = find.ancestor(of: find.text('Lookup'), matching: find.byType(Material)).first;
    final restingWidth = tester.getSize(segment).width;

    final press = await tester.startGesture(tester.getCenter(find.text('Lookup')));
    await tester.pump(); // the press starts the spring
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(segment).width, greaterThan(restingWidth));

    await press.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(segment).width, moreOrLessEquals(restingWidth, epsilon: 0.5));
  });
}
