import 'package:carp_serializable/carp_serializable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_tile.dart';
import 'package:health_example/shared/data_point/value_views/raw_json_view.dart';

import '../support/sample_points.dart';
import '../support/shared_test_app.dart';

void main() {
  group('DataPointTile', () {
    testWidgets('shows the value, the type, the time and the source', (tester) async {
      final point = heartRatePoint();
      await tester.pumpWidget(sharedTestApp(SegmentedList(children: [DataPointTile(point: point)])));

      expect(find.text('72 bpm'), findsOneWidget);
      final subtitle = 'Heart rate · ${formatTimeRange(point.dateFrom, point.dateTo)}\ncom.example.watch';
      expect(find.text(subtitle), findsOneWidget);
    });

    testWidgets('summarizes typed values and leaves out the type under a type header', (tester) async {
      await tester.pumpWidget(sharedTestApp(DataPointTile(point: poolSwimPoint(), showType: false)));

      expect(find.text('Swimming pool · 30 min · 1 km · 300 kcal · 3 laps'), findsOneWidget);
      expect(find.textContaining('Workout ·'), findsNothing);
    });

    testWidgets('names the recording method for screen readers and runs onTap', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(sharedTestApp(DataPointTile(point: bananaPoint(), onTap: () => taps++)));

      expect(find.bySemanticsLabel(RegExp('Manual recording')), findsOneWidget);
      await tester.tap(find.byType(DataPointTile));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('an interval of several apps names them all', (tester) async {
      await tester.pumpWidget(sharedTestApp(DataPointTile(point: stepsIntervalPoint())));

      expect(find.text('1,234'), findsOneWidget);
      expect(find.textContaining('com.google.android.apps.fitness, com.example.watch'), findsOneWidget);
    });
  });

  group('RawJsonView', () {
    testWidgets('shows the point as toJsonString prints it, once opened', (tester) async {
      final point = heartRatePoint();
      await tester.pumpWidget(sharedTestApp(RawJsonView(point: point), scrollable: true));

      expect(find.byType(SelectableText), findsNothing, reason: 'the JSON is built only when opened');
      await tester.tap(find.text('Show JSON'));
      await tester.pumpAndSettle();

      final shown = tester.widget<SelectableText>(find.byType(SelectableText)).data!;
      expect(shown, toJsonString(point));
      expect(shown, contains('"type": "HEART_RATE"'));
      expect(shown, contains('"numericValue": 72'));
    });

    test('encodes every kind of value', () {
      for (final MapEntry(key: name, value: point) in everyKindOfPoint().entries) {
        final json = RawJsonView.encode(point);
        expect(json, contains('"type": "${point.type.name}"'), reason: name);
        expect(json, contains('"__type": "${point.value.runtimeType}"'), reason: '$name names its kind of value');
      }
    });

    test('says so when metadata cannot be encoded instead of throwing', () {
      final point = samplePoint(
        HealthDataType.STEPS,
        NumericHealthValue(numericValue: 10),
        metadata: {'not json': Object()},
      );

      expect(RawJsonView.encode(point), startsWith('// Not encodable as JSON'));
    });
  });
}
