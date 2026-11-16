/// Picks the time range a read, an interval query or a delete covers: a preset ending now, or a custom
/// range of whole days from the date range picker.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/time/time_range.dart';

/// Choice chips for the [presets] and, under them, the exact range [value] covers and how long it is.
///
/// A preset chip reports `TimeRange.preset` through [onChanged]; tapping the selected one again
/// reports it anew, ending now. The Custom chip opens the date range picker and reports the picked
/// days in full, from midnight of the first day to the end of the last ([customRange]).
///
/// Preset ranges end when they are made: controllers call `TimeRange.refreshed` before each read, so
/// "Last hour" still means the last hour later on.
class TimeRangeSelector extends StatelessWidget {
  /// Creates a selector showing [value].
  const TimeRangeSelector({super.key, required this.value, required this.onChanged, this.presets = defaultPresets});

  /// The selected range.
  final TimeRange value;

  /// Called with the range the user chose.
  final ValueChanged<TimeRange> onChanged;

  /// The chips offered, in order.
  final List<TimeRangePreset> presets;

  /// Every preset, custom included.
  static const List<TimeRangePreset> defaultPresets = TimeRangePreset.values;

  /// The custom range of the whole days from [firstDay] to [lastDay] (both included), as picked in a
  /// date range picker, which gives both days at midnight.
  static TimeRange customRange(DateTime firstDay, DateTime lastDay) => TimeRange.custom(
    DateTime(firstDay.year, firstDay.month, firstDay.day),
    // The last millisecond of the last day; DateTime's calendar arithmetic is right across DST changes.
    DateTime(lastDay.year, lastDay.month, lastDay.day + 1).subtract(const Duration(milliseconds: 1)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in presets)
              ChoiceChip(
                avatar: preset == TimeRangePreset.custom ? const Icon(Icons.date_range) : null,
                label: Text(preset.label),
                selected: value.preset == preset,
                // Called on every tap, also of the selected chip: re-choosing a preset ends it now.
                onSelected: (_) =>
                    preset == TimeRangePreset.custom ? _pickCustom(context) : onChanged(TimeRange.preset(preset)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            Icon(Icons.schedule, size: 18, color: scheme.onSurfaceVariant),
            Expanded(
              child: Text(
                '${formatTimeRange(value.start, value.end)} · ${formatDuration(value.duration)}',
                style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Asks for a range of days, starting from the days [value] covers, and reports it.
  Future<void> _pickCustom(BuildContext context) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = DateTime(today.year - 10, today.month, today.day);
    // The picker asserts that its initial range lies between its first and last date.
    DateTime clamp(DateTime day) => day.isBefore(first) ? first : (day.isAfter(today) ? today : day);
    final start = clamp(DateUtils.dateOnly(value.start));
    final end = clamp(DateUtils.dateOnly(value.end));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: today,
      initialDateRange: DateTimeRange(start: start, end: end.isBefore(start) ? start : end),
      helpText: 'Choose the days to cover',
      saveText: 'Use',
    );
    if (picked != null) onChanged(customRange(picked.start, picked.end));
  }
}
