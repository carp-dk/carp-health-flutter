/// The data type a measurement is written as, picked from the types `writeHealthData` writes.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';
import 'package:health_example/shared/visuals/type_icon.dart';
import 'package:health_example/shared/widgets/type_picker_sheet.dart';

/// Shows [type] (its icon in its category's shape, its name, its `HealthDataType` name and default unit)
/// and, when tapped, the type picker over [types], reporting the pick through [onChanged].
class MeasurementTypeField extends StatelessWidget {
  /// Creates the field showing [type].
  const MeasurementTypeField({super.key, required this.type, required this.types, required this.onChanged});

  /// The selected type.
  final HealthDataType type;

  /// The types offered: `TypeCatalog.writableTypes`.
  final List<HealthDataType> types;

  /// Called with the type the user picked.
  final ValueChanged<HealthDataType> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTypePicker(
      context,
      available: types,
      initial: {type},
      multiple: false,
      title: 'Choose a type to write',
    );
    if (picked != null && picked.isNotEmpty) onChanged(picked.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = formatUnit(type.defaultUnit);
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: ExpressiveShapes.rounded(ExpressiveShapes.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            spacing: 16,
            children: [
              TypeIcon(type: type, size: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(type.label, style: theme.textTheme.titleMediumEmphasized),
                    Text(
                      unit.isEmpty ? type.name : '${type.name} · $unit',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant).monospace,
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
