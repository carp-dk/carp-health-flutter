import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/shared/widgets/type_chips.dart';

import '../support/shared_test_app.dart';

void main() {
  testWidgets('shows the types sorted by category, then name, and removes one', (tester) async {
    HealthDataType? removed;
    await tester.pumpWidget(
      sharedTestApp(
        TypeChips(
          types: const {HealthDataType.HEART_RATE, HealthDataType.WEIGHT, HealthDataType.STEPS},
          onRemove: (type) => removed = type,
        ),
      ),
    );

    final labels = tester.widgetList<InputChip>(find.byType(InputChip)).map((chip) => (chip.label as Text).data);
    expect(labels, ['Steps', 'Weight', 'Heart rate'], reason: 'activity, body, then vitals');

    await tester.tap(find.byTooltip('Remove Weight'));
    expect(removed, HealthDataType.WEIGHT);
  });

  testWidgets('collapses a long selection into a count that edits it', (tester) async {
    var edits = 0;
    await tester.pumpWidget(
      sharedTestApp(TypeChips(types: dataTypeKeysAndroid.take(20).toSet(), maxVisible: 5, onEdit: () => edits++)),
    );

    expect(find.byType(InputChip), findsNWidgets(5));
    await tester.tap(find.text('+15 more'));
    await tester.tap(find.text('Edit'));
    expect(edits, 2);
  });

  testWidgets('without types offers to choose some', (tester) async {
    var edits = 0;
    await tester.pumpWidget(sharedTestApp(TypeChips(types: const {}, onEdit: () => edits++)));

    await tester.tap(find.text('Choose data types'));
    expect(edits, 1);
  });

  testWidgets('without types and without editing says there are none', (tester) async {
    await tester.pumpWidget(sharedTestApp(const TypeChips(types: {})));

    expect(find.text('No data types'), findsOneWidget);
  });
}
