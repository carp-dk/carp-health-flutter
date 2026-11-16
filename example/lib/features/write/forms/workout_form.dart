/// PLACEHOLDER for the workout write form, which the Write feature replaces: it only exists so that the
/// app compiles while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder of the form that writes a workout (`writeWorkoutData`); the Write feature replaces it.
class WorkoutForm extends StatelessWidget {
  /// Creates the placeholder.
  const WorkoutForm({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.construction,
    title: 'Workout form',
    message: 'Placeholder: the Write feature replaces this form.',
  );
}
