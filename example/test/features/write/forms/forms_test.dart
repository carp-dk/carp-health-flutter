import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/features/write/forms/activity_intensity_form.dart';
import 'package:health_example/features/write/forms/audiogram_form.dart';
import 'package:health_example/features/write/forms/blood_oxygen_form.dart';
import 'package:health_example/features/write/forms/blood_pressure_form.dart';
import 'package:health_example/features/write/forms/insulin_delivery_form.dart';
import 'package:health_example/features/write/forms/meal_form.dart';
import 'package:health_example/features/write/forms/measurement_form.dart';
import 'package:health_example/features/write/forms/menstruation_flow_form.dart';
import 'package:health_example/features/write/forms/mindfulness_form.dart';
import 'package:health_example/features/write/forms/sexual_activity_form.dart';
import 'package:health_example/features/write/forms/sleep_session_form.dart';
import 'package:health_example/features/write/forms/workout_form.dart';
import 'package:health_example/features/write/forms/workout_route_form.dart';

import '../../../core/support/fake_health.dart';
import '../../../shared/support/shared_test_app.dart';

/// A [FakeHealth] whose workout reads finish synchronously in tests without hitting a platform channel.
class _FormHealth extends FakeHealth {
  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? limit,
  }) async => const [];
}

/// A [_FormHealth] whose blood oxygen write saves nothing, as without write access.
class _RefusingHealth extends _FormHealth {
  @override
  Future<bool> writeBloodOxygen({
    required double saturation,
    required DateTime startTime,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async => false;
}

void main() {
  /// Every form, by name.
  final forms = <String, Widget Function()>{
    'measurement': MeasurementForm.new,
    'blood pressure': BloodPressureForm.new,
    'blood oxygen': BloodOxygenForm.new,
    'meal': MealForm.new,
    'workout': WorkoutForm.new,
    'workout route': WorkoutRouteForm.new,
    'sleep session': SleepSessionForm.new,
    'mindfulness': MindfulnessForm.new,
    'menstruation flow': MenstruationFlowForm.new,
    'sexual activity': SexualActivityForm.new,
    'insulin delivery': InsulinDeliveryForm.new,
    'audiogram': AudiogramForm.new,
    'activity intensity': ActivityIntensityForm.new,
  };

  late AppServices services;
  tearDown(() => services.dispose());

  Future<void> pumpForm(
    WidgetTester tester,
    Widget form,
    HealthPlatformType platform, {
    FakeHealth? health,
    Size size = const Size(360, 800),
  }) async {
    usePhoneSize(tester, size: size);
    services = testServices(health ?? _FormHealth(), platform: platform);
    await tester.pumpWidget(sharedTestApp(form, services: services, scrollable: true));
    await tester.pumpAndSettle();
  }

  for (final platform in HealthPlatformType.values) {
    for (final MapEntry(key: name, value: form) in forms.entries) {
      testWidgets('the $name form builds on ${platform.name}', (tester) async {
        // The test font draws every glyph 1 em wide: the widest menus need more than a phone's width.
        await pumpForm(tester, form(), platform, size: const Size(480, 900));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a section of the other platform is one line with a platform badge', (tester) async {
    await pumpForm(tester, const MenstruationFlowForm(), HealthPlatformType.googleHealthConnect);
    expect(find.text('Start of cycle'), findsOneWidget);
    expect(find.text('iOS'), findsOneWidget);
    expect(find.text('Ignored on Android'), findsOneWidget);
    expect(find.text('Starts a cycle'), findsNothing);
  });

  testWidgets('a write this platform lacks says why in place of the write button', (tester) async {
    await pumpForm(tester, const InsulinDeliveryForm(), HealthPlatformType.googleHealthConnect);
    expect(find.text('Not available here'), findsOneWidget);
    expect(find.text('iOS only: Health Connect has no insulin type.'), findsOneWidget);
    expect(find.text('Write insulin delivery'), findsNothing);
  });

  testWidgets('a write that saved nothing shows a compact result with what the method returned', (tester) async {
    await pumpForm(tester, const BloodOxygenForm(), HealthPlatformType.googleHealthConnect, health: _RefusingHealth());
    await tester.ensureVisible(find.text('Write blood oxygen'));
    await tester.tap(find.text('Write blood oxygen'));
    await tester.pumpAndSettle();

    expect(find.text('Not saved'), findsOneWidget);
    expect(find.text('Request access'), findsOneWidget);
    await tester.tap(find.byTooltip('About the result'));
    await tester.pumpAndSettle();
    expect(find.text('writeBloodOxygen returned false'), findsOneWidget);
  });
}
