import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

import 'design_test_app.dart';

void main() {
  const outer = Radius.circular(SegmentedList.outerRadius);
  const inner = Radius.circular(SegmentedList.innerRadius);

  Widget list(List<String> titles) => designTestApp(
    SizedBox(
      width: 320,
      child: SegmentedList(
        children: [for (final title in titles) ListTile(title: Text(title), onTap: () {})],
      ),
    ),
  );

  BorderRadiusGeometry radiusOf(String title) =>
      (materialShapeAround(find.text(title))! as RoundedRectangleBorder).borderRadius;

  testWidgets('rounds the ends of the group and keeps the corners between items small', (tester) async {
    await tester.pumpWidget(list(['First', 'Middle', 'Last']));

    expect(radiusOf('First'), const BorderRadius.vertical(top: outer, bottom: inner));
    expect(radiusOf('Middle'), const BorderRadius.vertical(top: inner, bottom: inner));
    expect(radiusOf('Last'), const BorderRadius.vertical(top: inner, bottom: outer));
  });

  testWidgets('rounds both ends of a single item', (tester) async {
    await tester.pumpWidget(list(['Only']));

    expect(radiusOf('Only'), const BorderRadius.vertical(top: outer, bottom: outer));
  });

  testWidgets('puts the items 2 dp apart', (tester) async {
    await tester.pumpWidget(list(['First', 'Second']));
    Rect segment(String title) =>
        tester.getRect(find.ancestor(of: find.text(title), matching: find.byType(Material)).first);

    expect(segment('Second').top - segment('First').bottom, 2);
  });

  testWidgets('gives list tiles the shape of their segment for their ink', (tester) async {
    await tester.pumpWidget(list(['First', 'Last']));

    final tileShape = ListTileTheme.of(tester.element(find.text('First'))).shape! as RoundedRectangleBorder;
    expect(tileShape.borderRadius, const BorderRadius.vertical(top: outer, bottom: inner));
  });
}
