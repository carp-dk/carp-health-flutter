/// A drop-down field for one of a fixed set of values, such as a workout's activity type or a meal type.
library;

import 'package:flutter/material.dart';

/// A Material 3 drop-down menu (`DropdownMenu`) that fills the width it is given and shows [value]
/// among [values], each named by [labelOf].
///
/// Long lists (more than [searchThreshold] values, such as the plugin's workout activity types) can be
/// filtered by typing. [iconOf] adds an icon before each entry.
class EnumDropdownField<T> extends StatelessWidget {
  /// Creates a drop-down for [value].
  const EnumDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.helperText,
  });

  /// What the value is, such as "Activity".
  final String label;

  /// The selected value.
  final T value;

  /// The values to choose from, in the order shown.
  final List<T> values;

  /// The display name of a value.
  final String Function(T value) labelOf;

  /// Called with the value the user picked.
  final ValueChanged<T> onChanged;

  /// An icon for each entry.
  final IconData Function(T value)? iconOf;

  /// A line under the field.
  final String? helperText;

  /// Above this many values, typing in the field filters the menu.
  static const int searchThreshold = 12;

  @override
  Widget build(BuildContext context) {
    final searchable = values.length > searchThreshold;
    return DropdownMenu<T>(
      initialSelection: value,
      label: Text(label),
      helperText: helperText,
      leadingIcon: iconOf == null ? null : Icon(iconOf!(value)),
      expandedInsets: EdgeInsets.zero,
      menuHeight: 360,
      enableFilter: searchable,
      requestFocusOnTap: searchable,
      dropdownMenuEntries: [
        for (final entry in values)
          DropdownMenuEntry<T>(
            value: entry,
            label: labelOf(entry),
            leadingIcon: iconOf == null ? null : Icon(iconOf!(entry)),
          ),
      ],
      onSelected: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}
