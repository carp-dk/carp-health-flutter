/// The icon the app shows a failure with, in the error card and the error dialog.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/errors/error_info.dart';

/// Display information for an [ErrorInfo].
extension ErrorInfoVisuals on ErrorInfo {
  /// An icon that says what kind of failure this is: a lock for a missing permission, else by the
  /// [HealthErrorCode] named in [ErrorInfo.code].
  IconData get icon {
    if (isPermission) return Icons.lock_outline;
    return switch (HealthErrorCode.values.asNameMap()[code]) {
      HealthErrorCode.rateLimitExceeded => Icons.hourglass_bottom,
      HealthErrorCode.notSupported => Icons.block,
      HealthErrorCode.unavailable => Icons.cloud_off,
      HealthErrorCode.deviceLocked => Icons.phonelink_lock,
      HealthErrorCode.dataTooLarge => Icons.data_usage,
      _ => Icons.error_outline,
    };
  }
}
