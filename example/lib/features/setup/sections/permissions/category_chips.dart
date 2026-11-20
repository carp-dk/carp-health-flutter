/// The row of categories to choose a permission scope from.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/health/type_category.dart';

/// A horizontally scrolling row of choice chips, one per category in [categories], with [selected]
/// chosen; [onSelected] reports the category tapped. All chips are disabled while not [enabled].
class CategoryChips extends StatelessWidget {
  /// Creates the row.
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  /// The categories to offer, in catalog order.
  final List<TypeCategory> categories;

  /// The chosen category, if any.
  final TypeCategory? selected;

  /// Called with the category the user chose.
  final ValueChanged<TypeCategory> onSelected;

  /// Whether the chips can be chosen.
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final category = categories[index];
        return Center(
          child: ChoiceChip(
            avatar: Icon(category.icon),
            label: Text(category.label),
            selected: category == selected,
            onSelected: enabled ? (_) => onSelected(category) : null,
          ),
        );
      },
    ),
  );
}
