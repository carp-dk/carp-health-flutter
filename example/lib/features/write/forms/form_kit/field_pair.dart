/// Two form fields side by side on wide windows, one above the other on phones.
library;

import 'package:flutter/material.dart';

/// Two fields side by side when there is room ([minWidth] for the pair), else one above the other: start
/// and end, distance and energy, an id and its version.
class FieldPair extends StatelessWidget {
  /// Creates a pair of [first] and [second].
  const FieldPair({super.key, required this.first, required this.second, this.minWidth = 420});

  /// The field at the start (or on top).
  final Widget first;

  /// The field at the end (or below).
  final Widget second;

  /// The narrowest width at which the fields sit side by side.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minWidth) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [first, second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(child: first),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}
