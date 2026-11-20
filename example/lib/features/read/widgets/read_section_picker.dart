/// The connected button group that switches the Read page between Query, Lookup and Changes.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import '../read_section.dart';

/// A [ConnectedButtonGroup] of the [ReadSection]s, capped at [maxGroupWidth] on tablets.
class ReadSectionPicker extends StatelessWidget {
  /// Creates the picker showing [selected].
  const ReadSectionPicker({super.key, required this.selected, required this.onSelected});

  /// The section shown.
  final ReadSection selected;

  /// Called with the section the user chose.
  final ValueChanged<ReadSection> onSelected;

  /// The widest the button group gets, so that its segments stay button-sized on tablets.
  static const double maxGroupWidth = 560;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxGroupWidth),
        child: ConnectedButtonGroup<ReadSection>(
          segments: [
            for (final section in ReadSection.values)
              ButtonGroupSegment(value: section, label: section.label, icon: section.icon),
          ],
          selected: selected,
          onSelected: onSelected,
        ),
      ),
    );
  }
}
