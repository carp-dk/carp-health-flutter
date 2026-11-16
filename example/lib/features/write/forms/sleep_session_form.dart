/// PLACEHOLDER for the sleep session write form, which the Write feature replaces: it only exists so that the
/// app compiles while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder of the form that writes a sleep session (`writeSleepSession`); the Write feature replaces it.
class SleepSessionForm extends StatelessWidget {
  /// Creates the placeholder.
  const SleepSessionForm({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.construction,
    title: 'Sleep session form',
    message: 'Placeholder: the Write feature replaces this form.',
  );
}
