import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

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

  group('Back-pressure', () {
    Future<void> serveEndless() => ctx.setUp(
      responder: (call) async {
        final served = ctx.channel.callsFor('getDataPage').length;
        return HealthFixtures.page(HealthFixtures.points(1, offset: served), nextPageToken: 'token-$served');
      },
    );

    test('nothing is read until the stream is listened to', () async {
      await serveEndless();

      final stream = ctx.pages([HealthDataType.HEART_RATE]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(ctx.channel.calls, isEmpty);
      expect((await stream.first).points, hasLength(1));
    });

    test('first reads one page only', () async {
      await serveEndless();

      final first = await ctx.pages([HealthDataType.HEART_RATE]).first;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(first.points.single.uuid, 'uuid-1');
      expect(ctx.pageCalls(), hasLength(1));
    });

    test('with await for, the next page is read once the loop body has finished', () async {
      await serveEndless();

      var received = 0;
      await for (final _ in ctx.pages([HealthDataType.HEART_RATE])) {
        received++;
        expect(ctx.pageCalls(), hasLength(received));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(ctx.pageCalls(), hasLength(received));
        if (received == 3) break;
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ctx.pageCalls(), hasLength(3));
    });

    test('cancelling stops the read after the page in flight', () async {
      final secondPage = Completer<Object?>();
      await ctx.setUp(
        responder: (call) async {
          final served = ctx.channel.callsFor('getDataPage').length;
          if (served == 2) return secondPage.future;
          return HealthFixtures.page(HealthFixtures.points(1, offset: served), nextPageToken: 'token-$served');
        },
      );

      final received = <HealthDataPage>[];
      final subscription = ctx.pages([HealthDataType.HEART_RATE]).listen(received.add);
      while (ctx.pageCalls().length < 2) {
        await pumpEventQueue(times: 1);
      }
      final cancelled = subscription.cancel();
      secondPage.complete(HealthFixtures.page(HealthFixtures.points(1, offset: 2), nextPageToken: 'token-2'));
      await cancelled;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(received, hasLength(1));
      expect(ctx.pageCalls(), hasLength(2));
    });
  });
}
