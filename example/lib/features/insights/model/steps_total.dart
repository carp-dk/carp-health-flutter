/// The answer of one `getTotalStepsInInterval` call, with the arguments it was asked with.
library;

import 'package:health_example/core/time/time_range.dart';

/// The [steps] `getTotalStepsInInterval` counted over [range], with or without manual entries
/// ([includeManualEntry]).
class StepsTotal {
  /// Creates the result of a step count.
  const StepsTotal({required this.steps, required this.range, required this.includeManualEntry});

  /// The steps counted: 0 when there were none (the plugin returns 0 rather than null since 14.0.0).
  final int steps;

  /// The time range counted: `startTime` to `endTime`.
  final TimeRange range;

  /// The `includeManualEntry` argument.
  final bool includeManualEntry;

  @override
  String toString() => 'StepsTotal($steps, includeManualEntry: $includeManualEntry, $range)';
}
