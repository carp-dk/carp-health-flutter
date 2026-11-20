import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/features/insights/insights_page.dart';

import '../../core/support/fake_health.dart';
import '../../shared/support/shared_test_app.dart';

/// A [FakeHealth] whose interval reads find nothing and whose step total is 1,200.
class _InsightsHealth extends FakeHealth {
  final List<List<RecordingMethod>> filters = [];

  @override
  Future<int> getTotalStepsInInterval(DateTime startTime, DateTime endTime, {bool includeManualEntry = true}) async =>
      1200;

  @override
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    filters.add(recordingMethodsToFilter);
    return const [];
  }
}

void main() {
  late _InsightsHealth health;
  late AppServices services;

  Future<void> pumpPage(WidgetTester tester, HealthPlatformType platform, {Size size = const Size(360, 800)}) async {
    services = testServices(health, platform: platform);
    addTearDown(services.dispose);
    await services.capabilities.refresh();
    usePhoneSize(tester, size: size);
    await tester.pumpWidget(sharedTestApp(const InsightsPage(), services: services));
    await tester.pumpAndSettle();
  }

  setUp(() => health = _InsightsHealth());

  testWidgets('Android: chart, options, manual filter and steps total', (tester) async {
    await pumpPage(tester, HealthPlatformType.googleHealthConnect);
    await tester.scrollUntilVisible(find.text('Exclude manual'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Not applied to this type'), findsOneWidget);
    expect(find.textContaining('recordingMethodsToFilter'), findsNothing);

    await tester.tap(find.text('Exclude manual'));
    await tester.pumpAndSettle();
    expect(health.filters.last, [RecordingMethod.manual]);

    await tester.scrollUntilVisible(find.textContaining('1,200'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('1,200'), findsOneWidget);
  });

  testWidgets('iOS on a tablet: lays out cleanly with manual filter supported', (tester) async {
    await pumpPage(tester, HealthPlatformType.appleHealth, size: const Size(900, 1200));
    expect(find.text('Exclude manual'), findsOneWidget);
    expect(find.text('Not applied to this type'), findsNothing);
    expect(find.textContaining('1,200'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
