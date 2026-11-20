/// The Workout recipe: writes a workout with `Health.writeWorkoutData`, or with
/// `Health.writeWorkoutDataUUID`, which also returns the new workout's UUID.
///
/// The form shows every argument of the two methods: the activity (only the activities this platform has
/// a workout type for), start and end, total distance and energy, the Health Connect title (Android), the
/// HealthKit `WorkoutMetadata` (iOS), the recording method, the client record id (Android) and, for a
/// swim, the `SwimmingDetails` with a lap editor and the pool length, and the stroke count (iOS).
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/time_span_fields.dart';
import 'workout/swimming_section.dart';
import 'workout/workout_activity_icons.dart';
import 'workout/workout_form_controller.dart';
import 'workout/workout_platform_sections.dart';
import 'workout/workout_sections.dart';

/// Writes a workout ([WorkoutFormController]): a 30-minute run by default. A written workout with a UUID
/// shows up in the Workout route form, which attaches a route to it.
class WorkoutForm extends StatefulWidget {
  /// Creates the form.
  const WorkoutForm({super.key});

  @override
  State<WorkoutForm> createState() => _WorkoutFormState();
}

class _WorkoutFormState extends WriteFormState<WorkoutForm, WorkoutFormController> {
  @override
  WorkoutFormController createController(AppServices services) =>
      WorkoutFormController(services.health, capabilities: services.capabilities);

  @override
  Widget buildFields(BuildContext context) {
    const motion = ExpressiveMotion.spatialDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              WorkoutActivitySection(controller: controller),
              FormSection(
                title: 'Time',
                parameter: 'start · end',
                caption: 'The laps of a swim must lie inside this time.',
                child: TimeSpanFields(start: controller.start, end: controller.end, onChanged: controller.setTimes),
              ),
              WorkoutTotalsSection(controller: controller),
              WorkoutTitleSection(controller: controller),
              WorkoutMetadataSection(controller: controller),
              RecordingMethodSection(options: controller),
              ClientRecordIdSection(options: controller),
              WorkoutMethodSection(controller: controller),
            ],
          ),
        ),
        // The swimming details appear, springing open, when the activity is a swim.
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: controller.isSwim
              ? FormCard(child: SwimmingSection(controller: controller))
              : const SizedBox(width: double.infinity),
        ),
        WriteButton(label: 'Write workout', icon: controller.activity.icon, onPressed: write),
        WriteOutcomeView(controller: controller, onRetry: write),
      ],
    );
  }
}
