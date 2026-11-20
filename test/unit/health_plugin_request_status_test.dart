import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/health_on_ios.dart';
import '../support/health_test_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;
  late Health ios;

  setUp(() async {
    ctx = HealthTestContext();
    await ctx.setUp();
    ios = HealthOnIOS();
  });

  tearDown(() async {
    await ctx.tearDown();
  });

  group('getRequestStatusForAuthorization', () {
    test('throws when permissions length mismatches types', () async {
      await expectLater(
        ios.getRequestStatusForAuthorization(
          [HealthDataType.HEART_RATE],
          permissions: [HealthDataAccess.READ, HealthDataAccess.WRITE],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(ctx.channel.calls, isEmpty);
    });

    test('returns null on Android without calling the platform', () async {
      // The tests run on a desktop host, where Health is on Health Connect.
      final status = await ctx.health.getRequestStatusForAuthorization([HealthDataType.STEPS]);

      expect(status, isNull);
      expect(ctx.channel.calls, isEmpty);
    });

    test('forwards types and read access on iOS and maps the reply', () async {
      ctx.channel.when('getRequestStatusForAuthorization', 'unnecessary');

      final status = await ios.getRequestStatusForAuthorization([HealthDataType.STEPS, HealthDataType.WEIGHT]);

      expect(status, HealthAuthorizationRequestStatus.unnecessary);
      final call = ctx.channel.lastCallFor('getRequestStatusForAuthorization');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['types'], [HealthDataType.STEPS.name, HealthDataType.WEIGHT.name]);
      expect(args['permissions'], [HealthDataAccess.READ.index, HealthDataAccess.READ.index]);
    });

    test('forwards the access asked for', () async {
      ctx.channel.when('getRequestStatusForAuthorization', 'shouldRequest');

      final status = await ios.getRequestStatusForAuthorization(
        [HealthDataType.STEPS, HealthDataType.WORKOUT],
        permissions: [HealthDataAccess.WRITE, HealthDataAccess.READ_WRITE],
      );

      expect(status, HealthAuthorizationRequestStatus.shouldRequest);
      final args = Map<String, dynamic>.from(ctx.channel.lastCall.arguments as Map);
      expect(args['permissions'], [HealthDataAccess.WRITE.index, HealthDataAccess.READ_WRITE.index]);
    });

    test('maps each reply', () async {
      ctx.channel.whenSequence('getRequestStatusForAuthorization', ['shouldRequest', 'unnecessary', 'unknown']);

      final statuses = [
        for (var i = 0; i < 3; i++) await ios.getRequestStatusForAuthorization([HealthDataType.STEPS]),
      ];

      expect(statuses, [
        HealthAuthorizationRequestStatus.shouldRequest,
        HealthAuthorizationRequestStatus.unnecessary,
        HealthAuthorizationRequestStatus.unknown,
      ]);
    });

    test('rejects write access to a type that HealthKit only lets apps read', () async {
      // HealthKit would raise an exception, which crashes the app.
      for (final access in [HealthDataAccess.WRITE, HealthDataAccess.READ_WRITE]) {
        await expectLater(
          ios.getRequestStatusForAuthorization([HealthDataType.ELECTROCARDIOGRAM], permissions: [access]),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(ctx.channel.calls, isEmpty);
    });

    test('throws the PlatformException of a HealthKit error', () async {
      ctx.channel.whenSequence('getRequestStatusForAuthorization', [
        PlatformException(code: 'NOT_SUPPORTED', message: 'Error getting the authorization request status'),
      ]);

      await expectLater(
        ios.getRequestStatusForAuthorization([HealthDataType.STEPS]),
        throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'NOT_SUPPORTED')),
      );
    });
  });

  group('HealthAuthorizationRequestStatus.fromString', () {
    test('maps known values and falls back to null', () {
      expect(
        HealthAuthorizationRequestStatus.fromString('shouldRequest'),
        HealthAuthorizationRequestStatus.shouldRequest,
      );
      expect(HealthAuthorizationRequestStatus.fromString('unnecessary'), HealthAuthorizationRequestStatus.unnecessary);
      expect(HealthAuthorizationRequestStatus.fromString('unknown'), HealthAuthorizationRequestStatus.unknown);
      expect(HealthAuthorizationRequestStatus.fromString(null), isNull);
      expect(HealthAuthorizationRequestStatus.fromString('bogus'), isNull);
    });
  });
}
