/// The swimming part of the workout form's state: pool length, laps and stroke count.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'swim_laps.dart';

/// The pool length, laps and stroke count of a swim, and the `SwimmingDetails` they write.
///
/// The plugin takes swimming details for `SWIMMING_POOL` and `SWIMMING_OPEN_WATER` workouts (and plain
/// `SWIMMING` on iOS), a pool length only for `SWIMMING_POOL`, and throws an `ArgumentError` for a lap
/// outside the workout. The laps follow each other from the workout's start ([SwimLaps.build]), so they
/// are always sorted and never overlap.
mixin SwimFormState on WriteFormController {
  List<LapDraft> _laps = const [];

  /// The pool length in meters (`SwimmingDetails.poolLength`), sent for a pool swim only.
  final TextEditingController poolLength = TextEditingController(text: '25');

  /// The number of strokes (`totalSwimmingStrokeCount`), which only HealthKit stores.
  final TextEditingController strokeCount = TextEditingController(text: '72');

  /// When the workout starts: the first lap starts then.
  DateTime get workoutStart;

  /// How long the workout lasts: the laps must fit into it.
  Duration get workoutDuration;

  /// Whether the workout is a swim, which takes swimming details.
  bool get isSwim;

  /// Whether the workout is a pool swim, which also takes a pool length.
  bool get isPoolSwim;

  /// The laps, in order.
  List<LapDraft> get laps => _laps;

  /// How long the laps take together.
  Duration get lapsDuration => SwimLaps.total(_laps);

  /// Whether the laps run past the end of the workout, which the plugin rejects.
  bool get lapsOverrun => lapsDuration > workoutDuration;

  /// The pool length entered, or null.
  double? get pool => NumberField.parse(poolLength.text)?.toDouble();

  /// The distance in meters the laps cover in the pool, or null without laps or a pool length.
  double? get lapDistance {
    final pool = this.pool;
    return isPoolSwim && pool != null && _laps.isNotEmpty ? SwimLaps.distance(_laps.length, pool) : null;
  }

  /// The `swimming` argument: null for a workout that is not a swim, or a swim without laps or a pool
  /// length (nothing to write).
  SwimmingDetails? get swimmingDetails {
    if (!isSwim) return null;
    final poolLength = isPoolSwim ? pool : null;
    if (poolLength == null && _laps.isEmpty) return null;
    return SwimmingDetails(poolLength: poolLength, laps: SwimLaps.build(workoutStart, _laps));
  }

  /// The start time of lap [index], which follows the laps before it.
  DateTime lapStart(int index) => workoutStart.add(SwimLaps.total(_laps.take(index).toList()));

  /// Adds a lap like the last one (or a one-minute freestyle lap).
  void addLap() => _setLaps([..._laps, _laps.isEmpty ? const LapDraft() : _laps.last]);

  /// Removes the lap at [index].
  void removeLap(int index) => _setLaps([..._laps]..removeAt(index));

  /// Replaces the lap at [index] with [lap].
  void updateLap(int index, LapDraft lap) => _setLaps([..._laps]..[index] = lap);

  /// Replaces the laps with the README's sample swim ([SwimLaps.sample]).
  void useSampleLaps() => _setLaps(SwimLaps.sample);

  /// Shortens the laps so that they fit into the workout ([SwimLaps.fit]).
  void fitLaps() => _setLaps(SwimLaps.fit(_laps, workoutDuration));

  /// Sets the pool length to [meters].
  void setPoolLength(double meters) =>
      update(() => poolLength.text = meters == meters.roundToDouble() ? '${meters.round()}' : '$meters');

  @override
  void dispose() {
    poolLength.dispose();
    strokeCount.dispose();
    super.dispose();
  }

  void _setLaps(List<LapDraft> laps) => update(() => _laps = List.unmodifiable(laps));
}
