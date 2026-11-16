/// PLACEHOLDER for the mindfulness session write form, which the Write feature replaces: it only exists so that the
/// app compiles while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder of the form that writes a mindfulness session (`writeMindfulnessSession`); the Write feature replaces it.
class MindfulnessForm extends StatelessWidget {
  /// Creates the placeholder.
  const MindfulnessForm({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.construction,
    title: 'Mindfulness session form',
    message: 'Placeholder: the Write feature replaces this form.',
  );
}
