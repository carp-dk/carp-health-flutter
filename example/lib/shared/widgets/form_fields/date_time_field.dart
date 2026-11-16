/// A field for a date and time, as the write forms use for the start and end of what they write.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';

/// A filled field showing [value] (such as "Today, 07:05") that, when tapped, asks for a date with the
/// date picker and then for a time with the time picker, and reports the result with [onChanged].
///
/// Cancelling the date picker changes nothing; cancelling the time picker keeps the time of [value] on
/// the new date. Dates are offered from [firstDate] to [lastDate].
class DateTimeField extends StatelessWidget {
  /// Creates a field for the date and time [value].
  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  /// What the date is, such as "Start".
  final String label;

  /// The date and time shown.
  final DateTime value;

  /// Called with the date and time the user picked.
  final ValueChanged<DateTime> onChanged;

  /// The earliest date offered; 1 January 2000 by default.
  final DateTime? firstDate;

  /// The latest date offered; a year from now by default.
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final text = formatDateTime(value);
    return Semantics(
      button: true,
      label: '$label: $text',
      excludeSemantics: true,
      child: Stack(
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.event),
              suffixIcon: const Icon(Icons.edit_calendar_outlined),
            ),
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          // Ink is painted on the nearest Material, under the field's opaque fill, where it would not
          // show: the ripple gets a transparent Material of its own on top, in the field's shape.
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: ExpressiveShapes.radius(ExpressiveShapes.large),
                onTap: () => _pick(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final first = firstDate ?? DateTime(2000);
    final last = lastDate ?? DateTime.now().add(const Duration(days: 365));
    // The pickers assert that the initial date lies in their range.
    final initial = value.isBefore(first) ? first : (value.isAfter(last) ? last : value);
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
    final picked = time ?? TimeOfDay.fromDateTime(value);
    onChanged(DateTime(date.year, date.month, date.day, picked.hour, picked.minute));
  }
}
