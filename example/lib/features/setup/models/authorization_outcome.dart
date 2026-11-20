/// What the result of `requestAuthorization` means, which differs between the platforms (README,
/// "Usage" and "Authorization on iOS").
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// The words, tone and icon the Setup page shows for the `bool` that `requestAuthorization` returned.
@immutable
class AuthorizationOutcome {
  /// Creates an outcome.
  const AuthorizationOutcome({required this.label, required this.tone, required this.icon, required this.explanation});

  /// Describes [result], as returned on iOS ([isIOS]) or on Android.
  factory AuthorizationOutcome.of(bool result, {required bool isIOS}) => switch ((result, isIOS)) {
    (true, false) => const AuthorizationOutcome(
      label: 'At least one granted',
      tone: StatusTone.success,
      icon: Icons.verified_user,
      explanation: 'At least one permission is granted, maybe from before. The check below tells which.',
    ),
    (false, false) => const AuthorizationOutcome(
      label: 'None granted',
      tone: StatusTone.warning,
      icon: Icons.gpp_maybe,
      explanation:
          'Nothing was granted, or the dialog could not open: the app needs a FlutterFragmentActivity, and '
          'only one request can wait at a time.',
    ),
    (true, true) => const AuthorizationOutcome(
      label: 'Request handled',
      tone: StatusTone.info,
      icon: Icons.task_alt,
      explanation:
          'HealthKit handled the request, with or without its sheet. It never tells what was chosen for '
          'reading; the check shows write access.',
    ),
    (false, true) => const AuthorizationOutcome(
      label: 'Not handled',
      tone: StatusTone.error,
      icon: Icons.error_outline,
      explanation: 'HealthKit reported an error, or this iOS has none of the requested types.',
    ),
  };

  /// The outcome in a few words, for a `StatusPill`.
  final String label;

  /// How the outcome reads.
  final StatusTone tone;

  /// An icon for the outcome.
  final IconData icon;

  /// What the result means on this platform, for the info button.
  final String explanation;
}
