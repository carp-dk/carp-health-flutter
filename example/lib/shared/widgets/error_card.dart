/// The card that shows a failed plugin call: what went wrong, its codes, and a way to retry.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/error_visuals.dart';
import 'package:health_example/shared/visuals/monospace.dart';

import 'error_dialog.dart';

/// Shows [error] as the app shows every failure: a compact card in the error container colours with a
/// title, the first line of the plugin's message and the error codes. Its info button opens
/// [showErrorDialog] with the whole message and advice ([ErrorInfo.hint]).
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
    final color = scheme.onErrorContainer;
    // AppNavigation exists in the app but not around a widget under test.
    final canOpenSetup = info.isPermission && context.getInheritedWidgetOfExactType<AppNavigation>() != null;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 12,
                children: [
                  ShapedIcon(
                    icon: info.icon,
                    shape: ExpressiveShape.sunny,
                    size: 40,
                    background: scheme.error,
                    foreground: scheme.onError,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.title, style: text.titleMediumEmphasized.copyWith(color: color)),
                        Text(
                          info.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium!.copyWith(color: color),
                        ),
                        if (info.codes.isNotEmpty)
                          Text(info.codes.join(' · '), style: text.labelSmall!.copyWith(color: color).monospace),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Details',
                    color: color,
                    onPressed: () => showErrorDialog(context, error),
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
              if (onRetry != null || canOpenSetup)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [?_retryButton(info, scheme), ?_setupButton(context, scheme, canOpenSetup)],
                  ),
                ),
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
}
