/// The swimming details of a workout: the pool length and the laps with their stroke styles.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// The [SwimmingDetails] of a swimming workout (`WorkoutHealthValue.swimming`): its pool length, the
/// distance its laps cover and each lap with its stroke style and time.
///
/// iOS reads them from HealthKit's lap length and lap events, Android from Health Connect's exercise
/// laps and the swimming segments over them. At most [maxLaps] laps are listed.
class SwimmingView extends StatelessWidget {
  /// Creates the view of [details].
  const SwimmingView({super.key, required this.details});

  /// The pool length and laps.
  final SwimmingDetails details;

  /// The most laps listed one by one.
  static const int maxLaps = 50;

  @override
  Widget build(BuildContext context) {
    final poolLength = details.poolLength;
    final laps = details.laps;
    return DetailSection(
      title: 'Swimming',
      subtitle: 'WorkoutHealthValue.swimming',
      children: [
        DetailField(
          label: 'Pool length',
          value: poolLength == null ? 'Not known (open water, or not recorded)' : '${formatNumber(poolLength)} m',
          icon: Icons.straighten,
        ),
        DetailField(
          label: 'Laps',
          value: poolLength == null || laps.isEmpty
              ? formatNumber(laps.length)
              : '${formatNumber(laps.length)} (${formatNumber(laps.length * poolLength)} m)',
          icon: Icons.repeat,
        ),
        for (final (index, lap) in laps.take(maxLaps).indexed) _LapTile(number: index + 1, lap: lap),
        if (laps.length > maxLaps)
          DetailField(label: 'More laps', value: '${laps.length - maxLaps} more laps are not listed'),
      ],
    );
  }
}

/// One lap: its number in a shape, its stroke style and when it started and how long it took.
class _LapTile extends StatelessWidget {
  const _LapTile({required this.number, required this.lap});

  final int number;
  final SwimmingLap lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duration = lap.endTime.difference(lap.startTime);
    return ListTile(
      leading: SizedBox.square(
        dimension: 40,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: scheme.secondaryContainer,
            shape: const ExpressiveShapeBorder(shape: ExpressiveShape.cookie6),
          ),
          child: Center(
            child: Text(
              '$number',
              style: theme.textTheme.labelLargeEmphasized.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ),
      ),
      title: Text(formatEnumName(lap.strokeStyle)),
      // Laps an Apple Watch recorded before watchOS 4 have no duration.
      subtitle: Text(
        duration == Duration.zero
            ? formatTime(lap.startTime, withSeconds: true)
            : '${formatTime(lap.startTime, withSeconds: true)} · ${formatDuration(duration)}',
      ),
    );
  }
}
