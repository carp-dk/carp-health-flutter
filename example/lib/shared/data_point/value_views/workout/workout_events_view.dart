/// The events of a workout that HealthKit records: pauses, laps, segments and markers.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/data_point/layout/detail_section.dart';

/// The [WorkoutEvent]s of a workout (`WorkoutHealthValue.workoutEvents`, iOS only), in order: each with
/// an icon for its kind and its time. At most [maxEvents] are listed.
class WorkoutEventsView extends StatelessWidget {
  /// Creates the view of [events].
  const WorkoutEventsView({super.key, required this.events});

  /// The events of the workout.
  final List<WorkoutEvent> events;

  /// The most events listed one by one.
  static const int maxEvents = 50;

  @override
  Widget build(BuildContext context) {
    return DetailSection(
      title: 'Events',
      children: [
        for (final event in events.take(maxEvents))
          ListTile(
            leading: Icon(iconOf(event.type)),
            title: Text(formatEnumName(event.type)),
            subtitle: Text(_timeOf(event)),
          ),
        if (events.length > maxEvents)
          DetailField(label: 'More events', value: '${events.length - maxEvents} not listed'),
      ],
    );
  }

  /// An icon for each kind of event.
  static IconData iconOf(WorkoutEventType type) => switch (type) {
    WorkoutEventType.pause => Icons.pause,
    WorkoutEventType.resume => Icons.play_arrow,
    WorkoutEventType.lap => Icons.flag_outlined,
    WorkoutEventType.marker => Icons.place_outlined,
    WorkoutEventType.motionPaused => Icons.pause_circle_outline,
    WorkoutEventType.motionResumed => Icons.play_circle_outline,
    WorkoutEventType.segment => Icons.linear_scale,
    WorkoutEventType.pauseOrResumeRequest => Icons.touch_app_outlined,
    WorkoutEventType.unknown => Icons.help_outline,
  };

  /// When [event] happened: one time for an instant (pauses, markers), a range for laps and segments.
  static String _timeOf(WorkoutEvent event) {
    final start = formatTime(event.start, withSeconds: true);
    if (!event.end.isAfter(event.start)) return start;
    return '$start – ${formatTime(event.end, withSeconds: true)} · ${formatDuration(event.end.difference(event.start))}';
  }
}
