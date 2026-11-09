import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';
import '../support/stub_device_info.dart';

/// Holds the lookup of the device id, and with it the start of a read, until
/// [release] completes.
class _HeldDeviceInfo extends StubDeviceInfoPlugin {
  final Completer<void> release = Completer<void>();
  bool isAsked = false;

  @override
  Future<IosDeviceInfo> get iosInfo async {
    isAsked = true;
    await release.future;
    return super.iosInfo;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;

  tearDown(() async {
    await ctx.tearDown();
  });

  /// Lets the read run until it has made [count] getDataPage calls.
  Future<void> untilPageCalls(int count) async {
    while (ctx.pageCalls().length < count) {
      await pumpEventQueue(times: 1);
    }
  }

  /// Listens to a read of [types] that must deliver neither pages nor errors.
  StreamSubscription<HealthDataPage> listen(List<HealthDataType> types) => ctx
      .pages(types)
      .listen(
        (page) => fail('unexpected page of ${page.type}'),
        onError: (Object error) => fail('unexpected error: $error'),
      );

  group('Cancelling getHealthDataPages', () {
    test('right after listening makes no platform call', () async {
      ctx = HealthTestContext();
      await ctx.setUp();
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(1)));

      await listen([HealthDataType.HEART_RATE]).cancel();
      await pumpEventQueue();

      expect(ctx.channel.calls, isEmpty);
    });

    test('before the first page is requested reads no page', () async {
      final deviceInfo = _HeldDeviceInfo();
      ctx = HealthTestContext(deviceInfo: deviceInfo);
      await ctx.setUp(configure: false);
      ctx.channel.when('getDataPage', HealthFixtures.page(HealthFixtures.points(1)));

      final subscription = listen([HealthDataType.HEART_RATE]);
      while (!deviceInfo.isAsked) {
        await pumpEventQueue(times: 1);
      }
      final cancelled = subscription.cancel();
      deviceInfo.release.complete();
      await cancelled;
      await pumpEventQueue();

      expect(ctx.channel.calls, isEmpty);
    });

    for (final mode in [HealthIsolateMode.inline, HealthIsolateMode.worker]) {
      test('while the first page is read requests no other page in $mode', () async {
        ctx = HealthTestContext(isolateMode: mode);
        await ctx.setUp();
        final firstPage = Completer<Object?>();
        ctx.channel.whenSequence('getDataPage', [firstPage.future, HealthFixtures.page(HealthFixtures.points(1))]);

        final subscription = listen([HealthDataType.HEART_RATE, HealthDataType.STEPS]);
        await untilPageCalls(1);
        final cancelled = subscription.cancel();
        // A page without points is not delivered: without the cancel, the
        // read would request the next page right away.
        firstPage.complete(HealthFixtures.page([], nextPageToken: 't1'));
        await cancelled;
        await pumpEventQueue();

        expect(ctx.pageCalls(), hasLength(1));
      });

      test('drops the error of the page in flight in $mode', () async {
        ctx = HealthTestContext(isolateMode: mode);
        await ctx.setUp();
        final firstPage = Completer<Object?>();
        ctx.channel.whenSequence('getDataPage', [firstPage.future]);

        final subscription = listen([HealthDataType.HEART_RATE]);
        await untilPageCalls(1);
        // Awaited only at the end, like StreamBuilder, which never awaits it:
        // completing it with the error would be an uncaught error, which
        // fails the test.
        final cancelled = subscription.cancel();
        firstPage.completeError(PlatformException(code: 'RATE_LIMIT_EXCEEDED', message: 'API call quota exceeded'));
        await pumpEventQueue();
        await cancelled;

        expect(ctx.pageCalls(), hasLength(1));
      });
    }
  });
}
