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
      explanation: 'Health Connect is ready: every plugin call can be used.',
    ),
    HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => const SdkStatusInfo(
      label: 'Install or update needed',
      tone: StatusTone.warning,
      icon: Icons.system_update,
      shape: ExpressiveShape.softBurst,
      explanation:
          'Android 13 and lower need the Health Connect app from Google Play, and this one is missing or too '
          'old. installHealthConnect opens the store. From Android 14 on, Health Connect is part of Android '
          'and updates with the system, so this status does not occur there and installHealthConnect does '
          'nothing.',
      offersInstall: true,
    ),
    HealthConnectSdkStatus.sdkUnavailable => const SdkStatusInfo(
      label: 'Unavailable',
      tone: StatusTone.error,
      icon: Icons.block,
      shape: ExpressiveShape.pentagon,
      explanation:
          'Health Connect cannot be used here: Android older than 9, a work profile, private space '
          '(Android 15 and later) or a device without Health Connect. Apps should hide their Health Connect '
          'features then, rather than offer to install it. Plugin calls throw an UnsupportedError.',
    ),
    null => const SdkStatusInfo(
      label: 'Unknown',
      tone: StatusTone.neutral,
      icon: Icons.help_outline,
      shape: ExpressiveShape.circle,
      explanation:
          'The status could not be read: getHealthConnectSdkStatus returns null when the platform call '
          'fails. Refresh to try again.',
    ),
  };

  /// The status in a few words, for a `StatusPill`.
  final String label;

  /// How the status reads.
  final StatusTone tone;

  /// An icon for the status.
  final IconData icon;

  /// The expressive shape the platform icon takes in this status, so a change of status morphs it.
  final ExpressiveShape shape;

  /// What the status means and what to do about it.
  final String explanation;

  /// Whether `installHealthConnect` helps: only when Health Connect must be installed or updated
  /// (`sdkUnavailableProviderUpdateRequired`, Android 13 and lower).
  final bool offersInstall;
}
