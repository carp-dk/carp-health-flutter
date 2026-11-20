/// What the platform tells about the app's access to the overview's core data types: Android's
/// `hasPermissions` and iOS's `getRequestStatusForAuthorization`.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

/// The app's access to the core types, as far as the platform discloses it, with a [label], a
/// [tone] and an [icon] for a `StatusPill`.
///
/// Health Connect answers whether permissions are granted. HealthKit never tells whether read access
/// was granted; it only tells whether the authorization sheet would show again.
enum CoreAccess {
  /// Android: `hasPermissions` says every core permission is granted.
  granted('Access granted', StatusTone.success, Icons.verified_user),

  /// Android: `hasPermissions` says at least one core permission is missing.
  missing('Access missing', StatusTone.warning, Icons.lock_outline),

  /// iOS: the user has answered the sheet for every core type
  /// (`HealthAuthorizationRequestStatus.unnecessary`).
  answered('Answered before', StatusTone.info, Icons.how_to_reg),

  /// iOS: the sheet would show, as some type was never asked for
  /// (`HealthAuthorizationRequestStatus.shouldRequest`).
  notAsked('Not asked yet', StatusTone.warning, Icons.lock_outline),

  /// The platform could not tell.
  unknown('Unknown', StatusTone.neutral, Icons.help_outline);

  const CoreAccess(this.label, this.tone, this.icon);

  /// The status in a few words.
  final String label;

  /// How the status reads.
  final StatusTone tone;

  /// An icon for the status.
  final IconData icon;

  /// The access `getRequestStatusForAuthorization` reports with [status] (iOS).
  static CoreAccess fromRequestStatus(HealthAuthorizationRequestStatus? status) => switch (status) {
    HealthAuthorizationRequestStatus.unnecessary => answered,
    HealthAuthorizationRequestStatus.shouldRequest => notAsked,
    HealthAuthorizationRequestStatus.unknown || null => unknown,
  };

  /// The method that checks the access on [platform].
  static String checkMethod(HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect => 'hasPermissions',
    HealthPlatformType.appleHealth => 'getRequestStatusForAuthorization',
  };

  /// What `requestAuthorization` answering [result] on [platform] means, in a short line. On Android,
  /// true says that at least one permission is granted, not all of them (`hasPermissions` tells); on
  /// iOS, that HealthKit completed the request, whatever the user chose, as it keeps read access private.
  static String describeRequest(bool result, HealthPlatformType platform) => switch ((platform, result)) {
    (HealthPlatformType.googleHealthConnect, true) => 'Access granted',
    (HealthPlatformType.googleHealthConnect, false) => 'No access granted',
    (HealthPlatformType.appleHealth, true) => 'Access requested',
    (HealthPlatformType.appleHealth, false) => 'Request failed',
  };

  /// What `requestAuthorization`'s result means on [platform], in a sentence.
  static String requestMeaning(HealthPlatformType platform) => switch (platform) {
    HealthPlatformType.googleHealthConnect =>
      'requestAuthorization returns true once any permission is granted, false when none is or the dialog '
          'could not show.',
    HealthPlatformType.appleHealth =>
      'requestAuthorization returns true once HealthKit completed the request, whatever the user chose.',
  };

  /// What the status means, in a sentence.
  String get explanation => switch (this) {
    granted => 'Every core type can be read and written.',
    missing => 'Some core permission is missing: grant access to read them all.',
    answered => 'The sheet was answered; HealthKit keeps private whether reading was allowed.',
    notAsked => 'The sheet has not been shown for every core type yet.',
    unknown => 'The platform could not tell whether access was granted.',
  };
}
