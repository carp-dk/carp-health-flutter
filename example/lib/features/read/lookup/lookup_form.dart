/// The form of Read > Lookup: the type and the UUID of the record to read.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';
import 'package:health_example/shared/widgets/form_fields/enum_dropdown_field.dart';

import '../widgets/card_title.dart';
import 'lookup_controller.dart';

/// A card with the `type` drop-down (filtered by typing), the `uuid` field (with paste and clear) and the
/// Look up button, which runs `getHealthDataByUUID` through [controller]. The info button names the call and
/// why the type matters.
class LookupForm extends StatelessWidget {
  /// Creates the form of [controller].
  const LookupForm({super.key, required this.controller});

  /// The Lookup section's controller.
  final LookupController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = controller.result.isLoading;
    const motion = ExpressiveMotion.spatialFast;
    // Outlined, on the surface colour: the filled text fields have the filled card's colour.
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(icon: Icons.fingerprint, shape: ExpressiveShape.cookie12, title: 'Record by UUID'),
          const SizedBox(height: 16),
          EnumDropdownField<HealthDataType>(
            // A new key when the type changes from outside (a recent write), so the field shows it.
            key: ValueKey(controller.type),
            label: 'Data type',
            value: controller.type,
            values: controller.types,
            labelOf: (type) => type.label,
            iconOf: (type) => type.icon,
            onChanged: (type) => controller.type = type,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.uuidField,
            style: theme.textTheme.bodyLarge!.monospace,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => controller.lookUp(),
            decoration: InputDecoration(
              labelText: 'UUID',
              hintText: 'E9F2EEAD-8FC5-4CE5-9FF5-7C4E535FB8B8',
              prefixIcon: const Icon(Icons.tag),
              suffixIcon: controller.uuid.isEmpty
                  ? IconButton(tooltip: 'Paste', onPressed: _paste, icon: const Icon(Icons.content_paste))
                  : IconButton(tooltip: 'Clear', onPressed: controller.uuidField.clear, icon: const Icon(Icons.clear)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: controller.canLookUp ? controller.lookUp : null,
            icon: AnimatedSwitcher(
              duration: motion.duration,
              switchInCurve: motion,
              child: busy
                  ? ExpressiveLoadingIndicator(
                      key: const ValueKey('busy'),
                      size: 24,
                      color: theme.colorScheme.primary,
                      semanticsLabel: 'Looking up',
                    )
                  : const Icon(Icons.search, key: ValueKey('idle')),
            ),
            label: Text(busy ? 'Looking up…' : 'Look up'),
          ),
        ],
      ),
    );
  }

  /// Puts the clipboard's text, such as a UUID copied from the data point sheet, into the field.
  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) controller.uuidField.text = text;
    } on PlatformException {
      // No clipboard access: the user can still type the UUID.
    }
  }
}
