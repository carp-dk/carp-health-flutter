/// A text field for a number, as the write forms use for values, totals and amounts.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A filled text field that accepts a number (with a decimal point or comma when [decimal], and a
/// minus sign when [signed]), shows its [unit] after the text and validates it in a `Form`.
///
/// Read the value with [NumberField.parse] (`NumberField.parse(controller.text)`), which also takes a
/// decimal comma, as many keyboards type one.
class NumberField extends StatelessWidget {
  /// Creates a number field for the text in [controller].
  const NumberField({
    super.key,
    required this.label,
    required this.controller,
    this.unit,
    this.decimal = true,
    this.signed = false,
    this.isRequired = true,
    this.helperText,
    this.onChanged,
  });

  /// What the number is, such as "Heart rate".
  final String label;

  /// Holds the text of the number.
  final TextEditingController controller;

  /// The unit symbol shown after the number, such as "bpm".
  final String? unit;

  /// Whether the number may have decimals.
  final bool decimal;

  /// Whether the number may be negative, as a skin temperature change can be.
  final bool signed;

  /// Whether an empty field is invalid; optional numbers (such as a workout's distance) leave it false.
  final bool isRequired;

  /// A line under the field, such as the range the plugin accepts.
  final String? helperText;

  /// Called with the text whenever it changes.
  final ValueChanged<String>? onChanged;

  /// The number in [text], or null when it is empty or not a number. A decimal comma counts as a point.
  static num? parse(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty || normalized == '-' || normalized == '.') return null;
    return num.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal, signed: signed),
      inputFormatters: [_NumberInputFormatter(decimal: decimal, signed: signed)],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, suffixText: unit, helperText: helperText),
      validator: _validate,
    );
  }

  String? _validate(String? text) {
    if (text == null || text.trim().isEmpty) return isRequired ? 'Enter a value' : null;
    return parse(text) == null ? 'Enter a number' : null;
  }
}

/// Keeps only edits that leave a number being typed: digits, at most one decimal separator (when
/// decimal) and a leading minus sign (when signed). Any other edit is ignored.
class _NumberInputFormatter extends TextInputFormatter {
  _NumberInputFormatter({required bool decimal, required bool signed})
    : _pattern = RegExp('^${signed ? '-?' : ''}\\d*${decimal ? r'([.,]\d*)?' : ''}\$');

  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      _pattern.hasMatch(newValue.text) ? newValue : oldValue;
}
