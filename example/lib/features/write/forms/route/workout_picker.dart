/// The list of workouts the Workout route form can attach its route to.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/form_kit/form_note.dart';
import 'package:health_example/features/write/forms/workout/workout_activity_icons.dart';
import 'package:health_example/shared/widgets/async_value_view.dart';

import 'route_workout.dart';
import 'workout_route_controller.dart';

/// The workouts of [controller] ([WorkoutRouteController.loadWorkouts]) as a segmented list to choose
/// one from, with buttons to read them again and to write a sample walk ([onWriteSample]).
///
/// The read shows the expressive loading indicator while it runs and an `ErrorCard` (with "Try again")
/// when it fails, as every plugin call of the app does.
class WorkoutPicker extends StatelessWidget {
  /// Creates the picker for [controller].
  const WorkoutPicker({super.key, required this.controller, required this.onWriteSample});

  /// The form's state.
  final WorkoutRouteController controller;

  /// Writes a sample workout and reports it.
  final VoidCallback onWriteSample;

  @override
  Widget build(BuildContext context) {
    final writingSample = controller.sampleWorkout.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        AsyncValueView<List<RouteWorkout>>(
          value: controller.workouts,
          loadingLabel: 'Reading workouts…',
          onRetry: controller.loadWorkouts,
          data: (context, workouts) => workouts.isEmpty
              ? FormNote(
                  icon: Icons.search_off,
                  text: 'No workouts in the last ${WorkoutRouteController.lookBack.inDays} days',
                )
              : SegmentedList(
                  children: [
                    for (final workout in workouts)
                      _WorkoutTile(
                        workout: workout,
                        selected: workout == controller.selected,
                        onTap: () => controller.select(workout),
                      ),
                  ],
                ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: writingSample ? null : onWriteSample,
              icon: writingSample
                  ? const ExpressiveLoadingIndicator(size: 20, semanticsLabel: 'Writing a sample walk')
                  : const Icon(Icons.directions_walk),
              label: const Text('Sample walk'),
            ),
            OutlinedButton.icon(
              onPressed: controller.workouts.isLoading ? null : controller.loadWorkouts,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
        ),
      ],
    );
  }
}

/// One workout: its activity in its shape, its time and who wrote it; the chosen one is marked.
class _WorkoutTile extends StatelessWidget {
  const _WorkoutTile({required this.workout, required this.selected, required this.onTap});

  final RouteWorkout workout;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final source = workout.sourceName.isEmpty ? 'Unknown source' : workout.sourceName;
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: ShapedIcon(
        icon: workout.activity?.icon ?? Icons.fitness_center,
        shape: selected ? ExpressiveShape.softBurst : ExpressiveShape.circle,
        size: 40,
        background: selected ? scheme.primary : scheme.secondaryContainer,
        foreground: selected ? scheme.onPrimary : scheme.onSecondaryContainer,
      ),
      title: Text(workout.label),
      subtitle: Text('${workout.time}\n$source', maxLines: 2, overflow: TextOverflow.ellipsis),
      isThreeLine: true,
      trailing: workout.writtenHere
          ? const StatusPill(label: 'This app', tone: StatusTone.success)
          : (selected ? Icon(Icons.check_circle, color: scheme.primary) : null),
    );
  }
}
