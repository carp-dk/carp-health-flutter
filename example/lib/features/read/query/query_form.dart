/// The form of Read > Query: what to read (the data types and the time range), how to read it (the options
/// card) and the Read button.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/time_range_selector.dart';
import 'package:health_example/shared/widgets/type_chips.dart';
import 'package:health_example/shared/widgets/type_picker_sheet.dart';

import '../widgets/adaptive_pair.dart';
import 'query_controller.dart';
import 'query_options.dart';
import 'query_options_card.dart';

/// The query form: a primary card with data types, time range and the Read button above the fold,
/// followed by the collapsible [QueryOptionsCard]. Every change goes to [controller] as new options.
class QueryForm extends StatelessWidget {
  /// Creates the form for [controller].
  const QueryForm({super.key, required this.controller, required this.catalog, required this.settings});

  /// The Query section's controller, which holds the options.
  final QueryController controller;

  /// The types this device supports, offered in the type picker.
  final TypeCatalog catalog;

  /// The plugin settings, for the page size option.
  final PluginSettings settings;

  @override
  Widget build(BuildContext context) {
    final options = controller.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpressiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdaptivePair(
                spacing: 20,
                first: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    const _FieldLabel(icon: Icons.category_outlined, label: 'Data types'),
                    TypeChips(types: options.types, onEdit: () => _pickTypes(context), onRemove: _removeType),
                  ],
                ),
                second: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    const _FieldLabel(icon: Icons.date_range, label: 'Time range'),
                    TimeRangeSelector(
                      value: options.range,
                      onChanged: (range) => controller.options = controller.options.copyWith(range: range),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxButtonWidth),
                  child: _ReadButton(controller: controller),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        QueryOptionsCard(controller: controller, settings: settings),
      ],
    );
  }

  /// The widest the Read button gets.
  static const double maxButtonWidth = 560;

  /// Lets the user choose the types to read, among those this device supports.
  Future<void> _pickTypes(BuildContext context) async {
    final picked = await showTypePicker(
      context,
      available: catalog.available,
      initial: controller.options.types,
      title: 'Data types to read',
    );
    if (picked != null) controller.options = controller.options.copyWith(types: picked);
  }

  void _removeType(HealthDataType type) =>
      controller.options = controller.options.copyWith(types: {...controller.options.types}..remove(type));
}

/// A quiet section label inside the query card.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        Text(label, style: theme.textTheme.labelLargeEmphasized.copyWith(color: scheme.onSurface)),
      ],
    );
  }
}

/// The button that starts the read, naming the read mode; it shows progress while a read runs and says
/// why it is disabled when no type is chosen.
class _ReadButton extends StatelessWidget {
  const _ReadButton({required this.controller});

  final QueryController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = controller.options;
    final reading = controller.isReading;
    const motion = ExpressiveMotion.spatialFast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: controller.canRead ? controller.read : null,
          icon: AnimatedSwitcher(
            duration: motion.duration,
            switchInCurve: motion,
            child: reading
                ? ExpressiveLoadingIndicator(
                    key: const ValueKey('reading'),
                    size: 24,
                    color: scheme.primary,
                    semanticsLabel: 'Reading',
                  )
                : const Icon(Icons.play_arrow_rounded, key: ValueKey('idle')),
          ),
          label: Text(
            reading
                ? 'Reading…'
                : options.mode == QueryMode.pages
                ? 'Read page by page'
                : 'Read all at once',
          ),
        ),
        if (options.types.isEmpty)
          Text(
            'Choose a data type first',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
