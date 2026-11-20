import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/shared/widgets/recording_method_filter.dart';

import '../support/shared_test_app.dart';

void main() {
  Set<RecordingMethod>? reported;

  Future<void> pumpFilter(WidgetTester tester, Set<RecordingMethod> filtered, HealthPlatformType platform) async {
    reported = null;
    await tester.pumpWidget(
      sharedTestApp(
        RecordingMethodFilter(filtered: filtered, onChanged: (methods) => reported = methods, platform: platform),
        scrollable: true,
      ),
    );
  }

  FilterChip chip(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

  group('Health Connect', () {
    const android = HealthPlatformType.googleHealthConnect;

    testWidgets('offers all four methods, selected when included', (tester) async {
      await pumpFilter(tester, {RecordingMethod.manual}, android);

      expect(find.byType(FilterChip), findsNWidgets(4));
      expect(chip(tester, 'Manual').selected, isFalse);
      expect(chip(tester, 'Automatic').selected, isTrue);
    });

    testWidgets('leaves out a method, and includes it again', (tester) async {
      await pumpFilter(tester, const {}, android);
      await tester.tap(find.text('Unknown'));
      expect(reported, {RecordingMethod.unknown});

      await pumpFilter(tester, {RecordingMethod.unknown, RecordingMethod.manual}, android);
      await tester.tap(find.text('Manual'));
      expect(reported, {RecordingMethod.unknown});
    });

    testWidgets('warns when every method is left out', (tester) async {
      await pumpFilter(tester, RecordingMethod.values.toSet(), android);

      expect(find.text('All excluded — no data will match'), findsOneWidget);
    });
  });

  group('HealthKit', () {
    const ios = HealthPlatformType.appleHealth;

    testWidgets('can leave out manual entries only', (tester) async {
      await pumpFilter(tester, const {}, ios);

      expect(find.byType(FilterChip), findsNWidgets(2));
      expect(chip(tester, 'Automatic').onSelected, isNull, reason: 'HealthKit reads every other sample as automatic');
      expect(chip(tester, 'Automatic').selected, isTrue);

      await tester.tap(find.text('Manual'));
      expect(reported, {RecordingMethod.manual});
    });

    testWidgets('shows automatic samples as included whatever the filter says', (tester) async {
      await pumpFilter(tester, {RecordingMethod.automatic, RecordingMethod.manual}, ios);

      expect(chip(tester, 'Automatic').selected, isTrue);
      expect(chip(tester, 'Manual').selected, isFalse);
      expect(find.text('All excluded — no data will match'), findsNothing);
    });
  });
}
