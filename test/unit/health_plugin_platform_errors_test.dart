import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/error_matchers.dart';
import '../support/fixtures.dart';
import '../support/health_test_context.dart';
import '../support/read_helpers.dart';

// Top-level, so that Isolate.run sends nothing but the function.
HealthPlatformException _unavailableError() => HealthPlatformException(
  HealthDataType.STEPS,
  PlatformException(code: 'UNAVAILABLE', message: 'busy', details: {'nativeCode': 6}),
);

Never _throwUnavailableError() => throw _unavailableError();

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

  group('Platform errors', () {
    for (final mode in [HealthIsolateMode.inline, HealthIsolateMode.worker]) {
      for (final MapEntry(key: code, value: (errorCode, isRetryable)) in platformErrorCodes.entries) {
        test('$code is $errorCode in $mode', () async {
          ctx.health.isolateMode = mode;
          final details = {'exception': 'java.lang.IllegalStateException', 'healthConnectErrorCode': 7};
          final error = PlatformException(code: code, message: 'message of $code', details: details);
          ctx.channel.whenSequence('getDataPage', [error, error]);

          final reads = [
            () => ctx.collect([HealthDataType.HEART_RATE]),
            () => ctx.pages([HealthDataType.HEART_RATE]).toList(),
          ];
          for (final read in reads) {
            await expectLater(
              read(),
              throwsA(
                allOf(
                  platformError(code),
                  isA<HealthPlatformException>()
                      .having((e) => e.isRetryable, 'isRetryable', isRetryable)
                      .having((e) => e.errorCode.isRetryable, 'errorCode.isRetryable', isRetryable)
                      .having((e) => e.message, 'message', 'message of $code')
                      .having((e) => e.cause, 'cause', 'message of $code')
                      .having((e) => e.details, 'details', details),
                ),
              ),
            );
          }
        });
      }
    }

    test('existing on PlatformException and on HealthException handlers catch them', () async {
      final error = PlatformException(
        code: 'DEVICE_LOCKED',
        details: {'domain': 'com.apple.healthkit', 'nativeCode': 6},
      );
      ctx.channel.whenSequence('getDataPage', [error, error]);

      try {
        await ctx.collect([HealthDataType.STEPS]);
        fail('expected an error');
      } on PlatformException catch (e) {
        expect(e.code, 'DEVICE_LOCKED');
        expect(e.details, {'domain': 'com.apple.healthkit', 'nativeCode': 6});
      }
      try {
        await ctx.collect([HealthDataType.STEPS]);
        fail('expected an error');
      } on HealthException catch (e) {
        expect(e.errorCode, HealthErrorCode.deviceLocked);
        expect(e.isRetryable, isTrue);
        expect(e.cause, 'DEVICE_LOCKED');
        expect(
          e.toString(),
          "Error requesting health data type 'HealthDataType.STEPS' - cause: DEVICE_LOCKED (DEVICE_LOCKED)",
        );
      }
    });

    test('an error after some pages ends the stream', () async {
      ctx.channel.whenSequence('getDataPage', [
        HealthFixtures.page(HealthFixtures.points(2), nextPageToken: 't1'),
        PlatformException(code: 'RATE_LIMIT_EXCEEDED', message: 'API call quota exceeded'),
      ]);

      await expectLater(
        ctx.pages([HealthDataType.HEART_RATE, HealthDataType.STEPS]),
        emitsInOrder([
          isA<HealthDataPage>().having((p) => p.points.length, 'points', 2),
          emitsError(platformError('RATE_LIMIT_EXCEEDED')),
          emitsDone,
        ]),
      );
      expect(ctx.channel.callsFor('getDataPage'), hasLength(2));
    });

    test('an error in the first type ends the stream before the next type', () async {
      ctx.channel.whenSequence('getDataPage', [
        PlatformException(code: 'UNAVAILABLE'),
        HealthFixtures.page(HealthFixtures.points(1)),
      ]);

      await expectLater(
        ctx.pages([HealthDataType.STEPS, HealthDataType.HEART_RATE]),
        emitsInOrder([emitsError(platformError('UNAVAILABLE', type: HealthDataType.STEPS)), emitsDone]),
      );
      expect(ctx.channel.callsFor('getDataPage'), hasLength(1));
    });

    test('an error in any type fails getHealthDataFromTypes', () async {
      ctx.channel.whenSequence('getDataPage', [
        HealthFixtures.page(HealthFixtures.points(1)),
        PlatformException(code: 'PERMISSION_DENIED'),
      ]);

      await expectLater(
        ctx.collect([HealthDataType.HEART_RATE, HealthDataType.STEPS]),
        throwsA(platformError('PERMISSION_DENIED', type: HealthDataType.STEPS)),
      );
    });

    test('an invalid reply parsed in a worker fails with a HealthException', () async {
      ctx.health.isolateMode = HealthIsolateMode.worker;
      ctx.channel.when('getDataPage', {'data': 'not a list'});

      await expectLater(
        ctx.collect([HealthDataType.HEART_RATE]),
        throwsA(
          isA<HealthException>()
              .having((e) => e.errorCode, 'errorCode', HealthErrorCode.unknown)
              .having((e) => e.dataType, 'dataType', HealthDataType.HEART_RATE),
        ),
      );
    });

    test('a HealthPlatformException crosses isolates intact', () async {
      final intact = isA<HealthPlatformException>()
          .having((e) => e.errorCode, 'errorCode', HealthErrorCode.unavailable)
          .having((e) => e.dataType, 'dataType', HealthDataType.STEPS)
          .having((e) => e.details, 'details', {'nativeCode': 6});

      expect(await Isolate.run<Object>(_unavailableError), intact);
      await expectLater(Isolate.run<Object>(_throwUnavailableError), throwsA(intact));
    });
  });
}
