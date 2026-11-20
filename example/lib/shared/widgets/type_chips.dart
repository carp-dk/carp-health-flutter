/// The data types a read, a permission request or a delete is about, as removable chips.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';

/// The [types] as input chips, each with the type's icon, sorted by category and then name.
///
/// With [onRemove] each chip has a remove button. With [onEdit] tapping a chip, or the trailing
/// "Choose data types" / "Edit" chip, edits the selection (usually with `showTypePicker`). Beyond
/// [maxVisible] types the rest collapse into a "+N more" chip, so selecting a whole category or every
/// type keeps the form short.
class TypeChips extends StatelessWidget {
  /// Creates chips for [types].
  const TypeChips({super.key, required this.types, this.onEdit, this.onRemove, this.maxVisible = 12});

  /// The selected types.
  final Set<HealthDataType> types;

  /// Edits the selection; null hides the edit chip.
  final VoidCallback? onEdit;

  /// Removes one type; null hides the remove buttons.
  final ValueChanged<HealthDataType>? onRemove;

  /// The most chips shown before the rest collapse into a count.
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = types.toList()
      ..sort((a, b) {
        final byCategory = a.category.index.compareTo(b.category.index);
        return byCategory != 0 ? byCategory : a.label.compareTo(b.label);
      });
    final hidden = sorted.length - maxVisible;
    final edit = onEdit;
    final remove = onRemove;
    if (sorted.isEmpty && edit == null) {
      return Text(
        'No data types',
        style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in sorted.take(maxVisible))
          InputChip(
            // A chip's avatar is as tall as its label (18 dp), too small for a shaped icon.
            avatar: Icon(type.icon),
            label: Text(type.label),
            onPressed: edit,
            onDeleted: remove == null ? null : () => remove(type),
            deleteButtonTooltipMessage: 'Remove ${type.label}',
          ),
        if (hidden > 0) ActionChip(label: Text('+$hidden more'), onPressed: edit),
        if (edit != null)
          ActionChip(
            avatar: Icon(sorted.isEmpty ? Icons.add : Icons.edit_outlined),
            label: Text(sorted.isEmpty ? 'Choose data types' : 'Edit'),
            onPressed: edit,
          ),
      ],
    );
  }
}
