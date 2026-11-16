import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/type_picker/type_picker_model.dart';
import 'package:health_example/shared/widgets/type_picker_sheet.dart';

import '../support/shared_test_app.dart';

const _offered = [
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.HEART_RATE,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.BLOOD_OXYGEN,
  HealthDataType.WEIGHT,
];

void main() {
  group('TypePickerModel', () {
    test('matches names and code names, every word of the query', () {
      expect(TypePickerModel.matches(HealthDataType.RESTING_HEART_RATE, 'heart'), isTrue);
      expect(TypePickerModel.matches(HealthDataType.RESTING_HEART_RATE, 'RESTING_HEART'), isTrue);
      expect(TypePickerModel.matches(HealthDataType.RESTING_HEART_RATE, 'rate rest'), isTrue);
      expect(TypePickerModel.matches(HealthDataType.BLOOD_OXYGEN, 'heart'), isFalse, reason: 'not its category');
      expect(TypePickerModel.matches(HealthDataType.STEPS, 'heart'), isFalse);
      expect(TypePickerModel.matches(HealthDataType.STEPS, '  '), isTrue, reason: 'an empty query matches all');
    });

    test('groups the matches by category in category order, sorted by name', () {
      final model = TypePickerModel(available: _offered);
      expect(model.groups.keys, [TypeCategory.activity, TypeCategory.body, TypeCategory.vitals]);
      expect(model.groups[TypeCategory.activity], [HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.STEPS]);

      model.query = 'heart';
      expect(model.groups.keys, [TypeCategory.vitals]);
      expect(model.groups[TypeCategory.vitals], [HealthDataType.HEART_RATE, HealthDataType.RESTING_HEART_RATE]);
    });

    test('selects all or none of the shown types of a category', () {
      final model = TypePickerModel(available: _offered, initial: {HealthDataType.HEART_RATE});
      expect(model.categoryState(TypeCategory.vitals), isNull, reason: 'one of three');

      model.toggleCategory(TypeCategory.vitals);
      expect(model.categoryState(TypeCategory.vitals), isTrue);
      model.toggleCategory(TypeCategory.vitals);
      expect(model.categoryState(TypeCategory.vitals), isFalse);

      model
        ..query = 'heart'
        ..toggleCategory(TypeCategory.vitals);
      expect(model.selected, {HealthDataType.HEART_RATE, HealthDataType.RESTING_HEART_RATE}, reason: 'only matches');
    });

    test('keeps only available initial types, and one type without multiple', () {
      final model = TypePickerModel(
        available: _offered,
        initial: {HealthDataType.STEPS, HealthDataType.AUDIOGRAM},
        multiple: false,
      );
      expect(model.selected, {HealthDataType.STEPS});

      model.toggle(HealthDataType.WEIGHT);
      expect(model.selected, {HealthDataType.WEIGHT}, reason: 'a single choice replaces the selection');
    });
  });

  group('showTypePicker', () {
    Set<HealthDataType>? result;
    var closed = false;

    /// Scrolls the picker's list until [text] shows.
    Future<void> scrollTo(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        150,
        scrollable: find.descendant(of: find.byType(TypePickerSheet), matching: find.byType(Scrollable)).first,
      );
      // scrollUntilVisible ends with a jump that the next frame lays out.
      await tester.pumpAndSettle();
    }

    Future<void> open(WidgetTester tester, {bool multiple = true, Set<HealthDataType> initial = const {}}) async {
      result = null;
      closed = false;
      usePhoneSize(tester);
      await tester.pumpWidget(
        sharedTestApp(
          launcher('Pick', (context) async {
            result = await showTypePicker(context, available: _offered, initial: initial, multiple: multiple);
            closed = true;
          }),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
    }

    testWidgets('groups the types by category and returns the checked ones', (tester) async {
      await open(tester, initial: {HealthDataType.STEPS});
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('1 of 2 selected'), findsOneWidget);

      await tester.tap(find.text('Weight'));
      await tester.pump();
      await scrollTo(tester, 'Heart & vitals');
      expect(find.text('0 of 3 selected'), findsOneWidget);
      await tester.tap(find.text('Done · 2 types'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, {HealthDataType.STEPS, HealthDataType.WEIGHT});
    });

    testWidgets('searches, and selects a whole category of matches', (tester) async {
      await open(tester);

      await tester.enterText(find.byType(SearchBar), 'heart');
      await tester.pumpAndSettle();
      expect(find.text('Activity'), findsNothing);
      expect(find.text('Blood oxygen'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Select all Heart & vitals'));
      await tester.pump();
      await tester.tap(find.text('Done · 2 types'));
      await tester.pumpAndSettle();

      expect(result, {HealthDataType.HEART_RATE, HealthDataType.RESTING_HEART_RATE});
    });

    testWidgets('explains a search without matches', (tester) async {
      await open(tester);

      await tester.enterText(find.byType(SearchBar), 'xyz');
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No data type matches "xyz"'), findsOneWidget);
    });

    testWidgets('returns null when cancelled', (tester) async {
      await open(tester, initial: {HealthDataType.STEPS});

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
    });

    testWidgets('with a single choice, the list keeps clear of the home indicator', (tester) async {
      // 34 dp at the bottom, as on an iPhone without a home button; open() sizes the window.
      tester.view.padding = const FakeViewPadding(bottom: 102);
      await open(tester, multiple: false);

      final list = tester.widget<SliverPadding>(
        find.descendant(of: find.byType(TypePickerSheet), matching: find.byType(SliverPadding)),
      );
      expect(list.padding, const EdgeInsets.fromLTRB(16, 0, 16, 24 + 34));
    });

    testWidgets('with a single choice, picking a type closes the sheet', (tester) async {
      await open(tester, multiple: false);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);

      await scrollTo(tester, 'Blood oxygen');
      await tester.tap(find.text('Blood oxygen'));
      await tester.pumpAndSettle();

      expect(result, {HealthDataType.BLOOD_OXYGEN});
    });
  });
}
