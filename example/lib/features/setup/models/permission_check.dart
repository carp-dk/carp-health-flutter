/// The answer of `hasPermissions` for a group of data types, and how the Setup page words it on each
/// platform.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// What `hasPermissions` returned, which is a `bool?`.
enum PermissionAnswer {
  /// `true`: every type has the access asked about.
  granted,

  /// `false`: at least one type lacks it. Health Connect answers true only when all of them have it, so
  /// one type at a time tells which are missing.
  denied,

  /// `null`: the platform does not tell. HealthKit never discloses read access, so on iOS this is the
  /// answer for `READ` and `READ_WRITE`.
  unknown;

  /// The answer for the plugin's result.
  static PermissionAnswer fromResult(bool? result) => switch (result) {
    true => granted,
    false => denied,
    null => unknown,
  };
}

/// The outcome of checking one category or one data type with `hasPermissions`.
@immutable
class PermissionCheck {
  /// Creates the outcome of a check.
  const PermissionCheck({required this.answer, this.write});

  /// The answer for the access the user chose (as `PermissionPlan` lowered it).
  final PermissionAnswer answer;

  /// iOS only: the answer for `WRITE` access to the types that can be written, which HealthKit does
  /// disclose; null where it was not checked.
  final PermissionAnswer? write;

  /// How the page shows this outcome, for a group of types when [isGroup] (a category) or for one type.
  PermissionCheckView describe({required bool isGroup}) {
    // On iOS the write answer is the informative one: HealthKit keeps read access to itself.
    if (write case final write?) {
      return switch (write) {
        PermissionAnswer.granted => const PermissionCheckView(
          label: 'Write granted',
          tone: StatusTone.success,
          icon: Icons.edit,
          note: 'Read access is not disclosed by HealthKit',
        ),
        PermissionAnswer.denied => PermissionCheckView(
          label: isGroup ? 'Write not all granted' : 'Write not granted',
          tone: StatusTone.warning,
          icon: Icons.edit_off,
          note: 'Read access is not disclosed by HealthKit',
        ),
        PermissionAnswer.unknown => _unknown,
      };
    }
    return switch (answer) {
      PermissionAnswer.granted => const PermissionCheckView(
        label: 'Granted',
        tone: StatusTone.success,
        icon: Icons.check_circle,
      ),
      PermissionAnswer.denied => PermissionCheckView(
        label: isGroup ? 'Not all granted' : 'Not granted',
        tone: StatusTone.error,
        icon: Icons.block,
        note: isGroup ? 'Open the category to see which types are missing' : null,
      ),
      PermissionAnswer.unknown => _unknown,
    };
  }

  static const PermissionCheckView _unknown = PermissionCheckView(
    label: 'Unknown',
    tone: StatusTone.neutral,
    icon: Icons.help_outline,
    note: 'HealthKit does not tell apps whether read access was granted',
  );

  @override
  bool operator ==(Object other) => other is PermissionCheck && other.answer == answer && other.write == write;

  @override
  int get hashCode => Object.hash(answer, write);

  @override
  String toString() => 'PermissionCheck($answer, write: $write)';
}

/// The words, tone and icon of a [PermissionCheck] on the page.
@immutable
class PermissionCheckView {
  /// Creates the view of a check.
  const PermissionCheckView({required this.label, required this.tone, required this.icon, this.note});

  /// The status in a few words, for a `StatusPill`.
  final String label;

  /// How the status reads.
  final StatusTone tone;

  /// An icon for the status.
  final IconData icon;

  /// A sentence that explains the status, if it needs one.
  final String? note;
}
