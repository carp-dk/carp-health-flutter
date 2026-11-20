/// How the Setup page explains Health Connect's status (`getHealthConnectSdkStatus`): what it means and
/// what an app should do about it, as the plugin's README advises.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

/// The description of one [HealthConnectSdkStatus], or of a status that could not be read.
@immutable
class SdkStatusInfo {
  /// Creates a description.
  const SdkStatusInfo({
    required this.label,
    required this.tone,
    required this.icon,
    required this.shape,
    required this.explanation,
    this.offersInstall = false,
  });

  /// Describes [status]; null is a status that could not be read (the plugin returns null on errors).
  factory SdkStatusInfo.of(HealthConnectSdkStatus? status) => switch (status) {
    HealthConnectSdkStatus.sdkAvailable => const SdkStatusInfo(
      label: 'Available',
      tone: StatusTone.success,
      icon: Icons.check_circle,
      shape: ExpressiveShape.cookie9,
      explanation:
          'Every plugin call can be used. From Android 14 on, Health Connect is part of Android, so '
          'installHealthConnect does nothing there.',
    ),
    HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => const SdkStatusInfo(
      label: 'Install or update needed',
      tone: StatusTone.warning,
      icon: Icons.system_update,
      shape: ExpressiveShape.softBurst,
      explanation:
          'Android 13 and lower need the Health Connect app, which is missing or too old: '
          'installHealthConnect opens the store. Android 14 and later have it built in.',
      offersInstall: true,
    ),
    HealthConnectSdkStatus.sdkUnavailable => const SdkStatusInfo(
      label: 'Unavailable',
      tone: StatusTone.error,
      icon: Icons.block,
      shape: ExpressiveShape.pentagon,
      explanation:
          'Android older than 9, a work profile, private space or no Health Connect. Plugin calls throw an '
          'UnsupportedError: apps should hide their Health Connect features.',
    ),
    null => const SdkStatusInfo(
      label: 'Unknown',
      tone: StatusTone.neutral,
      icon: Icons.help_outline,
      shape: ExpressiveShape.circle,
      explanation: 'getHealthConnectSdkStatus returned null: the platform call failed. Refresh to try again.',
    ),
  };

  /// Apple Health on iOS [version] (null when unknown): HealthKit has no SDK status to read.
  factory SdkStatusInfo.healthKit(int? version) => SdkStatusInfo(
    label: 'Built into iOS${version == null ? '' : ' $version'}',
    tone: StatusTone.success,
    icon: Icons.check_circle,
    shape: ExpressiveShape.cookie12,
    explanation:
        'HealthKit is part of iOS: nothing to install. getHealthConnectSdkStatus returns null and '
        'installHealthConnect does nothing here.',
  );

  /// The status while the first check runs.
  static const SdkStatusInfo checking = SdkStatusInfo(
    label: 'Checking…',
    tone: StatusTone.neutral,
    icon: Icons.hourglass_top,
    shape: ExpressiveShape.circle,
    explanation: 'Asking getHealthConnectSdkStatus whether Health Connect can be used.',
  );

  /// The status in a few words, for a `StatusPill`.
  final String label;

  /// How the status reads.
  final StatusTone tone;

  /// An icon for the status.
  final IconData icon;

  /// The expressive shape the platform icon takes in this status, so a change of status morphs it.
  final ExpressiveShape shape;

  /// What the status means and what to do about it, for the info button.
  final String explanation;

  /// Whether `installHealthConnect` helps: only when Health Connect must be installed or updated
  /// (`sdkUnavailableProviderUpdateRequired`, Android 13 and lower).
  final bool offersInstall;
}
