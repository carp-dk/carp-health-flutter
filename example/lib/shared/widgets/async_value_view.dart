/// Shows the state of a plugin call, an `AsyncValue`, the one way the whole app does: the expressive
/// loading indicator while it runs, an `ErrorCard` when it failed, and the result when it is there.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';

import 'error_card.dart';

/// Builds the widget for each state of [value]:
///
/// * [AsyncIdle]: [idle], or nothing;
/// * [AsyncLoading]: an [ExpressiveLoadingIndicator] with [loadingLabel], or, while a refresh keeps the
///   previous value, that value under a [WavyProgressIndicator], so the content does not jump;
/// * [AsyncData]: [data];
/// * [AsyncError]: an [ErrorCard], with a retry button when [onRetry] is given.
///
/// State changes cross-fade on the slow effects spring. The plugin is never called here: the feature
/// controllers own the calls and expose their state as `AsyncValue`s.
class AsyncValueView<T> extends StatelessWidget {
  /// Creates a view of [value] that shows its data with [data].
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.idle,
    this.onRetry,
    this.loadingLabel,
  });

  /// The state to show.
  final AsyncValue<T> value;

  /// Builds the result of a call that succeeded.
  final Widget Function(BuildContext context, T value) data;

  /// Shown before anything was asked for; nothing by default.
  final Widget? idle;

  /// Repeats the call after an error; null hides the retry button.
  final VoidCallback? onRetry;

  /// What is loading, such as "Reading steps…", shown under the loading indicator.
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final (String state, Widget child) = switch (value) {
      AsyncIdle() => ('idle', idle ?? const SizedBox.shrink()),
      AsyncLoading(:final previous) when previous != null => (
        'data',
        _DataWithProgress(refreshing: true, label: loadingLabel, child: data(context, previous)),
      ),
      AsyncLoading() => ('loading', _Loading(label: loadingLabel)),
      AsyncData(:final value) => ('data', _DataWithProgress(refreshing: false, child: data(context, value))),
      AsyncError(:final error) => ('error', ErrorCard(error: error, onRetry: onRetry)),
    };
    const motion = ExpressiveMotion.effectsSlow;
    return AnimatedSwitcher(
      duration: motion.duration,
      switchInCurve: motion,
      switchOutCurve: motion,
      // Top-aligned, so content of a different height does not jump to the middle while it fades.
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(state), child: child),
    );
  }
}

/// The first load: a loading indicator and what is loading.
class _Loading extends StatelessWidget {
  const _Loading({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            ExpressiveLoadingIndicator(size: 56, semanticsLabel: label ?? 'Loading'),
            if (label case final label?)
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// The data, with a wavy progress bar above it that springs open while a refresh runs.
class _DataWithProgress extends StatelessWidget {
  const _DataWithProgress({required this.refreshing, required this.child, this.label});

  final bool refreshing;
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const motion = ExpressiveMotion.spatialDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: refreshing
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WavyProgressIndicator(semanticsLabel: label ?? 'Refreshing'),
                )
              : const SizedBox(width: double.infinity),
        ),
        child,
      ],
    );
  }
}
