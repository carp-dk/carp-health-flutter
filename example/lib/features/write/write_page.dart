/// PLACEHOLDER for the Write feature, which replaces this file: it only exists so that the app shell
/// compiles and runs while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder page of the Write destination; the write feature replaces it.
class WritePage extends StatelessWidget {
  /// Creates the placeholder.
  const WritePage({super.key});

  @override
  Widget build(BuildContext context) => const ExpressivePage(
    title: 'Write',
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.construction,
          title: 'Write is on its way',
          message: 'Placeholder: the Write feature replaces this page.',
        ),
      ),
    ],
  );
}
