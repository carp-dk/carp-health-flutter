import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/widgets/write_result.dart';

import '../support/sample_points.dart';
import '../support/shared_test_app.dart';

void main() {
  late LookupHealth health;
  late AppServices services;

  setUp(() {
    health = LookupHealth();
    services = testServices(health);
  });
  tearDown(() => services.dispose());

  /// Shows a "Report" button that reports a heart rate write of 72 bpm with these results.
  Future<void> report(
    WidgetTester tester, {
    required bool success,
    String? uuid,
    Object? error,
    bool withServices = true,
    ValueNotifier<AppDestination>? destination,
  }) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      sharedTestApp(
        launcher(
          'Report',
          (context) => reportWriteResult(
            context,
            type: HealthDataType.HEART_RATE,
            description: '72 bpm',
            success: success,
            uuid: uuid,
            clientRecordId: 'client-1',
            error: error,
          ),
        ),
        services: withServices ? services : null,
        destination: destination,
      ),
    );
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
  }

  testWidgets('a write with a UUID is logged, confirmed and can be viewed', (tester) async {
    health.records['uuid-new'] = heartRatePoint(uuid: 'uuid-new');
    await report(tester, success: true, uuid: 'uuid-new');

    final write = services.recentWrites.items.single;
    expect(
      (write.type, write.description, write.uuid, write.clientRecordId),
      (HealthDataType.HEART_RATE, '72 bpm', 'uuid-new', 'client-1'),
    );
    expect(find.text('Heart rate written: 72 bpm'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(health.lookups, [('uuid-new', HealthDataType.HEART_RATE)]);
    expect(find.byType(DataPointSheet), findsOneWidget);
  });

  testWidgets('a write without a UUID is logged without a View action', (tester) async {
    await report(tester, success: true, uuid: '');

    expect(services.recentWrites.items.single.uuid, isNull, reason: 'an empty UUID means nothing to look up');
    expect(find.text('Heart rate written: 72 bpm'), findsOneWidget);
    expect(find.text('View'), findsNothing);
  });

  testWidgets('a false from the plugin is reported and not logged', (tester) async {
    await report(tester, success: false);

    expect(find.text('Heart rate not written: check write access'), findsOneWidget);
    expect(services.recentWrites.items, isEmpty);
    expect(find.text('Setup'), findsNothing, reason: 'no AppNavigation to go to Setup with');
  });

  testWidgets('a false from the plugin offers the way to Setup, where permissions are requested', (tester) async {
    final destination = ValueNotifier(AppDestination.write);
    addTearDown(destination.dispose);
    await report(tester, success: false, destination: destination);

    await tester.tap(find.text('Setup'));
    expect(destination.value, AppDestination.setup);
  });

  testWidgets('an error is named, with its details a tap away', (tester) async {
    await report(tester, success: false, error: ArgumentError('The value must be positive'));

    expect(find.text('Heart rate not written: Invalid argument'), findsOneWidget);
    expect(services.recentWrites.items, isEmpty);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('The value must be positive'), findsOneWidget);
  });

  testWidgets('reports without the app services too, without View', (tester) async {
    await report(tester, success: true, uuid: 'uuid-new', withServices: false);

    expect(find.text('Heart rate written: 72 bpm'), findsOneWidget);
    expect(find.text('View'), findsNothing, reason: "View reads through the app's plugin instance");
  });
}
