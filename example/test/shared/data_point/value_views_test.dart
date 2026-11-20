import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/shared/data_point/value_views/numeric_value_view.dart';
import 'package:health_example/shared/data_point/value_views/typed_value_view.dart';

import '../support/sample_points.dart';
import '../support/shared_test_app.dart';

/// Shows [point]'s value with [TypedValueView] on a phone-sized page.
Future<void> _pumpValue(WidgetTester tester, HealthDataPoint point) async {
  usePhoneSize(tester);
  await tester.pumpWidget(sharedTestApp(TypedValueView(point: point), scrollable: true));
  await tester.pumpAndSettle();
}

/// Expects a field labelled [label] showing [value].
void _expectField(String label, String value) {
  expect(find.text(label), findsWidgets, reason: 'the field "$label"');
  expect(find.text(value), findsWidgets, reason: 'the value of "$label"');
}

void main() {
  group('numeric values', () {
    testWidgets('show the number and unit the plugin returned', (tester) async {
      await _pumpValue(tester, heartRatePoint());

      expect(find.byType(NumericValueView), findsOneWidget);
      _expectField('Value', '72');
      _expectField('Unit', 'bpm (BEATS_PER_MINUTE)');
    });

    testWidgets('show sleep stages, which the plugin reports in minutes, as a duration', (tester) async {
      await _pumpValue(tester, deepSleepPoint());

      _expectField('Duration', '1 h 35 min');
    });

    testWidgets('show HealthKit fractions as percentages', (tester) async {
      await _pumpValue(tester, iosBloodOxygenPoint());

      _expectField('Percentage', '97%');
    });

    testWidgets('give the meaning of coded values', (tester) async {
      await _pumpValue(tester, bloodTypePoint());

      _expectField('Meaning', 'A+');
    });
  });

  group('small typed values', () {
    testWidgets('menstruation: flow, cycle start and whether the user entered it', (tester) async {
      await _pumpValue(tester, menstruationPoint());

      expect(find.text('Menstrual flow'), findsOneWidget);
      _expectField('Flow', 'Light');
      _expectField('Start of cycle', 'Yes');
      _expectField('Entered by the user', 'Yes');
    });

    testWidgets('menstruation from Health Connect, which records neither flag', (tester) async {
      final point = samplePoint(
        HealthDataType.MENSTRUATION_FLOW,
        MenstruationFlowHealthValue(flow: MenstrualFlow.heavy, dateTime: sampleStart),
      );
      await _pumpValue(tester, point);

      _expectField('Flow', 'Heavy');
      expect(find.text('Not recorded'), findsNWidgets(2));
    });

    testWidgets('sexual activity: protection status', (tester) async {
      await _pumpValue(tester, sexualActivityPoint());

      expect(find.text('Sexual activity'), findsOneWidget);
      _expectField('Protection', 'Protected');

      await _pumpValue(tester, sexualActivityPoint(protectionUsed: SexualActivityProtection.unknown));
      _expectField('Protection', 'Unspecified');
    });

    testWidgets('insulin: units and reason', (tester) async {
      await _pumpValue(tester, insulinPoint());

      _expectField('Amount', '4.5 IU');
      _expectField('Reason', 'Bolus');
    });

    testWidgets('skin temperature: change, baseline, temperature and location', (tester) async {
      await _pumpValue(tester, skinTemperaturePoint());

      _expectField('Change from baseline', '+0.4 °C');
      _expectField('Baseline', '33.1 °C');
      _expectField('Temperature', '33.5 °C');
      _expectField('Measured at', 'Wrist');
    });

    testWidgets('skin temperature without a baseline has no temperature', (tester) async {
      final point = samplePoint(HealthDataType.SKIN_TEMPERATURE, SkinTemperatureHealthValue(temperatureDelta: -0.2));
      await _pumpValue(tester, point);

      _expectField('Change from baseline', '-0.2 °C');
      _expectField('Baseline', 'Not recorded');
      expect(find.text('Temperature'), findsNothing);
    });

    testWidgets('activity intensity: level and duration', (tester) async {
      await _pumpValue(tester, activityIntensityPoint());

      _expectField('Intensity', 'Vigorous');
      _expectField('Duration', '25 min');
    });
  });
}
