/// The state of the Workout route form and its plugin calls: the workouts to attach a route to
/// (`getHealthDataFromTypes`), and the route builder (`startWorkoutRoute`, `insertWorkoutRouteData`,
/// `finishWorkoutRoute`, `discardWorkoutRoute`).
library;

import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';

import 'route_step.dart';
import 'route_workout.dart';
import 'sample_route.dart';

/// Attaches the sample route ([SampleRoute]) to a workout, as an app that records a route does: it opens
/// a route builder, adds the locations and finishes the route for the workout's UUID. When a step fails,
/// it discards the builder, as an app does when a session is cancelled ([performWrite]).
///
/// The workouts come from a read of the last [lookBack] ([loadWorkouts]), or from a sample walk this
/// form writes itself ([writeSampleWorkout]). [startAndDiscard] shows `discardWorkoutRoute` on its own.
class WorkoutRouteController extends WriteFormController {
  /// Creates the form's state, writing through [health]; [recentWrites] tell which workouts this app
  /// wrote, and [clock] (`DateTime.now` by default) the current time.
  WorkoutRouteController(super.health, {required this.recentWrites, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// What this app wrote in this session.
  final RecentWrites recentWrites;

  final DateTime Function() _clock;

  /// How far back [loadWorkouts] reads.
  static const Duration lookBack = Duration(days: 7);

  /// The most workouts [loadWorkouts] reads (the newest).
  static const int workoutLimit = 20;

  /// The `metadata` the route is finished with; HealthKit stores it on the route, Health Connect has none.
  static const Map<String, dynamic> routeMetadata = {'sample_source': 'health_example_app'};

  AsyncValue<List<RouteWorkout>> _workouts = const AsyncIdle();
  AsyncValue<WriteOutcome> _sampleWorkout = const AsyncIdle();
  AsyncValue<bool> _discarded = const AsyncIdle();
  RouteWorkout? _selected;
  List<RouteStep> _steps = const [];

  /// The workouts to choose from, newest first.
  AsyncValue<List<RouteWorkout>> get workouts => _workouts;

  /// The state of the last [writeSampleWorkout].
  AsyncValue<WriteOutcome> get sampleWorkout => _sampleWorkout;

  /// The state of the last [startAndDiscard]: what `discardWorkoutRoute` returned.
  AsyncValue<bool> get discarded => _discarded;

  /// The workout the route is attached to.
  RouteWorkout? get selected => _selected;

  /// The plugin calls of the last write or discard, as they run.
  List<RouteStep> get steps => _steps;

  /// Whether a route is being written or discarded.
  bool get isBusy => isWriting || _discarded.isLoading;

  /// Chooses [workout] for the route.
  void select(RouteWorkout workout) => update(() => _selected = workout);

  /// The locations of the route over the chosen workout; none without one, or when it is too short.
  List<WorkoutRouteLocation> get locations => switch (_selected) {
    final workout? when SampleRoute.fits(workout.start, workout.end) => SampleRoute.over(workout.start, workout.end),
    _ => const [],
  };

  @override
  HealthDataType get type => HealthDataType.WORKOUT_ROUTE;

  /// A route needs write access to routes, and to the workout it is added to.
  @override
  List<HealthDataType> get accessTypes => const [HealthDataType.WORKOUT, HealthDataType.WORKOUT_ROUTE];

  @override
  String get description => switch (_selected) {
    final workout? => '${SampleRoute.coordinates.length} locations on ${workout.label}, ${workout.time}',
    null => 'A route without a workout',
  };

  /// Reads the newest [workoutLimit] workouts of the last [lookBack] (and the next day, for workouts written
  /// ahead) with `getHealthDataFromTypes`, and keeps the chosen one, or chooses the newest this app wrote.
  /// Never throws: a failure is kept in [workouts].
  Future<void> loadWorkouts() async {
    if (_workouts.isLoading) return;
    update(() => _workouts = _workouts.toLoading());
    final now = _clock();
    final result = await AsyncValue.guard(() async {
      final points = await health.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT],
        startTime: now.subtract(lookBack),
        endTime: now.add(const Duration(days: 1)),
        limit: workoutLimit,
      );
      final ours = {for (final write in recentWrites.ofType(HealthDataType.WORKOUT)) ?write.uuid};
      return [
        for (final point in points..sort((a, b) => b.dateTo.compareTo(a.dateTo)))
          RouteWorkout.fromPoint(point, writtenHere: ours.contains(point.uuid)),
      ];
    });
    update(() {
      _workouts = result;
      final found = result.valueOrNull ?? const <RouteWorkout>[];
      if (!found.contains(_selected)) {
        _selected = found.where((workout) => workout.writtenHere).firstOrNull ?? found.firstOrNull;
      }
    });
  }

