import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/shared/data_point/value_views/ecg/ecg_trace.dart';
import 'package:health_example/shared/data_point/value_views/route/route_preview.dart';
import 'package:health_example/shared/data_point/value_views/typed_value_view.dart';
import 'package:health_example/shared/data_point/value_views/workout/swimming_view.dart';
import 'package:health_example/shared/data_point/value_views/workout/workout_events_view.dart';

import '../support/sample_points.dart';
import '../support/shared_test_app.dart';

/// Shows [point]'s value with [TypedValueView] on a phone-sized page.
Future<void> _pumpValue(WidgetTester tester, HealthDataPoint point) async {
  usePhoneSize(tester);
  await tester.pumpWidget(sharedTestApp(TypedValueView(point: point), scrollable: true));
  await tester.pumpAndSettle();
}

/// Finds a metric tile's big value (its number and unit are one rich text).
Finder _figure(String text) => find.text(text, findRichText: true);

void main() {
  group('workout', () {
    testWidgets('shows the totals as figures and HealthKit\'s extra fields', (tester) async {
      await _pumpValue(tester, poolSwimPoint());

      expect(_figure('30 min'), findsOneWidget, reason: 'the duration from start to end');
      expect(_figure('28 min'), findsOneWidget, reason: 'the active time HealthKit records, without pauses');
      expect(_figure('1 km'), findsOneWidget);
      expect(_figure('300 kcal'), findsOneWidget);
      expect(_figure('420'), findsOneWidget, reason: 'the swimming strokes');
      expect(find.text('Swimming pool (SWIMMING_POOL)'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget, reason: 'indoors');
      expect(find.text('8.5 METs (kcal/kg/h)'), findsOneWidget);
    });

    testWidgets('lists the swimming laps with their strokes and the pool length', (tester) async {
      await _pumpValue(tester, poolSwimPoint());

      expect(find.byType(SwimmingView), findsOneWidget);
      expect(find.text('25 m'), findsOneWidget);
      expect(find.text('3 (75 m)'), findsOneWidget, reason: 'three laps of 25 m');
      for (final stroke in ['Freestyle', 'Backstroke', 'Butterfly']) {
        expect(find.text(stroke), findsOneWidget);
      }
    });

    testWidgets('lists the workout events in order', (tester) async {
      await _pumpValue(tester, poolSwimPoint());

      expect(find.byType(WorkoutEventsView), findsOneWidget);
      final events = ['Pause', 'Resume', 'Segment'].map((name) => tester.getTopLeft(find.text(name)).dy).toList();
      expect(events, orderedEquals([...events]..sort()), reason: 'pause, resume and segment top to bottom');
      expect(find.textContaining('· 8 min'), findsOneWidget, reason: 'the segment lasts eight minutes');
    });

    testWidgets('an Android workout without totals shows only its duration', (tester) async {
      final point = samplePoint(
        HealthDataType.WORKOUT,
        WorkoutHealthValue(workoutActivityType: HealthWorkoutActivityType.YOGA),
        duration: const Duration(minutes: 45),
      );
      await _pumpValue(tester, point);

      expect(_figure('45 min'), findsOneWidget);
      expect(find.byType(SwimmingView), findsNothing);
      expect(find.byType(WorkoutEventsView), findsNothing);
    });
  });

  testWidgets('nutrition: energy and macros as figures, micronutrients by group', (tester) async {
    await _pumpValue(tester, bananaPoint());

    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);
    expect(_figure('105 kcal'), findsOneWidget);
    expect(_figure('1.3 g'), findsOneWidget);
    expect(_figure('27 g'), findsOneWidget);
    expect(find.text('Vitamins'), findsOneWidget);
    expect(find.text('10.3 mg'), findsOneWidget, reason: 'vitamin C, given in grams, reads in milligrams');
    expect(find.text('Minerals'), findsOneWidget);
    expect(find.text('422 mg'), findsOneWidget);
    expect(find.text('Other'), findsNothing, reason: 'groups without a nutrient are left out');
  });

  testWidgets('audiogram: a table of both ears per frequency', (tester) async {
    await _pumpValue(tester, audiogramPoint());

    expect(find.byType(Table), findsOneWidget);
    for (final frequency in ['500 Hz', '1,000 Hz', '2,000 Hz', '4,000 Hz']) {
      expect(find.text(frequency), findsOneWidget);
    }
    expect(find.text('30 dB'), findsOneWidget, reason: 'the right ear at 4 kHz');
    expect(find.text('–'), findsOneWidget, reason: 'the left ear was not tested at 4 kHz');
  });

  testWidgets('ECG: classification, heart rate, samples and a trace', (tester) async {
    await _pumpValue(tester, ecgPoint());

    expect(find.text('Sinus rhythm'), findsOneWidget);
    expect(_figure('64 bpm'), findsOneWidget);
    expect(_figure('20 Hz'), findsOneWidget);
    expect(_figure('600'), findsOneWidget, reason: 'the number of voltage samples');
    expect(find.byType(EcgTrace), findsOneWidget);
  });

  group('workout route', () {
    testWidgets('draws the route and gives its figures, ends and workout', (tester) async {
      await _pumpValue(tester, routePoint());

      expect(find.byType(RoutePreview), findsOneWidget);
      expect(_figure('5'), findsOneWidget, reason: 'five locations');
      expect(_figure('4 min'), findsOneWidget);
      expect(_figure('20–24 m'), findsOneWidget, reason: 'the altitudes');
      expect(find.textContaining('55.78560, 12.52180'), findsOneWidget, reason: 'the start');
      expect(find.textContaining('55.78960, 12.52780'), findsOneWidget, reason: 'the end');
      expect(find.text('uuid-run'), findsOneWidget);
    });

    testWidgets('explains a route Health Connect returned without its locations', (tester) async {
      await _pumpValue(tester, routeNeedingConsentPoint());

      expect(find.textContaining('without its locations'), findsOneWidget);
      expect(find.byType(RoutePreview), findsNothing);
    });

    test('measures its length along the locations', () {
      final locations = (routePoint().value as WorkoutRouteHealthValue).locations;
      // Each step goes 111 m north and about 94 m east at this latitude.
      expect(routeDistance(locations), closeTo(4 * 145.6, 2));
    });
  });
}
