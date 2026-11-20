import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/shared/data_point/data_point_details.dart';
import 'package:health_example/shared/data_point/sheet/data_point_fields.dart';
import 'package:health_example/shared/data_point/sheet/data_point_header.dart';
import 'package:health_example/shared/data_point/value_views/raw_json_view.dart';
import 'package:health_example/shared/data_point/value_views/workout/workout_value_view.dart';

import '../support/sample_points.dart';
import '../support/shared_test_app.dart';

void main() {
  /// The top of the widget [finder] finds.
  double top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

  testWidgets('shows a point inline, header first, without the app services', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(sharedTestApp(DataPointDetails(point: poolSwimPoint()), scrollable: true));

    expect(find.text('Swimming pool'), findsOneWidget, reason: 'the headline');
    final order = [DataPointHeader, WorkoutValueView, DataPointFields, RawJsonView].map((type) => find.byType(type));
    final tops = [for (final finder in order) top(tester, finder)];
    expect(tops, orderedEquals([...tops]..sort()), reason: 'header, value, fields and JSON, top to bottom');
    expect(find.text('Written by this app'), findsNothing, reason: 'no recent writes without the services');
  });

  testWidgets('puts the actions between the header and the value', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      sharedTestApp(DataPointDetails(point: heartRatePoint(), actions: const Text('Actions')), scrollable: true),
    );

    final actions = top(tester, find.text('Actions'));
    expect(actions, greaterThan(top(tester, find.byType(DataPointHeader))));
    expect(actions, lessThan(top(tester, find.text('Measurement'))));
  });
}
