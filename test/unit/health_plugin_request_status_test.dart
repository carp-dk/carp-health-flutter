import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/health_test_context.dart';

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

  group('getRequestStatusForAuthorization', () {
    test('throws when permissions length mismatches types', () {
      expect(
        () => ctx.health.getRequestStatusForAuthorization(
          [HealthDataType.HEART_RATE],
          permissions: [HealthDataAccess.READ, HealthDataAccess.WRITE],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns null on non-iOS without invoking the channel', () async {
      final status = await ctx.health.getRequestStatusForAuthorization([HealthDataType.STEPS]);

      expect(status, isNull);
      expect(ctx.channel.lastCallFor('getRequestStatusForAuthorization'), isNull);
    }, skip: Platform.isIOS ? 'iOS forwards to the channel' : false);

    test('iOS: forwards types/permissions and maps the result', () async {
      ctx.channel.when('getRequestStatusForAuthorization', 'unnecessary');

      final status = await ctx.health.getRequestStatusForAuthorization([HealthDataType.STEPS, HealthDataType.WEIGHT]);

      expect(status, HealthAuthorizationRequestStatus.unnecessary);
      final call = ctx.channel.lastCallFor('getRequestStatusForAuthorization');
      expect(call, isNotNull);
      final args = Map<String, dynamic>.from(call!.arguments as Map);
      expect(args['types'], [HealthDataType.STEPS.name, HealthDataType.WEIGHT.name]);
      expect(args['permissions'], [HealthDataAccess.READ.index, HealthDataAccess.READ.index]);
    }, skip: Platform.isIOS ? false : 'channel path only runs on iOS');

    test('iOS: maps shouldRequest and unknown', () async {
      ctx.channel.when('getRequestStatusForAuthorization', 'shouldRequest');
      expect(
        await ctx.health.getRequestStatusForAuthorization([HealthDataType.STEPS]),
        HealthAuthorizationRequestStatus.shouldRequest,
      );

      ctx.channel.when('getRequestStatusForAuthorization', 'unknown');
      expect(
        await ctx.health.getRequestStatusForAuthorization([HealthDataType.STEPS]),
        HealthAuthorizationRequestStatus.unknown,
      );
    }, skip: Platform.isIOS ? false : 'channel path only runs on iOS');
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
