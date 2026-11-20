import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/time/time_range.dart';
import 'package:health_example/shared/widgets/time_range_selector.dart';

import '../support/shared_test_app.dart';

void main() {
  TimeRange? reported;

  Future<void> pumpSelector(WidgetTester tester, TimeRange value, {List<TimeRangePreset>? presets}) async {
    reported = null;
    usePhoneSize(tester);
    await tester.pumpWidget(
      sharedTestApp(
        TimeRangeSelector(
          value: value,
          onChanged: (range) => reported = range,
          presets: presets ?? TimeRangeSelector.defaultPresets,
        ),
        scrollable: true,
      ),
    );
  }

  testWidgets('offers the presets, marks the selected one and shows its exact range', (tester) async {
    final range = TimeRange.preset(TimeRangePreset.last24Hours);
    await pumpSelector(tester, range);

    for (final preset in TimeRangePreset.values) {
      expect(find.widgetWithText(ChoiceChip, preset.label), findsOneWidget);
    }
    final selected = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).where((chip) => chip.selected);
    expect((selected.single.label as Text).data, 'Last 24 hours');
    expect(find.text('${formatTimeRange(range.start, range.end)} · 1 d'), findsOneWidget);
  });

  testWidgets('reports the preset tapped, ending now', (tester) async {
    await pumpSelector(tester, TimeRange.preset(TimeRangePreset.today));

    await tester.tap(find.text('Last 7 days'));

    expect(reported?.preset, TimeRangePreset.last7Days);
    expect(DateTime.now().difference(reported!.end).inSeconds, lessThan(5));
  });

  testWidgets('offers only the presets asked for', (tester) async {
    await pumpSelector(tester, TimeRange.preset(TimeRangePreset.today), presets: const [TimeRangePreset.today]);

    expect(find.byType(ChoiceChip), findsOneWidget);
  });

  testWidgets('Custom opens the date range picker and reports whole days', (tester) async {
    await pumpSelector(tester, TimeRange.preset(TimeRangePreset.today));

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    expect(reported?.preset, TimeRangePreset.custom);
    expect(reported?.start, DateTime(today.year, today.month, today.day));
    expect(reported?.end, DateTime(today.year, today.month, today.day, 23, 59, 59, 999));
  });

  test('a custom range covers its first and last day in full', () {
    final range = TimeRangeSelector.customRange(DateTime(2026, 3, 1), DateTime(2026, 3, 3));

    expect(range.start, DateTime(2026, 3, 1));
    expect(range.end, DateTime(2026, 3, 3, 23, 59, 59, 999));
    expect(range.contains(DateTime(2026, 3, 3, 22)), isTrue);
  });
}
