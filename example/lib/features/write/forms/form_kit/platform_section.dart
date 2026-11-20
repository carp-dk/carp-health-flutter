/// A write form section for arguments that only one platform stores.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/common/form_section.dart';
import 'package:health_example/shared/scope_lookup.dart';

import 'form_note.dart';

/// A [FormSection] for arguments that only [onlyOn] stores, marked with that platform's `PlatformBadge`.
///
/// On the other platform the fields are replaced by a one-line "Ignored on …" note, so the form shows
/// the difference instead of hiding the fields silently.
class PlatformSection extends StatelessWidget {
  /// Creates a section of [child] that only [onlyOn] uses.
  const PlatformSection({
    super.key,
    required this.title,
    required this.onlyOn,
    required this.note,
    required this.child,
    this.parameter,
    this.caption,
  });

  /// What the fields set, such as "Title".
  final String title;

  /// The plugin arguments, such as `title · notes`.
  final String? parameter;

  /// What the arguments do on [onlyOn], for the info sheet.
  final String? caption;

  /// The platform that stores these arguments.
  final HealthPlatformType onlyOn;

  /// What the other platform does with the arguments, for the info sheet there.
  final String note;

  /// The fields.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final here = healthPlatformOf(context) == onlyOn;
    final ios = onlyOn == HealthPlatformType.appleHealth;
    return FormSection(
      title: title,
      parameter: parameter,
      caption: here ? caption : note,
      trailing: ios ? const PlatformBadge.ios() : const PlatformBadge.android(),
      child: here ? child : FormNote(text: ios ? 'Ignored on Android' : 'Ignored on iOS'),
    );
  }
}
