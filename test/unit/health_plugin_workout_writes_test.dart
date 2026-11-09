import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import '../support/fixtures.dart';
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

  // The arguments both workout writes send for the run that writeRun and
  // writeRunUUID below write, without metadata.
  final runArgs = <String, Object?>{
    'activityType': HealthWorkoutActivityType.RUNNING.name,
    'startTime': HealthFixtures.start.millisecondsSinceEpoch,
    'endTime': HealthFixtures.end.millisecondsSinceEpoch,
    'totalEnergyBurned': 200,
    'totalEnergyBurnedUnit': HealthDataUnit.KILOCALORIE.name,
    'totalDistance': 5000,
    'totalDistanceUnit': HealthDataUnit.METER.name,
    'title': 'Morning run',
    'recordingMethod': RecordingMethod.manual.toInt(),
  };
  // A false field is sent, a null one is not.
  const sampleMetadata = WorkoutMetadata(workoutBrandName: 'Acme Fitness', indoorWorkout: true, coachedWorkout: false);
  const sampleMetadataArgs = {'workoutBrandName': 'Acme Fitness', 'indoorWorkout': true, 'coachedWorkout': false};

  Map<String, dynamic> argsOf(String method) =>
      Map<String, dynamic>.from(ctx.channel.lastCallFor(method)!.arguments as Map);

  Future<bool> writeRun({WorkoutMetadata? metadata}) => ctx.health.writeWorkoutData(
    activityType: HealthWorkoutActivityType.RUNNING,
    start: HealthFixtures.start,
    end: HealthFixtures.end,
    totalEnergyBurned: 200,
    totalDistance: 5000,
    title: 'Morning run',
    metadata: metadata,
    recordingMethod: RecordingMethod.manual,
  );

  Future<String?> writeRunUUID({WorkoutMetadata? metadata}) => ctx.health.writeWorkoutDataUUID(
    activityType: HealthWorkoutActivityType.RUNNING,
    start: HealthFixtures.start,
    end: HealthFixtures.end,
    totalEnergyBurned: 200,
    totalDistance: 5000,
    title: 'Morning run',
    metadata: metadata,
    recordingMethod: RecordingMethod.manual,
  );

  group('writeWorkoutData', () {
    test('forwards the workout and sends no metadata when it is null', () async {
      ctx.channel.when('writeWorkoutData', true);

      final success = await writeRun();

      expect(success, isTrue);
      final args = argsOf('writeWorkoutData');
      expect(args, isNot(contains('metadata')));
      expect(args, runArgs);
    });

    test('forwards metadata as a map of the fields that are set', () async {
      ctx.channel.when('writeWorkoutData', true);

      final success = await writeRun(metadata: sampleMetadata);

      expect(success, isTrue);
      expect(argsOf('writeWorkoutData'), {...runArgs, 'metadata': sampleMetadataArgs});
    });
  });

  group('writeWorkoutDataUUID', () {
    test('forwards the workout and sends no metadata when it is null', () async {
      ctx.channel.when('writeWorkoutDataUUID', 'workout-uuid-1');

      final uuid = await writeRunUUID();

      expect(uuid, 'workout-uuid-1');
      final args = argsOf('writeWorkoutDataUUID');
      expect(args, isNot(contains('metadata')));
      expect(args, runArgs);
    });

    test('forwards metadata as a map of the fields that are set', () async {
      ctx.channel.when('writeWorkoutDataUUID', 'workout-uuid-1');

      final uuid = await writeRunUUID(metadata: sampleMetadata);

      expect(uuid, 'workout-uuid-1');
      expect(argsOf('writeWorkoutDataUUID'), {...runArgs, 'metadata': sampleMetadataArgs});
    });
  });

  group('WorkoutMetadata', () {
    test('toJson holds only the fields that are not null, by field name', () {
      expect(const WorkoutMetadata().toJson(), isEmpty);
      expect(const WorkoutMetadata(groupFitness: false).toJson(), {'groupFitness': false});
      expect(
        const WorkoutMetadata(
          workoutBrandName: 'Acme Fitness',
          indoorWorkout: false,
          groupFitness: true,
          coachedWorkout: true,
          appleFitnessPlusSession: false,
        ).toJson(),
        {
          'workoutBrandName': 'Acme Fitness',
          'indoorWorkout': false,
          'groupFitness': true,
          'coachedWorkout': true,
          'appleFitnessPlusSession': false,
        },
      );
    });

    test('equal fields make equal metadata with equal hash codes', () {
      // Not const, which would make them one and the same object.
      WorkoutMetadata full() => WorkoutMetadata(
        workoutBrandName: 'Acme Fitness',
        indoorWorkout: true,
        groupFitness: false,
        coachedWorkout: true,
        appleFitnessPlusSession: false,
      );

      expect(identical(full(), full()), isFalse);
      expect(full(), full());
      expect(full().hashCode, full().hashCode);
      expect(WorkoutMetadata(), WorkoutMetadata());
      expect(WorkoutMetadata().hashCode, WorkoutMetadata().hashCode);
    });

    test('every field takes part in equality', () {
      final variants = [
        WorkoutMetadata(),
        WorkoutMetadata(workoutBrandName: 'Acme Fitness'),
        WorkoutMetadata(workoutBrandName: 'Other Fitness'),
        WorkoutMetadata(indoorWorkout: true),
        WorkoutMetadata(indoorWorkout: false),
        WorkoutMetadata(groupFitness: true),
        WorkoutMetadata(coachedWorkout: true),
        WorkoutMetadata(appleFitnessPlusSession: true),
      ];

      for (var i = 0; i < variants.length; i++) {
        for (var j = 0; j < variants.length; j++) {
          expect(variants[i] == variants[j], i == j, reason: '${variants[i]} == ${variants[j]}');
        }
      }
    });
  });
}
