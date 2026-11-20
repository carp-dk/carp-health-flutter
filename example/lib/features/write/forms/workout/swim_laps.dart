/// The laps of a swim as the workout form edits them, and the `SwimmingLap`s they write.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// One lap in the lap editor: its stroke style and how long it takes.
///
/// The editor's laps follow each other from the start of the workout, so a lap's times follow from the
/// laps before it ([SwimLaps.build]); this keeps them sorted and without overlaps, as the plugin requires.
@immutable
class LapDraft {
  /// Creates a lap of [duration] in [strokeStyle].
  const LapDraft({this.strokeStyle = SwimmingStrokeStyle.freestyle, this.duration = const Duration(minutes: 1)});

  /// The stroke style the lap is written with.
  final SwimmingStrokeStyle strokeStyle;

  /// How long the lap takes.
  final Duration duration;

  /// This lap with the given fields replaced.
  LapDraft copyWith({SwimmingStrokeStyle? strokeStyle, Duration? duration}) =>
      LapDraft(strokeStyle: strokeStyle ?? this.strokeStyle, duration: duration ?? this.duration);

  @override
  bool operator ==(Object other) => other is LapDraft && other.strokeStyle == strokeStyle && other.duration == duration;

  @override
  int get hashCode => Object.hash(strokeStyle, duration);

  @override
  String toString() => 'LapDraft(${strokeStyle.name}, $duration)';
}

/// What the lap editor does with its laps: sample laps, the [SwimmingLap]s they write, and fitting them
/// into the workout.
abstract final class SwimLaps {
  /// The README's sample swim: four one-minute lengths, two freestyle, one backstroke, one breaststroke.
  static const List<LapDraft> sample = [
    LapDraft(strokeStyle: SwimmingStrokeStyle.freestyle),
    LapDraft(strokeStyle: SwimmingStrokeStyle.freestyle),
    LapDraft(strokeStyle: SwimmingStrokeStyle.backstroke),
    LapDraft(strokeStyle: SwimmingStrokeStyle.breaststroke),
  ];

  /// The pool lengths offered as presets, in meters.
  static const List<double> poolPresets = [25, 50];

  /// How much one tap on a lap's minus or plus changes its duration.
  static const Duration step = Duration(seconds: 15);

  /// The shortest lap the editor makes.
  static const Duration shortest = Duration(seconds: 15);

  /// The longest lap the editor makes.
  static const Duration longest = Duration(minutes: 10);

  /// The [SwimmingLap]s of [laps], one after the other from [start]: what `SwimmingDetails.laps` gets.
  static List<SwimmingLap> build(DateTime start, List<LapDraft> laps) {
    final built = <SwimmingLap>[];
    var lapStart = start;
    for (final lap in laps) {
      final lapEnd = lapStart.add(lap.duration);
      built.add(SwimmingLap(startTime: lapStart, endTime: lapEnd, strokeStyle: lap.strokeStyle));
      lapStart = lapEnd;
    }
    return built;
  }

  /// How long [laps] take together.
  static Duration total(List<LapDraft> laps) => laps.fold(Duration.zero, (sum, lap) => sum + lap.duration);

  /// [laps] with their durations scaled to take at most [available] together, in whole seconds and at
  /// least a second each, so that they fit into a workout that lasts [available].
  static List<LapDraft> fit(List<LapDraft> laps, Duration available) {
    final total = SwimLaps.total(laps);
    if (laps.isEmpty || total <= available) return laps;
    final factor = available.inMilliseconds / total.inMilliseconds;
    return [
      for (final lap in laps)
        lap.copyWith(duration: Duration(seconds: math.max(1, (lap.duration.inSeconds * factor).floor()))),
    ];
  }

  /// The distance in meters that [count] lengths of a [poolLength] meter pool cover.
  static double distance(int count, double poolLength) => count * poolLength;
}
