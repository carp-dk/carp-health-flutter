/// PLACEHOLDER for the Read feature, which replaces this file: it only exists so that the app shell
/// compiles and runs while the features are being written.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Placeholder page of the Read destination; the read feature replaces it.
class ReadPage extends StatelessWidget {
  /// Creates the placeholder.
  const ReadPage({super.key});

  @override
  Widget build(BuildContext context) => const ExpressivePage(
    title: 'Read',
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.construction,
          title: 'Read is on its way',
          message: 'Placeholder: the Read feature replaces this page.',
        ),
      ),
    ],
  );
}
