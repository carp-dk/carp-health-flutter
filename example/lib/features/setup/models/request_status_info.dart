/// How the Setup page explains `getRequestStatusForAuthorization`, which tells on iOS whether
/// `requestAuthorization` would show HealthKit's sheet (README, "Authorization on iOS").
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

/// The description of one [HealthAuthorizationRequestStatus], or of none (null).
@immutable
class RequestStatusInfo {
  /// Creates a description.
  const RequestStatusInfo({required this.label, required this.tone, required this.icon, required this.explanation});

  /// Describes [status]; null is what the plugin returns on Android, or for a request without types.
  factory RequestStatusInfo.of(HealthAuthorizationRequestStatus? status) => switch (status) {
    HealthAuthorizationRequestStatus.shouldRequest => const RequestStatusInfo(
      label: 'Sheet will show',
      tone: StatusTone.info,
      icon: Icons.open_in_new,
      explanation: "Some of these types were not asked about yet: requestAuthorization shows HealthKit's sheet.",
    ),
    HealthAuthorizationRequestStatus.unnecessary => const RequestStatusInfo(
      label: 'Already answered',
      tone: StatusTone.success,
      icon: Icons.done_all,
      explanation:
          'All were answered: requestAuthorization returns without the sheet. Users change their choice in '
          'the Health or Settings app.',
    ),
    HealthAuthorizationRequestStatus.unknown => const RequestStatusInfo(
      label: 'Unknown',
      tone: StatusTone.neutral,
      icon: Icons.help_outline,
      explanation: 'HealthKit could not tell whether the sheet would show.',
    ),
    null => const RequestStatusInfo(
      label: 'No status',
      tone: StatusTone.neutral,
      icon: Icons.remove_circle_outline,
      explanation: 'Nothing to ask about: the scope has no types on this device.',
    ),
  };

  /// The status in a few words, for a `StatusPill`.
  final String label;

  /// How the status reads.
  final StatusTone tone;

  /// An icon for the status.
  final IconData icon;

  /// What the status means for the next request, for the info button.
  final String explanation;
}
