/// The sheet listing this week's workouts, which the overview's workouts tile opens.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';
import 'package:health_example/shared/data_point/data_point_tile.dart';

import '../model/workout_week.dart';

/// Shows [week]'s workouts in a modal bottom sheet ([WorkoutsSheet]).
Future<void> showWorkoutsSheet(BuildContext context, WorkoutWeek week) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => WorkoutsSheet(week: week),
);

/// The workouts `getHealthDataFromTypes` read for `WORKOUT` since Monday, newest first, with an info
/// button naming the call; tapping one opens its data point sheet with its totals, laps and events.
class WorkoutsSheet extends StatelessWidget {
  /// Creates the sheet of [week]'s workouts.
  const WorkoutsSheet({super.key, required this.week});

  /// The workouts to list.
  final WorkoutWeek week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 1,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32 + bottomInset),
        children: [
          Row(
            spacing: 16,
            children: [
              ShapedIcon(icon: Icons.fitness_center, shape: ExpressiveShape.softBurst, size: 56),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workouts', style: theme.textTheme.headlineSmallEmphasized),
                    Text(
                      '${formatNumber(week.count)} this week · ${formatDuration(week.totalDuration)}',
                      style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedList(
            children: [
              for (final workout in week.workouts)
                DataPointTile(point: workout, showType: false, onTap: () => showDataPointSheet(context, workout)),
            ],
          ),
        ],
      ),
    );
  }
}
