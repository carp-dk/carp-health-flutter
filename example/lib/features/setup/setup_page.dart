/// PLACEHOLDER for the Setup feature, which replaces this file: it only exists so that the app shell
/// compiles and runs while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder page of the Setup destination; the setup feature replaces it.
class SetupPage extends StatelessWidget {
  /// Creates the placeholder.
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) => const ExpressivePage(
    title: 'Setup',
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.construction,
          title: 'Setup is on its way',
          message: 'Placeholder: the Setup feature replaces this page.',
        ),
      ),
    ],
  );
}
