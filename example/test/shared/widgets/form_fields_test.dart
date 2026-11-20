import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import '../support/shared_test_app.dart';

void main() {
  group('NumberField', () {
    test('parses numbers with a decimal point or comma', () {
      expect(NumberField.parse('72'), 72);
      expect(NumberField.parse(' 3,5 '), 3.5);
      expect(NumberField.parse('-0.4'), -0.4);
      for (final text in ['', '-', '.', 'abc']) {
        expect(NumberField.parse(text), isNull, reason: '"$text"');
      }
    });

    testWidgets('takes only what keeps a number, and shows its unit', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(sharedTestApp(NumberField(label: 'Heart rate', controller: controller, unit: 'bpm')));

      await tester.enterText(find.byType(TextField), '7a2');
      expect(controller.text, isEmpty, reason: 'letters are refused');
      await tester.enterText(find.byType(TextField), '72,5');
      expect(controller.text, '72,5');
      expect(find.text('bpm'), findsOneWidget);
    });

    testWidgets('refuses decimals for whole numbers and asks for a required value', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        sharedTestApp(
          Form(
            key: form,
            child: NumberField(label: 'Steps', controller: controller, decimal: false),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '7.5');
      expect(controller.text, isEmpty);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a value'), findsOneWidget);
    });
  });

  testWidgets('EnumDropdownField shows the value and reports the one picked', (tester) async {
    String? picked;
    await tester.pumpWidget(
      sharedTestApp(
        EnumDropdownField<String>(
          label: 'Meal',
          value: 'breakfast',
          values: const ['breakfast', 'lunch', 'dinner'],
          labelOf: humanize,
          onChanged: (value) => picked = value,
        ),
        scrollable: true,
      ),
    );
    expect(find.text('Breakfast'), findsOneWidget);

    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dinner').last);
    await tester.pumpAndSettle();

    expect(picked, 'dinner');
  });

  testWidgets('DateTimeField asks for a date, then a time', (tester) async {
    final value = DateTime(2026, 3, 14, 7, 30);
    DateTime? picked;
    usePhoneSize(tester);
    await tester.pumpWidget(
      sharedTestApp(DateTimeField(label: 'Start', value: value, onChanged: (time) => picked = time), scrollable: true),
    );
    expect(find.text(formatDateTime(value)), findsOneWidget);

    await tester.tap(find.byType(DateTimeField));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(picked, value);
  });

  group('WriteButton', () {
    testWidgets('shows progress and refuses a second tap while the write runs', (tester) async {
      final write = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        sharedTestApp(
          WriteButton(
            label: 'Write heart rate',
            onPressed: () {
              calls++;
              return write.future;
            },
          ),
        ),
      );

      await tester.tap(find.text('Write heart rate'));
      await tester.pump();
      expect(find.text('Writing…'), findsOneWidget);
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      await tester.tap(find.text('Writing…'));
      expect(calls, 1);

      write.complete();
      await tester.pumpAndSettle();
      expect(find.text('Write heart rate'), findsOneWidget);
    });

    testWidgets('shows a write that throws in a snack bar instead of crashing', (tester) async {
      await tester.pumpWidget(
        sharedTestApp(
          WriteButton(label: 'Write', onPressed: () async => throw ArgumentError('Value must be positive')),
        ),
      );

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();

      expect(find.text('Write failed: Invalid argument'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget, reason: 'ready again');
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Value must be positive'), findsOneWidget);
    });
  });
}
