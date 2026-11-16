/// The card that shows a failed plugin call: what went wrong, what to do about it, and a way to retry.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';

/// Shows [error] as the app shows every failure: a card in the error container colours with a title,
/// the plugin's message, advice ([ErrorInfo.hint]) and the error codes.
///
/// [ErrorInfo.from] describes any error a plugin call can throw: a `HealthPlatformException` with a
/// `HealthErrorCode` (such as `rateLimitExceeded`), a `HealthException`, an `UnsupportedError` when
/// Health Connect is missing, and so on. With [onRetry] the card offers "Try again", emphasized when
/// the error is retryable. A permission error also links to the Setup page, where access is requested.
class ErrorCard extends StatelessWidget {
  /// Creates a card for [error]; [onRetry] repeats the call that failed.
  const ErrorCard({super.key, required this.error, this.onRetry});

  /// What the failed call threw.
  final Object error;

  /// Repeats the failed call; null hides the retry button.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final info = ErrorInfo.from(error);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    // AppNavigation exists in the app but not around a widget under test.
    final canOpenSetup = info.isPermission && context.getInheritedWidgetOfExactType<AppNavigation>() != null;
    final codes = [?info.code, if (info.platformCode != info.code) ?info.platformCode];
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 16,
                children: [
                  ShapedIcon(
                    icon: _iconFor(info),
                    shape: ExpressiveShape.sunny,
                    size: 48,
                    background: scheme.error,
                    foreground: scheme.onError,
                  ),
                  Expanded(
                    child: Text(info.title, style: text.titleMediumEmphasized.copyWith(color: scheme.onErrorContainer)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(info.message, style: text.bodyMedium!.copyWith(color: scheme.onErrorContainer)),
              if (info.hint case final hint?) ...[
                const SizedBox(height: 8),
                Text(hint, style: text.bodySmall!.copyWith(color: scheme.onErrorContainer)),
              ],
              if (codes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(codes.join(' · '), style: text.labelSmall!.copyWith(color: scheme.onErrorContainer).monospace),
              ],
              if (onRetry != null || canOpenSetup) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [?_retryButton(info, scheme), ?_setupButton(context, scheme, canOpenSetup)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "Try again": filled in the error colour when the error is retryable (the plugin never retries on
  /// its own), quieter otherwise.
  Widget? _retryButton(ErrorInfo info, ColorScheme scheme) {
    final retry = onRetry;
    if (retry == null) return null;
    const icon = Icon(Icons.refresh);
    const label = Text('Try again');
    if (info.isRetryable) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
        onPressed: retry,
        icon: icon,
        label: label,
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: scheme.onErrorContainer),
      onPressed: retry,
      icon: icon,
      label: label,
    );
  }

  /// "Open Setup", for permission errors: Setup requests access with `requestAuthorization`.
  Widget? _setupButton(BuildContext context, ColorScheme scheme, bool show) => !show
      ? null
      : TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: scheme.onErrorContainer),
          onPressed: () => AppNavigation.goTo(context, AppDestination.setup),
          icon: const Icon(Icons.lock_open),
          label: const Text('Open Setup'),
        );

  /// An icon that says what kind of failure [info] is; [ErrorInfo.code] is a [HealthErrorCode] name.
  static IconData _iconFor(ErrorInfo info) {
    if (info.isPermission) return Icons.lock_outline;
    return switch (HealthErrorCode.values.asNameMap()[info.code]) {
      HealthErrorCode.rateLimitExceeded => Icons.hourglass_bottom,
      HealthErrorCode.notSupported => Icons.block,
      HealthErrorCode.unavailable => Icons.cloud_off,
      HealthErrorCode.deviceLocked => Icons.phonelink_lock,
      HealthErrorCode.dataTooLarge => Icons.data_usage,
      _ => Icons.error_outline,
    };
  }
}
