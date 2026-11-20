import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';

import '../support/sample_points.dart';
import '../support/shared_test_app.dart';

/// The data point sheet lays out every kind of value without overflowing, which flutter_test reports
/// as an error: on a phone in the light theme, and on a small phone with twice the text size in the
/// dark theme.
void main() {
  late AppServices services;

  setUp(() => services = testServices(LookupHealth()));
  tearDown(() => services.dispose());

  /// Opens [point] in the sheet in [theme], then drags and scrolls to the raw JSON and opens it.
  Future<void> showEverything(WidgetTester tester, HealthDataPoint point, ThemeData theme) async {
    await tester.pumpWidget(
      sharedTestApp(
        launcher('Open', (context) => showDataPointSheet(context, point)),
        services: services,
        theme: theme,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Show JSON'),
      400,
      scrollable: find.descendant(of: find.byType(DataPointSheet), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show JSON'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget, reason: 'the JSON is shown');
  }

  for (final MapEntry(key: name, value: point) in everyKindOfPoint().entries) {
    testWidgets('$name on a phone in the light theme', (tester) async {
      usePhoneSize(tester);
      await showEverything(tester, point, ExpressiveTheme.light());
    });

    testWidgets('$name on a small phone with large text in the dark theme', (tester) async {
      usePhoneSize(tester, size: const Size(320, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await showEverything(tester, point, ExpressiveTheme.dark());
    });
  }

  testWidgets('keeps the end of the content above the home indicator', (tester) async {
    usePhoneSize(tester);
    // 34 dp at the bottom, as on an iPhone without a home button.
    tester.view.padding = const FakeViewPadding(bottom: 102);
    await tester.pumpWidget(
      sharedTestApp(launcher('Open', (context) => showDataPointSheet(context, heartRatePoint())), services: services),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(
      find.descendant(of: find.byType(DataPointSheet), matching: find.byType(ListView)),
    );
    expect(list.padding, const EdgeInsets.fromLTRB(24, 0, 24, 32 + 34));
  });
}
