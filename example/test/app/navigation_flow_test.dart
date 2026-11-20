import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/app/navigation/app_shell.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';

import '../core/support/fake_health.dart';
import '../shared/support/sample_points.dart';
import '../shared/support/shared_test_app.dart';

class _ShellHealth extends FakeHealth {
  @override
  Future<bool?> hasPermissions(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async => true;

  @override
  Future<int> getTotalStepsInInterval(DateTime startTime, DateTime endTime, {bool includeManualEntry = true}) async =>
      5386;

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? limit,
  }) async => [heartRatePoint()];

  @override
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async => [stepsIntervalPoint()];

  @override
  Future<HealthDataPoint?> getHealthDataByUUID({required String uuid, required HealthDataType type}) async =>
      poolSwimPoint();

  @override
  Future<String?> writeWorkoutDataUUID({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalEnergyBurned,
    HealthDataUnit totalEnergyBurnedUnit = HealthDataUnit.KILOCALORIE,
    int? totalDistance,
    HealthDataUnit totalDistanceUnit = HealthDataUnit.METER,
    String? title,
    WorkoutMetadata? metadata,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
    String? clientRecordId,
    double? clientRecordVersion,
    Duration? startZoneOffset,
    Duration? endZoneOffset,
    SwimmingDetails? swimming,
    int? totalSwimmingStrokeCount,
  }) async => 'uuid-workout-1';
}

void main() {
  Finder navTab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  Future<(AppServices, ValueNotifier<AppDestination>)> pumpApp(
    WidgetTester tester, {
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 120, bottom: 72);
    addTearDown(tester.view.reset);

    final health = _ShellHealth();
    final services = testServices(health);
    await services.capabilities.refresh();
    addTearDown(services.dispose);
    final destination = ValueNotifier(AppDestination.overview);
    addTearDown(destination.dispose);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: AppNavigation(
          notifier: destination,
          child: MaterialApp(theme: ExpressiveTheme.light(), home: const AppShell()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (services, destination);
  }

  testWidgets('bottom navigation bar omits top status bar padding', (tester) async {
    await pumpApp(tester);
    final barHeight = tester.getSize(find.byType(NavigationBar)).height;
    // 68 dp bar + 24 dp bottom inset = 92 dp (must not include the 40 dp top status bar inset).
    expect(barHeight, closeTo(68 + 24, 1));
  });

  testWidgets('write workout, inspect from recent writes, toggle Read filters and switch tabs cleanly', (tester) async {
    final (services, _) = await pumpApp(tester);

    // Write page: recent writes hidden while empty; tap Workout card in the grid.
    await tester.tap(navTab('Write'));
    await tester.pumpAndSettle();
    expect(find.text('Recent writes'), findsNothing);
    expect(find.text('Steps'), findsOneWidget);

    await tester.ensureVisible(find.text('Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workout'));
    await tester.pumpAndSettle();

    // Simulate keyboard opening & closing while on form.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Write workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Write workout'));
    await tester.pumpAndSettle();

    // Tap View on the snackbar, pop sheet, pop form back to Write.
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.byType(DataPointSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Tap the active Write tab to scroll back to the top; recent write is promoted right under Sample data.
    await tester.tap(navTab('Write'));
    await tester.pumpAndSettle();
    expect(find.text('Recent writes'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Running'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Running'));
    await tester.pumpAndSettle();
    expect(find.byType(DataPointSheet), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Switch back to Overview (post-frame stale reload) and across Read / Insights / Overview.
    await tester.tap(navTab('Overview'));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Read'));
    await tester.pumpAndSettle();

    // Primary Read button is immediately visible; Filters & limits expands on demand.
    expect(find.text('Read all at once'), findsOneWidget);
    expect(find.text('Imperial units (°F, lb, in)'), findsNothing);
    await tester.ensureVisible(find.text('Filters & limits'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters & limits'));
    await tester.pumpAndSettle();
    expect(find.text('Imperial units (°F, lb, in)'), findsOneWidget);

    await tester.tap(navTab('Read'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lookup'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Query'));
    await tester.pumpAndSettle();

    await tester.tap(navTab('Insights'));
    await tester.pumpAndSettle();
    services.recentWrites.add(RecentWrite(type: HealthDataType.STEPS, description: '100', uuid: 'u2'));
    await tester.tap(navTab('Overview'));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Insights'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Write and Read lay out cleanly on a tablet', (tester) async {
    await pumpApp(tester, size: const Size(900, 1200));
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Write')));
    await tester.pumpAndSettle();
    expect(find.text('Write data'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Read')));
    await tester.pumpAndSettle();
    expect(find.text('Read all at once'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
