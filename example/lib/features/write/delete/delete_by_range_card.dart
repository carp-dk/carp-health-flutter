/// The Delete page's form for `Health.delete`: the types and the time range to delete the app's data in.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/time/time_range.dart';
import 'package:health_example/shared/widgets/time_range_selector.dart';
import 'package:health_example/shared/widgets/type_chips.dart';
import 'package:health_example/shared/widgets/type_picker_sheet.dart';

import '../forms/common/form_section.dart';
import 'delete_controller.dart';
import 'delete_range_results.dart';

/// The types (picked from the deletable ones, or the types written in this session) and the range of
/// a `delete` call, the button that confirms and deletes, and the outcome per type
/// ([DeleteRangeResults]). What `delete` removes of sleep and workouts on this platform opens from the
/// types' info button.
class DeleteByRangeCard extends StatelessWidget {
  /// Creates the form of [controller].
  const DeleteByRangeCard({super.key, required this.controller});

  /// The Delete page's state and calls.
  final DeleteController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final written = c.writtenTypes;
    final count = c.types.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Data types',
                parameter: 'type',
                caption: _typesCaption(c.capabilities.isAndroid),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    TypeChips(
                      types: c.types,
                      onEdit: c.isDeleting ? null : () => _pickTypes(context),
                      onRemove: c.isDeleting ? null : (type) => c.types = {...c.types}..remove(type),
                    ),
                    if (written.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.history),
                        label: Text('Written this session (${written.length})'),
                        onPressed: c.isDeleting ? null : () => c.types = written.toSet(),
                      ),
                  ],
                ),
              ),
              FormSection(
                title: 'Time range',
                parameter: 'startTime · endTime',
                caption:
                    'A preset range ends when the delete starts. A range without the app\'s data also counts as '
                    'deleted.',
                child: TimeRangeSelector(
                  value: c.range,
                  onChanged: (range) => c.range = range,
                  presets: const [
                    TimeRangePreset.lastHour,
                    TimeRangePreset.today,
                    TimeRangePreset.last24Hours,
                    TimeRangePreset.last7Days,
                    TimeRangePreset.custom,
                  ],
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: count == 0 || c.isDeleting ? null : () => _confirmAndDelete(context),
          icon: const Icon(Icons.delete_sweep_outlined),
          label: Text(count == 0 ? 'Choose types' : 'Delete ${_types(count)}'),
        ),
        DeleteRangeResults(controller: c),
      ],
    );
  }

  Future<void> _pickTypes(BuildContext context) async {
    final picked = await showTypePicker(
      context,
      available: controller.deletableTypes,
      initial: controller.types,
      title: 'Types to delete',
    );
    if (picked != null) controller.types = picked;
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final c = controller;
    final range = c.range.refreshed();
    final names = c.types.map((type) => type.label).toList()..sort();
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: Text('Delete ${_types(names.length)}?'),
        content: Text('${names.join(', ')}\n${formatTimeRange(range.start, range.end)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await c.deleteInRange();
  }

  static String _types(int count) => count == 1 ? '1 type' : '$count types';

  /// One call per type, and what it removes of sleep and workouts on this platform (README, "Writing a
  /// night of sleep" and "Writing workouts").
  static String _typesCaption(bool isAndroid) => isAndroid
      ? 'One call per type. Any sleep type deletes whole sleep sessions; a workout\'s Distance and Total '
            'calories burned are records of their own.'
      : 'One call per type, each deleting only that type. A night of sleep is In bed plus a type per stage.';
}
