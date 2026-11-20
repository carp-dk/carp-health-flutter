/// The card of Read > Changes that chooses what to follow: the data types and whether this app's own
/// records count.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/type_chips.dart';
import 'package:health_example/shared/widgets/type_picker_sheet.dart';

import '../../widgets/card_title.dart';
import '../changes_controller.dart';

/// The `types` of `getChangesToken`, as chips with a picker of the types this device supports, and the
/// `includeSelf` switch of `getChanges`.
class ChangesTypesCard extends StatelessWidget {
  /// Creates the card of [controller], offering the types of [catalog].
  const ChangesTypesCard({super.key, required this.controller, required this.catalog});

  /// The Changes section's controller.
  final ChangesController controller;

  /// The types this device supports.
  final TypeCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return ExpressiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(
            icon: Icons.category_outlined,
            title: 'Types to follow',
            trailing: PlatformBadge.android(),
          ),
          const SizedBox(height: 14),
          TypeChips(types: controller.types, onEdit: () => _pickTypes(context), onRemove: _remove),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include own writes'),
            value: controller.includeSelf,
            onChanged: (include) => controller.includeSelf = include,
          ),
        ],
      ),
    );
  }

  /// Lets the user choose the types to follow, among those this device supports.
  Future<void> _pickTypes(BuildContext context) async {
    final picked = await showTypePicker(
      context,
      available: catalog.available,
      initial: controller.types,
      title: 'Data types to follow',
    );
    if (picked != null) controller.types = picked;
  }

  void _remove(HealthDataType type) => controller.types = {...controller.types}..remove(type);
}
