import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/read/read_page.dart';
import 'package:health_example/features/read/read_section.dart';

import '../../shared/support/sample_points.dart';
import '../../shared/support/shared_test_app.dart';
import 'support/read_health.dart';

void main() {
  late ReadHealth health;
  late AppServices services;

  setUp(() {
    health = ReadHealth();
    services = testServices(health);
  });
  tearDown(() => services.dispose());

  Future<void> pumpPage(
    WidgetTester tester, {
    Size size = const Size(360, 800),
    ReadSection section = ReadSection.query,
  }) async {
    usePhoneSize(tester, size: size);
    await tester.pumpWidget(readTestApp(services, ReadPage(initialSection: section)));
    await tester.pumpAndSettle();
  }

  /// Taps the visible widget with [text], scrolling the page to it first.
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pump();
    await tester.tap(find.text(text));
  }

  testWidgets('switches between Query, Lookup and Changes', (tester) async {
    await pumpPage(tester);
    expect(find.text('Read all at once'), findsOneWidget);
    // The page builds lazily: scroll to the end of the form.
    await tester.scrollUntilVisible(find.text('Nothing read yet'), 300, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lookup'));
    await tester.pumpAndSettle();
    expect(find.text('Record by UUID'), findsOneWidget);
    expect(find.text('Read all at once'), findsNothing);

    await tester.tap(find.text('Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Types to follow'), findsOneWidget);
    expect(find.text('Changes token'), findsOneWidget);
    expect(find.byType(PlatformBadge), findsWidgets);
  });

  testWidgets('reads all at once and shows the points grouped by type, with the toolbar', (tester) async {
    health.points = [pointAt(0), pointAt(10, uuid: 'record-2'), pointAt(5, type: HealthDataType.HEART_RATE)];
    await pumpPage(tester);

    await tapText(tester, 'Read all at once');
    await tester.pumpAndSettle();

    expect(health.reads.single.types, [HealthDataType.STEPS, HealthDataType.HEART_RATE]);
    expect(find.text('points · 2 types'), findsOneWidget);
    expect(find.byType(FloatingToolbar), findsOneWidget);

    await tester.tap(find.byTooltip('Remove duplicates'));
    await tester.pumpAndSettle();
    expect(find.text('No duplicates'), findsOneWidget);
  });

  testWidgets('reads page by page with progress, and Cancel keeps the pages read', (tester) async {
    health.cancelHold = Completer<void>();
    await pumpPage(tester);
    await tapText(tester, 'Page by page');
    await tester.pumpAndSettle();

    await tapText(tester, 'Read page by page');
    await tester.pump();
    health.pages!.add(page(HealthDataType.STEPS, [pointAt(0), pointAt(1)]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Reading pages…'), findsOneWidget);
    expect(find.text('Steps'), findsWidgets);

    await tapText(tester, 'Cancel');
    await tester.pump();
    expect(health.pagesCancelled, isTrue);
    expect(find.text('Cancelling…'), findsOneWidget, reason: 'the platform call in flight returns first');

    health.cancelHold!.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Cancelling…'), findsNothing);
    expect(find.text('Cancelled (1 page)'), findsOneWidget);
  });

  testWidgets('an expired changes token offers the full resync in Query', (tester) async {
    health.changePages.add(changesPage(const [], next: 'token-1', expired: true));
    await pumpPage(tester, section: ReadSection.changes);

    await tapText(tester, 'Create token');
    await tester.pumpAndSettle();
    await tapText(tester, 'Fetch changes');
    await tester.pumpAndSettle();
    expect(find.text('Token expired'), findsOneWidget);

    await tapText(tester, 'Read in Query');
    await tester.pumpAndSettle();
    expect(find.text('Read page by page'), findsOneWidget, reason: 'the resync reads page by page');
  });

  testWidgets('Changes explains on iOS that only Health Connect has it', (tester) async {
    services.dispose();
    services = testServices(health, platform: HealthPlatformType.appleHealth);
    await pumpPage(tester, section: ReadSection.changes);

    expect(find.text('Health Connect only'), findsOneWidget);
    expect(health.tokenRequests, isEmpty);

    await tapText(tester, 'Go to Query');
    await tester.pumpAndSettle();
    expect(find.text('Read all at once'), findsOneWidget, reason: 'Query opens as it was');
  });

  testWidgets('looks up a record written in this session by its UUID', (tester) async {
    health.records['uuid-hr'] = heartRatePoint();
    services.recentWrites.add(RecentWrite(type: HealthDataType.HEART_RATE, description: '72 bpm', uuid: 'uuid-hr'));
    await pumpPage(tester, section: ReadSection.lookup);

    await tapText(tester, 'Heart rate · 72 bpm');
    await tester.pumpAndSettle();

    expect(health.lookups, [('uuid-hr', HealthDataType.HEART_RATE)]);
    expect(find.text('Found it'), findsOneWidget);
    expect(find.text('72 bpm'), findsWidgets);
  });

  testWidgets('lays every section out on a tablet', (tester) async {
    await pumpPage(tester, size: const Size(1024, 900));

    for (final section in ['Lookup', 'Changes', 'Query']) {
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
