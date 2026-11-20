import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

import 'design_test_app.dart';

void main() {
  Widget menu(List<String> log) => designTestApp(
    const Text('Content'),
    floatingActionButton: FabMenu(
      tooltip: 'Quick actions',
      items: [
        FabMenuItem(icon: Icons.edit_note, label: 'Write sample data', onPressed: () => log.add('write')),
        FabMenuItem(icon: Icons.monitor_heart, label: 'Read last 24 h', onPressed: () => log.add('read')),
      ],
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Quick actions'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens into its items and runs the chosen one', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(menu(log));
    expect(find.text('Write sample data'), findsNothing);

    await open(tester);
    expect(find.text('Write sample data'), findsOneWidget);
    expect(find.text('Read last 24 h'), findsOneWidget);
    expect(find.byTooltip('Close menu'), findsOneWidget);

    await tester.tap(find.text('Read last 24 h'));
    await tester.pumpAndSettle();
    expect(log, ['read']);
    expect(find.text('Read last 24 h'), findsNothing, reason: 'choosing an item closes the menu');
  });

  testWidgets('closes with its close button without running anything', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(menu(log));
    await open(tester);

    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();

    expect(find.text('Write sample data'), findsNothing);
    expect(log, isEmpty);
  });

  testWidgets('closes on a tap outside and on back', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(menu(log));

    await open(tester);
    await tester.tap(find.text('Content'));
    await tester.pumpAndSettle();
    expect(find.text('Write sample data'), findsNothing);

    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Write sample data'), findsNothing);
    expect(find.text('Content'), findsOneWidget, reason: 'back closes the menu, not the page');
    expect(log, isEmpty);
  });
}
