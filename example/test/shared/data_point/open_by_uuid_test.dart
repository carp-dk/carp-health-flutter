import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/data_point/open_by_uuid.dart';

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

  /// Shows a "View" button that opens the heart rate record `uuid-hr`.
  Future<void> pumpViewButton(WidgetTester tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      sharedTestApp(
        launcher('View', (context) => openDataPointByUuid(context, uuid: 'uuid-hr', type: HealthDataType.HEART_RATE)),
        services: services,
      ),
    );
  }

  testWidgets('shows progress while the plugin reads, then the record in the sheet', (tester) async {
    health.records['uuid-hr'] = heartRatePoint();
    health.hold = Completer<void>();
    await pumpViewButton(tester);

    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reading Heart rate'), findsOneWidget);
    expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
    expect(health.lookups, [('uuid-hr', HealthDataType.HEART_RATE)]);

    // The read cannot be abandoned half-way: back leaves the progress dialog up.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Reading Heart rate'), findsOneWidget);

    health.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Reading Heart rate'), findsNothing);
    expect(find.byType(DataPointSheet), findsOneWidget);
    expect(find.text('72 bpm'), findsOneWidget);
  });

  testWidgets('explains a null from the plugin in a snack bar', (tester) async {
    await pumpViewButton(tester);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.byType(DataPointSheet), findsNothing);
    expect(find.text('No Heart rate record with this UUID, or no read access.'), findsOneWidget);
  });

  testWidgets('names an error in a snack bar, with its details a tap away', (tester) async {
    health.lookupError = HealthPlatformException(
      HealthDataType.HEART_RATE,
      PlatformException(code: 'PERMISSION_DENIED', message: 'Missing READ_HEART_RATE'),
    );
    await pumpViewButton(tester);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('Permission needed'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Missing READ_HEART_RATE'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