  /// Writes a 30-minute walk that ends now with `writeWorkoutDataUUID` and chooses it, for a device without
  /// workouts of this app (Health Connect lets an app add a route only to its own workouts). Never throws.
  Future<AsyncValue<WriteOutcome>> writeSampleWorkout() async {
    if (_sampleWorkout.isLoading) return _sampleWorkout;
    update(() => _sampleWorkout = const AsyncLoading());
    final end = _clock();
    final start = end.subtract(const Duration(minutes: 30));
    final result = await AsyncValue.guard(() async {
      final uuid = await health.writeWorkoutDataUUID(
        activityType: HealthWorkoutActivityType.WALKING,
        start: start,
        end: end,
        totalDistance: 1500,
        totalEnergyBurned: 150,
        recordingMethod: RecordingMethod.manual,
      );
      return WriteOutcome.fromUuid(
        'writeWorkoutDataUUID',
        HealthDataType.WORKOUT,
        'Walking · 30 min · 1,500 m · 150 kcal',
        uuid,
      );
    });
    update(() {
      _sampleWorkout = result;
      if (result case AsyncData(value: WriteOutcome(:final uuid?))) {
        final walk = RouteWorkout(
          uuid: uuid,
          activity: HealthWorkoutActivityType.WALKING,
          start: start,
          end: end,
          sourceName: 'This app',
          writtenHere: true,
        );
        // A read right after the write may not return it yet, so it joins the list directly.
        final others = (_workouts.valueOrNull ?? const <RouteWorkout>[]).where((workout) => workout != walk);
        _workouts = AsyncData([walk, ...others]);
        _selected = walk;
      }
    });
    return result;
  }

  /// Opens a route builder, adds the locations and finishes the route for the chosen workout. If a step
  /// fails, the builder is discarded and the step's error is thrown.
  @override
  Future<WriteOutcome> performWrite() async {
    final workout = _selected ?? (throw StateError('Choose the workout to attach the route to.'));
    final locations = SampleRoute.over(workout.start, workout.end);
    _setSteps(const [
      RouteStep('startWorkoutRoute'),
      RouteStep('insertWorkoutRouteData'),
      RouteStep('finishWorkoutRoute'),
    ]);
    String? builderId;
    try {
      final id = await _run<String>(0, health.startWorkoutRoute, _quoted);
      builderId = id;
      await _insert(1, id, locations);
      final routeUuid = await _run(
        2,
        () => health.finishWorkoutRoute(builderId: id, workoutUuid: workout.uuid, metadata: routeMetadata),
        _quoted,
      );
      return WriteOutcome.fromUuid('finishWorkoutRoute', type, description, routeUuid);
    } catch (_) {
      // A started builder stays open until it is finished or discarded.
      if (builderId != null) await _discardAfterFailure(builderId);
      rethrow;
    }
  }

  /// Opens a route builder, adds the locations and discards it, as an app does when the user cancels a
  /// recording; the builder is discarded even when adding the locations fails. Never throws.
  Future<void> startAndDiscard() async {
    if (isBusy) return;
    final now = _clock();
    final workout = _selected;
    final locations = workout != null && SampleRoute.fits(workout.start, workout.end)
        ? SampleRoute.over(workout.start, workout.end)
        : SampleRoute.over(now.subtract(const Duration(minutes: 30)), now);
    update(() {
      _discarded = const AsyncLoading();
      _steps = const [
        RouteStep('startWorkoutRoute'),
        RouteStep('insertWorkoutRouteData'),
        RouteStep('discardWorkoutRoute'),
      ];
    });
    final result = await AsyncValue.guard(() async {
      final id = await _run(0, health.startWorkoutRoute, _quoted);
      late final bool discarded;
      try {
        await _insert(1, id, locations);
      } finally {
        discarded = await _run(2, () => health.discardWorkoutRoute(id), _plain);
      }
      return discarded;
    });
    update(() => _discarded = result);
  }

  /// Adds [locations] to builder [id] as step [index]; `false` is a failure, as nothing was added.
  Future<void> _insert(int index, String id, List<WorkoutRouteLocation> locations) async {
    final added = await _run(index, () => health.insertWorkoutRouteData(builderId: id, locations: locations), _plain);
    if (!added) {
      _mark(index, RouteStepStatus.failed, 'false');
      throw StateError('insertWorkoutRouteData returned false: the locations were not added.');
    }
  }

  /// Discards builder [id] after a failed step, as a step of its own; its own failure is only shown there.
  Future<void> _discardAfterFailure(String id) async {
    _setSteps([..._steps, const RouteStep('discardWorkoutRoute')]);
    try {
      await _run(_steps.length - 1, () => health.discardWorkoutRoute(id), _plain);
    } catch (_) {
      // The step shows the failure; the error of the write is the one to report.
    }
  }

  /// Runs [call] as step [index], marking it running, then done with [describe] of what it returned, or
  /// failed with the title of what it threw (which is rethrown).
  Future<T> _run<T>(int index, Future<T> Function() call, String Function(T value) describe) async {
    _mark(index, RouteStepStatus.running);
    try {
      final value = await call();
      _mark(index, RouteStepStatus.done, describe(value));
      return value;
    } catch (error) {
      _mark(index, RouteStepStatus.failed, ErrorInfo.from(error).title);
      rethrow;
    }
  }

  void _mark(int index, RouteStepStatus status, [String? detail]) =>
      _setSteps([..._steps]..[index] = _steps[index].to(status, detail));

  void _setSteps(List<RouteStep> steps) => update(() => _steps = List.unmodifiable(steps));

  static String _quoted(String value) => '"$value"';

  static String _plain(Object? value) => '$value';
}
