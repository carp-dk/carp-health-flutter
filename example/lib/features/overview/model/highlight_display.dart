/// What a highlight tile shows for the state of its read, and what tapping it does: each tile handles
/// loading, missing access, no data and errors on its own.
library;

import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/format/value_formatter.dart';

import 'highlight.dart';
import 'latest_sample.dart';
import 'sleep_summary.dart';
import 'workout_week.dart';

/// What tapping a highlight tile does.
enum HighlightTap {
  /// Nothing: the tile is static.
  none,

  /// Requests access to the highlight's types (`requestAuthorization`) and reads it again.
  authorize,

  /// Shows the full error.
  showError,

  /// Opens the data point sheet of [HighlightDisplay.point].
  openPoint,

  /// Lists the week's workouts.
  openWorkouts,
}

/// The texts of a highlight's `MetricTile` and its [tap] action.
class HighlightDisplay {
  /// Creates the display of a tile.
  const HighlightDisplay({
    this.value,
    this.unit,
    this.footnote,
    this.error,
    this.loading = false,
    this.tap = HighlightTap.none,
    this.point,
  });

  /// The display of [highlight] for the [state] of its read on [platform], seen from [now].
  ///
  /// A permission error offers to grant access, any other error shows its headline and opens the
  /// full error on tap, and data without a value shows a dash with a footnote saying why.
  factory HighlightDisplay.of(
    Highlight highlight,
    AsyncValue<Object?> state, {
    required HealthPlatformType platform,
    DateTime? now,
  }) => switch (state) {
    AsyncIdle() || AsyncLoading(previous: null) => const HighlightDisplay(loading: true),
    AsyncError(:final error) when ErrorInfo.from(error).isPermission => const HighlightDisplay(
      error: 'Tap to grant',
      tap: HighlightTap.authorize,
    ),
    AsyncError(:final error) => HighlightDisplay(
      error: ErrorInfo.from(error).title,
      tap: HighlightTap.showError,
    ),
    // Data, or a refresh that keeps the previous data on screen.
    _ => _ofValue(highlight, state.valueOrNull, platform, now),
  };

  /// The formatted number, or null for no data (the tile shows a dash).
  final String? value;

  /// The unit after the number.
  final String? unit;

  /// A line under the number.
  final String? footnote;

  /// Why the value could not be read, shown instead of it.
  final String? error;

  /// Whether the value is being read.
  final bool loading;

  /// What tapping the tile does.
  final HighlightTap tap;

  /// The data point [HighlightTap.openPoint] opens.
  final HealthDataPoint? point;

  static HighlightDisplay _ofValue(Highlight highlight, Object? value, HealthPlatformType platform, DateTime? now) {
    return switch ((highlight, value)) {
      (Highlight.steps, final int steps) => HighlightDisplay(
        value: formatNumber(steps),
        footnote: steps > 0 ? 'Today' : 'No steps today',
      ),
      (Highlight.heartRate || Highlight.weight, LatestSample(readDenied: true)) => const HighlightDisplay(
        error: 'Tap to grant',
        tap: HighlightTap.authorize,
      ),
      (Highlight.heartRate || Highlight.weight, final LatestSample sample) => _latest(highlight, sample, now),
      (Highlight.activeEnergy, final double kcal) => HighlightDisplay(
        value: formatNumber(kcal, maxDecimals: 0),
        unit: 'kcal',
        footnote: 'Today',
      ),
      (Highlight.activeEnergy, null) => const HighlightDisplay(footnote: 'Today'),
      (Highlight.sleep, final SleepSummary sleep) => _sleep(sleep),
      (Highlight.workouts, final WorkoutWeek week) => _workouts(week),
      _ => const HighlightDisplay(footnote: 'No data'),
    };
  }

  /// The newest heart rate or weight, with how long ago it was measured.
  static HighlightDisplay _latest(Highlight highlight, LatestSample sample, DateTime? now) {
    final point = sample.point;
    final value = sample.value;
    if (point == null) {
      return HighlightDisplay(footnote: highlight == Highlight.heartRate ? 'Last 30d' : 'Last year');
    }
    return HighlightDisplay(
      // A value that is not a number (never expected here) shows as the formatter has it.
      value: value == null
          ? formatPointValue(point)
          : formatNumber(value, maxDecimals: highlight == Highlight.heartRate ? 0 : 1),
      unit: value == null ? null : formatUnit(point.unit),
      footnote: formatRelative(point.dateTo, now: now),
      tap: HighlightTap.openPoint,
      point: point,
    );
  }

  /// Last night: the time asleep where the night has stages, else the time in bed.
  static HighlightDisplay _sleep(SleepSummary sleep) {
    if (!sleep.hasData) return const HighlightDisplay(footnote: 'Last night');
    final footnote = switch ((sleep.showsAsleep, sleep.inBed)) {
      (true, final Duration inBed) => 'In bed ${formatDuration(inBed)}',
      (true, null) => 'Asleep',
      (false, _) => 'In bed',
    };
    return HighlightDisplay(value: formatDuration(sleep.headline), footnote: footnote);
  }

  /// The week's workouts: how many, how long in total and the newest activity.
  static HighlightDisplay _workouts(WorkoutWeek week) {
    if (week.count == 0) return const HighlightDisplay(value: '0', footnote: 'This week');
    final activity = week.latestActivity;
    return HighlightDisplay(
      value: formatNumber(week.count),
      footnote: [
        formatDuration(week.totalDuration),
        if (activity != null) formatEnumName(activity),
      ].join(' · '),
      tap: HighlightTap.openWorkouts,
    );
  }
}
