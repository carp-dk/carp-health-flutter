import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/data_point/value_views/workout/swimming_view.dart';
import 'package:health_example/shared/widgets/error_card.dart';

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

  Future<void> openSheet(WidgetTester tester, HealthDataPoint point, {ValueChanged<HealthDataPoint>? onDeleted}) async {
    usePhoneSize(tester);
    await tester.pumpWidget(
      sharedTestApp(
        launcher('Open', (context) => showDataPointSheet(context, point, onDeleted: onDeleted)),
        services: services,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// The button labelled [label], whichever button class draws it.
  ButtonStyleButton button(WidgetTester tester, String label) => tester.widget<ButtonStyleButton>(
    find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton)),
  );

  /// Drags the sheet up (growing it, then scrolling it) until [finder] shows.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.descendant(of: find.byType(DataPointSheet), matching: find.byType(Scrollable)).first,
    );
    // scrollUntilVisible ends with a jump that the next frame lays out.
    await tester.pumpAndSettle();
  }

  testWidgets('shows the value in big type, the record fields and the raw JSON', (tester) async {
    await openSheet(tester, heartRatePoint());

    expect(find.text('72 bpm'), findsOneWidget, reason: 'the headline');
    expect(find.text('Automatic'), findsWidgets, reason: 'the recording method pill');
    expect(find.text('Health Connect'), findsOneWidget);
    await scrollTo(tester, find.text('Pixel Watch 2'));
    expect(find.text('com.example.watch'), findsOneWidget);
    expect(find.text('uuid-hr'), findsOneWidget);
    await scrollTo(tester, find.text('Raw JSON'));
    expect(find.text('Show JSON'), findsOneWidget);
  });

  testWidgets('shows a workout with its typed view', (tester) async {
    await openSheet(tester, poolSwimPoint());

    expect(find.text('Swimming pool'), findsOneWidget, reason: 'the headline names the activity');
    await scrollTo(tester, find.byType(SwimmingView));
    expect(find.text('Freestyle'), findsOneWidget);
  });

  group('Re-read by UUID', () {
    testWidgets('calls getHealthDataByUUID and shows the record it returns', (tester) async {
      health.records['uuid-hr'] = heartRatePoint(bpm: 80);
      await openSheet(tester, heartRatePoint());

      await tester.tap(find.text('Re-read by UUID'));
      await tester.pumpAndSettle();

      expect(health.lookups, [('uuid-hr', HealthDataType.HEART_RATE)]);
      expect(find.text('80 bpm'), findsOneWidget);
      expect(find.textContaining('Re-read at'), findsOneWidget);
    });

    testWidgets('shows progress while the plugin reads', (tester) async {
      health.hold = Completer<void>();
      await openSheet(tester, heartRatePoint());

      await tester.tap(find.text('Re-read by UUID'));
      await tester.pump();
      expect(find.byType(ExpressiveLoadingIndicator), findsOneWidget);
      expect(button(tester, 'Delete').enabled, isFalse, reason: 'no second call while one runs');

      health.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ExpressiveLoadingIndicator), findsNothing);
    });

    testWidgets('explains a null from the plugin', (tester) async {
      await openSheet(tester, heartRatePoint());

      await tester.tap(find.text('Re-read by UUID'));
      await tester.pumpAndSettle();

      expect(find.textContaining('getHealthDataByUUID returned null'), findsOneWidget);
    });

    testWidgets('shows a failure in an error card with a retry', (tester) async {
      health.lookupError = HealthPlatformException(
        HealthDataType.HEART_RATE,
        PlatformException(code: 'RATE_LIMIT_EXCEEDED', message: 'API quota used up'),
      );
      await openSheet(tester, heartRatePoint());

      await tester.tap(find.text('Re-read by UUID'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorCard), findsOneWidget);
      expect(find.text('Rate limit reached'), findsOneWidget);
      health.lookupError = null;
      health.records['uuid-hr'] = heartRatePoint(bpm: 75);
      // The first drag grows the sheet to full height, which brings the card's button into view.
      await tester.drag(find.byType(DataPointSheet), const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(health.lookups, hasLength(2));
      expect(find.byType(ErrorCard), findsNothing);
      expect(find.text('75 bpm'), findsOneWidget);
    });
  });

  group('Delete', () {
    testWidgets('explains that apps delete only their own data, deletes, closes and reports it', (tester) async {
      HealthDataPoint? deleted;
      final point = heartRatePoint();
      services.recentWrites.add(RecentWrite(type: HealthDataType.HEART_RATE, description: '72 bpm', uuid: 'uuid-hr'));
      health.deletable.add('uuid-hr');
      await openSheet(tester, point, onDeleted: (point) => deleted = point);
      expect(find.text('Written by this app'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this record?'), findsOneWidget);
      expect(find.textContaining('Apps can delete only the data they wrote themselves'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await tester.pumpAndSettle();

      expect(health.deletions, [('uuid-hr', HealthDataType.HEART_RATE)]);
      expect(find.byType(DataPointSheet), findsNothing);
      expect(find.text('Heart rate record deleted with deleteByUUID'), findsOneWidget);
      expect(deleted, same(point));
      expect(services.recentWrites.items, isEmpty, reason: 'the deleted record leaves the recent writes');
    });

    testWidgets('deletes nothing when the user cancels', (tester) async {
      await openSheet(tester, heartRatePoint());

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(health.deletions, isEmpty);
      expect(find.byType(DataPointSheet), findsOneWidget);
    });

    testWidgets('explains a false from the plugin and keeps the sheet open', (tester) async {
      await openSheet(tester, heartRatePoint());

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
      await tester.pumpAndSettle();

      expect(find.byType(DataPointSheet), findsOneWidget);
      expect(find.textContaining('deleteByUUID returned false'), findsOneWidget);
    });
  });

  testWidgets('an interval point has no UUID: its actions are off and say why', (tester) async {
    await openSheet(tester, stepsIntervalPoint());

    expect(button(tester, 'Re-read by UUID').enabled, isFalse);
    expect(button(tester, 'Delete').enabled, isFalse);
    expect(find.textContaining('This data point has no UUID'), findsOneWidget);
  });
}
