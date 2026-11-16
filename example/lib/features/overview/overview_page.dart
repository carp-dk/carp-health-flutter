/// PLACEHOLDER for the Overview feature, which replaces this file: it only exists so that the app shell
/// compiles and runs while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder page of the Overview destination; the overview feature replaces it.
class OverviewPage extends StatelessWidget {
  /// Creates the placeholder.
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) => const ExpressivePage(
    title: 'Overview',
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.construction,
          title: 'Overview is on its way',
          message: 'Placeholder: the Overview feature replaces this page.',
        ),
      ),
    ],
  );
}
