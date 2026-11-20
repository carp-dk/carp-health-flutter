/// The sections of the workout form that both platforms use: the write method, the activity and the
/// totals.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/common/form_section.dart';
import 'package:health_example/features/write/forms/form_kit/field_pair.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'workout_activities.dart';
import 'workout_activity_icons.dart';
import 'workout_form_controller.dart';

/// The choice between `writeWorkoutData` (returns a bool) and `writeWorkoutDataUUID` (returns the UUID).
class WorkoutMethodSection extends StatelessWidget {
  /// Creates the section for [controller].
  const WorkoutMethodSection({super.key, required this.controller});

  /// The workout form's state.
  final WorkoutFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Method',
      parameter: controller.method.name,
      caption: controller.method.returns,
      child: ConnectedButtonGroup<WorkoutWriteMethod>(
        segments: const [
          ButtonGroupSegment(value: WorkoutWriteMethod.writeWorkoutData, label: 'Bool', icon: Icons.check_circle),
          ButtonGroupSegment(value: WorkoutWriteMethod.writeWorkoutDataUUID, label: 'UUID', icon: Icons.fingerprint),
        ],
        selected: controller.method,
        onSelected: (method) => controller.method = method,
      ),
    );
  }
}

/// The activity: a searchable drop-down of the activities this platform writes, and chips for a few
/// common ones.
class WorkoutActivitySection extends StatelessWidget {
  /// Creates the section for [controller].
  const WorkoutActivitySection({super.key, required this.controller});

  /// The workout form's state.
  final WorkoutFormController controller;

  /// Common activities offered as chips, where the platform writes them.
  static const List<HealthWorkoutActivityType> quickPicks = [
    HealthWorkoutActivityType.RUNNING,
    HealthWorkoutActivityType.WALKING,
    HealthWorkoutActivityType.BIKING,
    HealthWorkoutActivityType.SWIMMING_POOL,
    HealthWorkoutActivityType.YOGA,
    HealthWorkoutActivityType.STRENGTH_TRAINING,
    HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
  ];

  @override
  Widget build(BuildContext context) {
    final activities = controller.activities;
    final missing = HealthWorkoutActivityType.values.length - activities.length;
    return FormSection(
      title: 'Activity',
      parameter: 'activityType',
      caption:
          '${activities.length} activities have a ${controller.capabilities.platformName} workout type; the '
          '$missing others throw notSupported.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          EnumDropdownField<HealthWorkoutActivityType>(
            label: 'Activity',
            value: controller.activity,
            values: activities,
            labelOf: WorkoutActivities.label,
            iconOf: (activity) => activity.icon,
            onChanged: (activity) => controller.activity = activity,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final activity in quickPicks.where(activities.contains))
                ChoiceChip(
                  avatar: Icon(activity.icon),
                  label: Text(WorkoutActivities.label(activity)),
                  selected: controller.activity == activity,
                  onSelected: (_) => controller.activity = activity,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The total distance and energy burned, and what each platform makes of them.
class WorkoutTotalsSection extends StatelessWidget {
  /// Creates the section for [controller].
  const WorkoutTotalsSection({super.key, required this.controller});

  /// The workout form's state.
  final WorkoutFormController controller;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Totals',
      parameter: 'totalDistance · totalEnergyBurned',
      caption: controller.capabilities.isIOS
          ? 'Optional whole numbers, kept on the workout only (not in distance or energy reads).'
          : 'Optional whole numbers, saved as DISTANCE_DELTA and TOTAL_CALORIES_BURNED records, which need '
                'their own write access.',
      child: FieldPair(
        first: NumberField(
          label: 'Distance',
          controller: controller.distance,
          unit: 'm',
          decimal: false,
          isRequired: false,
          onChanged: (_) => controller.textChanged(),
        ),
        second: NumberField(
          label: 'Energy burned',
          controller: controller.energy,
          unit: 'kcal',
          decimal: false,
          isRequired: false,
          onChanged: (_) => controller.textChanged(),
        ),
      ),
    );
  }
}
