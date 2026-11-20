import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/read/changes/changes_controller.dart';
import 'package:health_example/features/read/changes/changes_summary.dart';
import 'package:health_example/features/read/changes/synced_records.dart';

import '../support/read_health.dart';

const _steps = HealthDataType.STEPS;
const _workout = HealthDataType.WORKOUT;

void main() {
  late ReadHealth health;
  late PlatformCapabilities capabilities;
  late ChangesController controller;

  ChangesController create(HealthPlatformType platform) => ChangesController(
    health: health,
    capabilities: capabilities = PlatformCapabilities(health, platform: platform, iosMajorVersion: 18),
    available: const [_workout, _steps, HealthDataType.WEIGHT],
  );

  setUp(() {
    health = ReadHealth();
    controller = create(HealthPlatformType.googleHealthConnect);
  });
  tearDown(() {
    controller.dispose();
    capabilities.dispose();
  });

  ChangesSummary summaryOf(ChangesController controller) => (controller.sync as AsyncData<ChangesSummary>).value;

  test('follows steps and workouts at first, as the old example did', () {
    expect(controller.types, {_steps, _workout});
    expect(controller.canSync, isFalse);
    expect(controller.canCreateToken, isTrue);
  });

  test('makes a token for the chosen types, in the order the chips show them', () async {
    await controller.createToken();

    expect(health.tokenRequests.single, [_steps, _workout]);
    expect(controller.token, 'token-1');
    expect(controller.tokenTypes, [_steps, _workout]);
    expect(controller.tokenFollowsSelection, isTrue);
    expect(controller.canSync, isTrue);

    controller.types = {_steps};
    expect(controller.tokenFollowsSelection, isFalse);
  });

  test('reports a failed or empty token request', () async {
    health.tokenError = HealthPlatformException(_steps, PlatformException(code: 'RATE_LIMIT_EXCEEDED'));
    await controller.createToken();
    expect(controller.tokenRequest.errorOrNull, isA<HealthPlatformException>());
    expect(controller.token, isNull);

    health
      ..tokenError = null
      ..token = null;
    await controller.createToken();
    expect(controller.tokenRequest.errorOrNull, isA<StateError>());
  });

  test('fetches while hasMore, moving on with each nextChangesToken', () async {
    await controller.createToken();
    controller.includeSelf = false;
    health.changePages.addAll([
      changesPage([upsertChange('a'), upsertChange('b')], next: 'token-2', hasMore: true),
      changesPage([upsertChange('a', value: 5), deleteChange('b'), deleteChange('x')], next: 'token-3'),
    ]);

    await controller.fetchChanges();

    expect(health.changeRequests, [('token-1', false), ('token-2', false)]);
    expect(controller.token, 'token-3');
    expect(controller.previousToken, 'token-2');
    final summary = summaryOf(controller);
    expect(summary.calls, 2);
    expect((summary.inserted, summary.updated, summary.removed, summary.unknownDeletes), (2, 1, 1, 1));
    expect(controller.records.recordCount, 1);
    expect(controller.recent.map((entry) => (entry.recordId, entry.outcome)), [
      ('x', ChangeOutcome.unknownDelete),
      ('b', ChangeOutcome.removed),
      ('a', ChangeOutcome.updated),
      ('b', ChangeOutcome.inserted),
      ('a', ChangeOutcome.inserted),
    ], reason: 'newest first');
    expect(controller.lastSyncAt, isNotNull);
  });

  test('stops at an expired token and keeps it, until a new token is made', () async {
    await controller.createToken();
    health.changePages.add(changesPage(const [], next: 'token-1', expired: true));

    await controller.fetchChanges();

    expect(controller.tokenExpired, isTrue);
    expect(controller.token, 'token-1');
    expect(controller.canSync, isFalse);
    expect(summaryOf(controller).tokenExpired, isTrue);

    health.token = 'token-9';
    await controller.createToken();
    expect(controller.tokenExpired, isFalse);
    expect(controller.canSync, isTrue);
  });

  test('keeps the pages before an error, and fails a sync whose first call failed', () async {
    await controller.createToken();
    final quota = HealthPlatformException(_steps, PlatformException(code: 'RATE_LIMIT_EXCEEDED'));
    health.changePages.addAll([
      changesPage([upsertChange('a')], next: 'token-2', hasMore: true),
      quota,
    ]);

    await controller.fetchChanges();

    expect(summaryOf(controller).error, same(quota));
    expect(controller.records.recordCount, 1);
    expect(controller.token, 'token-2', reason: 'the next sync goes on after the applied page');

    health.changePages.add(quota);
    await controller.fetchChanges();
    expect(controller.sync.errorOrNull, same(quota));
  });

  test('makes at most maxCallsPerSync calls in one sync', () async {
    await controller.createToken();
    for (var i = 0; i < ChangesController.maxCallsPerSync + 5; i++) {
      health.changePages.add(changesPage([upsertChange('r$i')], next: 'token-${i + 2}', hasMore: true));
    }

    await controller.fetchChanges();

    expect(health.changeRequests, hasLength(ChangesController.maxCallsPerSync));
    expect(summaryOf(controller).hasMore, isTrue);
  });

  test('clears the local copy but keeps the token', () async {
    await controller.createToken();
    health.changePages.add(changesPage([upsertChange('a')], next: 'token-2'));
    await controller.fetchChanges();
    expect(controller.canClearLocalCopy, isTrue);

    controller.clearLocalCopy();

    expect(controller.records.recordCount, 0);
    expect(controller.recent, isEmpty);
    expect(controller.sync, isA<AsyncIdle<ChangesSummary>>());
    expect(controller.token, 'token-2');
    expect(controller.canClearLocalCopy, isFalse);
  });

  test('makes no calls on iOS, which has no changes API', () async {
    controller.dispose();
    capabilities.dispose();
    controller = create(HealthPlatformType.appleHealth);

    await controller.createToken();
    await controller.fetchChanges();

    expect(controller.isSupported, isFalse);
    expect(health.tokenRequests, isEmpty);
    expect(health.changeRequests, isEmpty);
  });
}
