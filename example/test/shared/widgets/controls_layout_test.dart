import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/time/time_range.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/shared.dart';

import '../support/sample_points.dart';
import '../support/shared_test_app.dart';

/// The shared controls lay out without overflowing, which flutter_test reports as an error, on a small
/// phone (320 dp wide) with twice the text size, in the dark theme.
void main() {
  late LookupHealth health;
  late AppServices services;

  setUp(() {
    health = LookupHealth();
    services = testServices(health);
  });
  tearDown(() => services.dispose());

  void useSmallPhoneWithLargeText(WidgetTester tester) {
    usePhoneSize(tester, size: const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('the read and write controls, an error and a list of every kind of data point', (tester) async {
    useSmallPhoneWithLargeText(tester);
    final number = TextEditingController(text: '72');
    addTearDown(number.dispose);
    final rateLimited = HealthPlatformException(
      HealthDataType.STEPS,
      PlatformException(code: 'RATE_LIMIT_EXCEEDED', message: 'Quota used up'),
    );
    await tester.pumpWidget(
      sharedTestApp(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            TypeChips(
              types: const {HealthDataType.STEPS, HealthDataType.HEART_RATE, HealthDataType.BLOOD_OXYGEN},
              onEdit: () {},
              onRemove: (_) {},
            ),
            TimeRangeSelector(value: TimeRange.preset(TimeRangePreset.last7Days), onChanged: (_) {}),
            for (final platform in HealthPlatformType.values)
              RecordingMethodFilter(filtered: const {RecordingMethod.manual}, onChanged: (_) {}, platform: platform),
            DateTimeField(label: 'Start', value: DateTime(2026, 3, 14, 7), onChanged: (_) {}),
            NumberField(label: 'Heart rate', controller: number, unit: 'bpm'),
            EnumDropdownField<RecordingMethod>(
              label: 'Recording method',
              value: RecordingMethod.manual,
              values: RecordingMethod.values,
              labelOf: (method) => method.label,
              onChanged: (_) {},
            ),
            WriteButton(label: 'Write heart rate', onPressed: () async {}),
            ErrorCard(error: rateLimited, onRetry: () {}),
            AsyncValueView<int>(value: const AsyncData(1234), data: (context, steps) => Text('$steps steps')),
            SegmentedList(
              children: [for (final point in everyKindOfPoint().values) DataPointTile(point: point, onTap: () {})],
            ),
          ],
        ),
        services: services,
        scrollable: true,
        theme: ExpressiveTheme.dark(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DataPointTile), findsNWidgets(everyKindOfPoint().length));
  });

  for (final multiple in [true, false]) {
    testWidgets('the type picker with ${multiple ? 'several types' : 'one type'} to pick', (tester) async {
      useSmallPhoneWithLargeText(tester);
      await tester.pumpWidget(
        sharedTestApp(
          launcher(
            'Pick',
            (context) => showTypePicker(
              context,
              available: dataTypeKeysAndroid,
              initial: {HealthDataType.STEPS},
              multiple: multiple,
            ),
          ),
          theme: ExpressiveTheme.dark(),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.byType(TypePickerSheet), findsOneWidget);
    });
  }

  testWidgets('the progress dialog of a lookup by UUID', (tester) async {
    useSmallPhoneWithLargeText(tester);
    health.hold = Completer<void>();
    await tester.pumpWidget(
      sharedTestApp(
        launcher('View', (context) => openDataPointByUuid(context, uuid: 'uuid-1', type: HealthDataType.HEART_RATE)),
        services: services,
        theme: ExpressiveTheme.dark(),
      ),
    );
    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reading Heart rate'), findsOneWidget);

    health.hold!.complete();
    await tester.pumpAndSettle();
  });
}
