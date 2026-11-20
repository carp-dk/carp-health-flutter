/// The Workout route recipe: records a GPS route and attaches it to a workout, with the route builder
/// calls `Health.startWorkoutRoute`, `Health.insertWorkoutRouteData` and `Health.finishWorkoutRoute`, and
/// `Health.discardWorkoutRoute` when a step fails or the recording is cancelled.
///
/// The workout comes from `Health.getHealthDataFromTypes` (the workouts of the last week) or from a
/// sample walk written with `Health.writeWorkoutDataUUID`; the route is the example's sample walk of five
/// locations, timed inside the workout.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/shared/widgets/error_card.dart';
import 'package:health_example/shared/widgets/form_fields.dart';
import 'package:health_example/shared/widgets/write_result.dart';

import 'common/form_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/form_note.dart';
import 'route/route_preview_panel.dart';
import 'route/route_steps_view.dart';
import 'route/workout_picker.dart';
import 'route/workout_route_controller.dart';

/// Attaches the sample route to a chosen workout ([WorkoutRouteController]), showing each route builder
/// call as it runs.
class WorkoutRouteForm extends StatefulWidget {
  /// Creates the form.
  const WorkoutRouteForm({super.key});

  @override
  State<WorkoutRouteForm> createState() => _WorkoutRouteFormState();
}

class _WorkoutRouteFormState extends WriteFormState<WorkoutRouteForm, WorkoutRouteController> {
  @override
  WorkoutRouteController createController(AppServices services) =>
      WorkoutRouteController(services.health, recentWrites: services.recentWrites);

  @override
  void initState() {
    super.initState();
    // The controller reads the workouts; the form only starts it.
    controller.loadWorkouts();
  }

  /// Writes the sample walk and reports it as every write is reported (a snack bar and a recent write).
  Future<void> _writeSampleWorkout() async {
    final result = await controller.writeSampleWorkout();
    if (!mounted) return;
    switch (result) {
      case AsyncData(value: final outcome):
        await reportWriteResult(
          context,
          type: outcome.type,
          description: outcome.description,
          success: outcome.success,
          uuid: outcome.uuid,
        );
      case AsyncError(:final error):
        await reportWriteResult(
          context,
          type: controller.type,
          description: 'Sample walk',
          success: false,
          error: error,
        );
      case AsyncIdle() || AsyncLoading():
        break;
    }
  }

  @override
  Widget buildFields(BuildContext context) {
    final android = AppScope.of(context).capabilities.isAndroid;
    final selected = controller.selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Workout',
                parameter: 'workoutUuid',
                caption: android
                    ? "Only workouts this app wrote take a route. finishWorkoutRoute returns the workout's UUID."
                    : "HealthKit links a route of its own to the workout. finishWorkoutRoute returns the route's UUID.",
                child: WorkoutPicker(controller: controller, onWriteSample: _writeSampleWorkout),
              ),
              FormSection(
                title: 'Route',
                parameter: 'locations: List<WorkoutRouteLocation>',
                caption: 'A sample walk spread over the workout, sent in time order with insertWorkoutRouteData.',
                child: RoutePreviewPanel(locations: controller.locations),
              ),
            ],
          ),
        ),
        if (selected == null)
          const FormNote(icon: Icons.touch_app_outlined, text: 'Choose a workout first')
        else
          WriteButton(label: 'Write route', icon: Icons.route, onPressed: write),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: controller.isBusy ? null : controller.startAndDiscard,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Start and discard'),
          ),
        ),
        RouteStepsView(steps: controller.steps),
        if (controller.discarded case AsyncError(:final error))
          ErrorCard(error: error, onRetry: controller.startAndDiscard),
        WriteOutcomeView(controller: controller, onRetry: write),
      ],
    );
  }
}
