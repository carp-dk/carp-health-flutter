import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/features/overview/overview_page.dart';

import '../../core/support/fake_health.dart';
import '../../shared/support/shared_test_app.dart';

/// A [FakeHealth] whose reads find nothing, whose access checks answer "missing" or "answered", and
/// whose `requestAuthorization` returns true.
class _OverviewHealth extends FakeHealth {
  int requests = 0;

  @override
  Future<bool?> hasPermissions(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async => false;

  @override
  Future<HealthAuthorizationRequestStatus?> getRequestStatusForAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => HealthAuthorizationRequestStatus.unnecessary;

  @override
  Future<bool> requestAuthorization(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async {
    requests++;
    return true;
  }

  @override
  Future<int> getTotalStepsInInterval(DateTime startTime, DateTime endTime, {bool includeManualEntry = true}) async =>
      1200;

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? limit,
  }) async => const [];

  @override
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async => const [];
}

void main() {
  late _OverviewHealth health;
  late AppServices services;

  Future<void> pumpPage(WidgetTester tester, HealthPlatformType platform, {Size size = const Size(360, 800)}) async {
    services = testServices(health, platform: platform);
    addTearDown(services.dispose);
    await services.capabilities.refresh();
    usePhoneSize(tester, size: size);
    await tester.pumpWidget(sharedTestApp(const OverviewPage(), services: services));
    await tester.pumpAndSettle();
  }

  setUp(() => health = _OverviewHealth());

  testWidgets('Android: shows platform status, requests core access and lists Health Connect features', (tester) async {
    await pumpPage(tester, HealthPlatformType.googleHealthConnect);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Access missing'), findsOneWidget);
    expect(find.textContaining('hasPermissions'), findsNothing);

    await tester.tap(find.text('Grant access'));
    await tester.pumpAndSettle();
    expect(health.requests, 1);
    expect(find.text('Access granted'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('History (30+ days)'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Not available'), findsWidgets);
  });

  testWidgets('iOS: hides Android-only Health Connect features section', (tester) async {
    await pumpPage(tester, HealthPlatformType.appleHealth);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Answered before'), findsOneWidget);
    expect(find.text('Features'), findsNothing);
  });

  testWidgets('lays out side by side on a tablet', (tester) async {
    await pumpPage(tester, HealthPlatformType.googleHealthConnect, size: const Size(900, 1200));
    expect(find.text('Grant access'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
