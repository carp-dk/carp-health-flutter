import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
import '../support/health_test_context.dart';

/// Writing a workout again without adding a copy, and the zone offsets of its records.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HealthTestContext ctx;

  setUp(() async {
    ctx = HealthTestContext();
    await ctx.setUp();
    ctx.channel.when('writeWorkoutData', true);
    ctx.channel.when('writeWorkoutDataUUID', 'workout-uuid-1');
  });

  tearDown(() async {
    await ctx.tearDown();
  });

  const methods = ['writeWorkoutData', 'writeWorkoutDataUUID'];

  /// Writes a run with both methods, or throws what they throw.
  Future<void> writeRun({
    WorkoutMetadata? metadata,
    String? clientRecordId,
    double? clientRecordVersion,
    Duration? startZoneOffset,
    Duration? endZoneOffset,
  }) async {
    final success = await ctx.health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.RUNNING,
      start: HealthFixtures.start,
      end: HealthFixtures.end,
      metadata: metadata,
      clientRecordId: clientRecordId,
      clientRecordVersion: clientRecordVersion,
      startZoneOffset: startZoneOffset,
      endZoneOffset: endZoneOffset,
    );
    expect(success, isTrue);
    final uuid = await ctx.health.writeWorkoutDataUUID(
      activityType: HealthWorkoutActivityType.RUNNING,
      start: HealthFixtures.start,
      end: HealthFixtures.end,
      metadata: metadata,
      clientRecordId: clientRecordId,
      clientRecordVersion: clientRecordVersion,
      startZoneOffset: startZoneOffset,
      endZoneOffset: endZoneOffset,
    );
    expect(uuid, 'workout-uuid-1');
  }

  /// The arguments that each method sent last.
  List<Map<String, dynamic>> sentArgs() => [
    for (final method in methods) Map<String, dynamic>.from(ctx.channel.lastCallFor(method)!.arguments as Map),
  ];

  /// Expects [write] to throw an ArgumentError before either method sends anything.
  Future<void> expectRejected(Future<void> Function() write) async {
    final sent = ctx.channel.calls.length;
    await expectLater(write(), throwsArgumentError);
    expect(ctx.channel.calls.length, sent);
  }

  test('forward the client record id and its version', () async {
    await writeRun(clientRecordId: 'run-1', clientRecordVersion: 3);

    for (final args in sentArgs()) {
      expect(args['clientRecordId'], 'run-1');
      expect(args['clientRecordVersion'], 3.0);
    }
  });

  test('forward the sync identifier and its version with the metadata', () async {
    await writeRun(metadata: const WorkoutMetadata(syncIdentifier: 'run-1', syncVersion: 3));

    for (final args in sentArgs()) {
      expect(args['metadata'], {'syncIdentifier': 'run-1', 'syncVersion': 3});
    }
  });

  test('reject an id without its version and a version without its id', () async {
    await expectRejected(() => writeRun(clientRecordId: 'run-1'));
    await expectRejected(() => writeRun(clientRecordVersion: 3));
    await expectRejected(() => writeRun(metadata: const WorkoutMetadata(syncIdentifier: 'run-1')));
    await expectRejected(() => writeRun(metadata: const WorkoutMetadata(syncVersion: 3)));
    // Each check also stops the UUID write, which the run above does not reach.
    await expectRejected(
      () => ctx.health.writeWorkoutDataUUID(
        activityType: HealthWorkoutActivityType.RUNNING,
        start: HealthFixtures.start,
        end: HealthFixtures.end,
        clientRecordId: 'run-1',
      ),
    );
  });

  test('send the zone offsets in seconds', () async {
    await writeRun(startZoneOffset: const Duration(hours: 5, minutes: 30), endZoneOffset: const Duration(hours: -8));

    for (final args in sentArgs()) {
      expect(args['startZoneOffsetSeconds'], 19800);
      expect(args['endZoneOffsetSeconds'], -28800);
    }
  });

  test('accept zone offsets of up to 18 hours and reject larger ones', () async {
    await writeRun(startZoneOffset: const Duration(hours: 18), endZoneOffset: const Duration(hours: -18));
    await expectRejected(() => writeRun(startZoneOffset: const Duration(hours: 18, seconds: 1)));
    await expectRejected(() => writeRun(endZoneOffset: const Duration(hours: -19)));
  });

  test('send no id, version or zone offset that is not given', () async {
    await writeRun();

    for (final args in sentArgs()) {
      for (final key in ['clientRecordId', 'clientRecordVersion', 'startZoneOffsetSeconds', 'endZoneOffsetSeconds']) {
        expect(args, isNot(contains(key)));
      }
      expect(args, isNot(contains('metadata')));
    }
  });

  test('forward everything together', () async {
    await writeRun(
      metadata: const WorkoutMetadata(indoorWorkout: true, syncIdentifier: 'run-1', syncVersion: 2),
      clientRecordId: 'run-1',
      clientRecordVersion: 2,
      startZoneOffset: const Duration(hours: 1),
      endZoneOffset: const Duration(hours: 2),
    );

    for (final args in sentArgs()) {
      expect(args, containsPair('metadata', {'indoorWorkout': true, 'syncIdentifier': 'run-1', 'syncVersion': 2}));
      expect(args, containsPair('clientRecordId', 'run-1'));
      expect(args, containsPair('clientRecordVersion', 2.0));
      expect(args, containsPair('startZoneOffsetSeconds', 3600));
      expect(args, containsPair('endZoneOffsetSeconds', 7200));
    }
  });
}
