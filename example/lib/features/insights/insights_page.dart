/// PLACEHOLDER for the Insights feature, which replaces this file: it only exists so that the app shell
/// compiles and runs while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder page of the Insights destination; the insights feature replaces it.
class InsightsPage extends StatelessWidget {
  /// Creates the placeholder.
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) => const ExpressivePage(
    title: 'Insights',
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.construction,
          title: 'Insights is on its way',
          message: 'Placeholder: the Insights feature replaces this page.',
        ),
      ),
    ],
  );
}
