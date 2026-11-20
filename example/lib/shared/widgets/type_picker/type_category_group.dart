/// One category in the type picker: a header with a select-all checkbox, over the category's types in
/// a segmented list.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import 'type_picker_model.dart';

/// The [category]'s types as [model] shows them: a header with the category's icon and name and, when
/// several types can be picked, how many of its types are selected and a tristate checkbox that selects
/// or deselects them all; then a row per type. Tapping a row calls [onPick].
class TypeCategoryGroup extends StatelessWidget {
  /// Creates the group of [types] of [category].
  const TypeCategoryGroup({
    super.key,
    required this.category,
    required this.types,
    required this.model,
    required this.onPick,
  });

  /// The category.
  final TypeCategory category;

  /// The category's types that match the search.
  final List<HealthDataType> types;

  /// The picker's state.
  final TypePickerModel model;

  /// Called with the type the user tapped.
  final ValueChanged<HealthDataType> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = types.where(model.isSelected).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
          child: Row(
            spacing: 12,
            children: [
              TypeIcon.category(category: category, size: 36),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(category.label, style: theme.textTheme.titleMediumEmphasized)),
                    if (model.multiple)
                      Text(
                        '$count of ${types.length} selected',
                        style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (model.multiple)
                Checkbox(
                  tristate: true,
                  value: model.categoryState(category),
                  semanticLabel: 'Select all ${category.label}',
                  // A tristate checkbox would go from all to none to some; the model goes to all or none.
                  onChanged: (_) => model.toggleCategory(category),
                ),
            ],
          ),
        ),
        SegmentedList(
          children: [for (final type in types) _TypeRow(type: type, model: model, onPick: onPick)],
        ),
      ],
    );
  }
}

/// A type: its icon and name, and whether it is selected. The code name (such as `HEART_RATE`) is left
/// out to keep the list calm; the search finds types by it.
class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.model, required this.onPick});

  final HealthDataType type;
  final TypePickerModel model;
  final ValueChanged<HealthDataType> onPick;

  @override
  Widget build(BuildContext context) {
    final selected = model.isSelected(type);
    return ListTile(
      leading: TypeIcon(type: type, size: 36),
      title: Text(type.label),
      selected: selected,
      trailing: model.multiple
          ? Checkbox(value: selected, onChanged: (_) => onPick(type))
          : (selected ? const Icon(Icons.check_circle) : null),
      onTap: () => onPick(type),
    );
  }
}
