import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

/// Health Connect lets an app that may write a type, but not read it, read the
/// records it wrote itself: Android then flags every page 'permissionDenied'
/// and sends those records as its points.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;

  setUp(() async {
    ctx = HealthTestContext();
    await ctx.setUp();
  });

  tearDown(() async {
    await ctx.tearDown();
  });

  // Three pages of the app's own records, each flagged, as Android replies them.
  List<Map<String, dynamic>> ownPages() => [
    HealthFixtures.page(HealthFixtures.points(3), nextPageToken: 'o1:1:5', permissionDenied: true),
    HealthFixtures.page(HealthFixtures.points(2, offset: 3), nextPageToken: 'o1:4:9', permissionDenied: true),
    HealthFixtures.page(HealthFixtures.points(1, offset: 5), permissionDenied: true),
  ];

  test('a flagged page holds the points of the app\'s own records', () async {
    ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(2), permissionDenied: true));

    final streamed = await ctx.pages([HealthDataType.HEART_RATE]).toList();

    expect(streamed.map((p) => (p.points.length, p.isLastPageForType, p.readPermissionDenied)), [(2, true, true)]);
    expect(streamed.single.points.map((p) => p.uuid), ['uuid-0', 'uuid-1']);
  });

  test('every page of the read keeps its points and the flag', () async {
    ctx.channel.whenSequence('getDataPage', ownPages());

    final streamed = await ctx.pages([HealthDataType.HEART_RATE]).toList();

    expect(streamed.map((p) => (p.points.length, p.isLastPageForType, p.readPermissionDenied)), [
      (3, false, true),
      (2, false, true),
      (1, true, true),
    ]);
    expect(ctx.pageCalls().map((args) => args['pageToken']), [null, 'o1:1:5', 'o1:4:9']);
  });

  test('getHealthDataFromTypes returns the points of every page', () async {
    ctx.channel.whenSequence('getDataPage', ownPages());

    final points = await ctx.collect([HealthDataType.HEART_RATE]);

    expect(points.map((p) => p.uuid), [for (var i = 0; i < 6; i++) 'uuid-$i']);
  });

  test('a read with a limit returns the newest of them', () async {
    ctx.channel.whenSequence('getDataPage', ownPages());

    final points = await ctx.health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: HealthFixtures.start,
      endTime: HealthFixtures.end,
      limit: 4,
    );

    // The pages are read until 4 points are in, then cut to the 4 that end last.
    expect(points.map((p) => p.uuid), ['uuid-4', 'uuid-3', 'uuid-2', 'uuid-1']);
    expect(ctx.pageCalls(), hasLength(2));
  });
}
