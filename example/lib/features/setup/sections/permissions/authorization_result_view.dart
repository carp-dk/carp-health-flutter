/// The state of the last `requestAuthorization` call, under the buttons of the permissions card.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../../models/authorization_outcome.dart';

/// Nothing before the first request and while it runs (the request button shows the progress); then what
/// the result means on this platform ([AuthorizationOutcome]) as a pill with an info button, or an
/// `ErrorCard`.
class AuthorizationResultView extends StatelessWidget {
  /// Creates the view of [value], a result of `requestAuthorization` on iOS ([isIOS]) or Android.
  const AuthorizationResultView({super.key, required this.value, required this.isIOS, this.onRetry});

  /// The state of the last request.
  final AsyncValue<bool> value;

  /// Whether the result came from HealthKit, which words it differently from Health Connect.
  final bool isIOS;

  /// Repeats the request after an error.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final Widget? child = switch (value) {
      AsyncData(:final value) => _Outcome(
        outcome: AuthorizationOutcome.of(value, isIOS: isIOS),
        result: value,
      ),
      AsyncError(:final error) => ErrorCard(error: error, onRetry: onRetry),
      AsyncIdle() || AsyncLoading() => null,
    };
    const motion = ExpressiveMotion.spatialDefault;
    return AnimatedSize(
      duration: motion.duration,
      curve: motion,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.effectsDefault.duration,
        child: child == null
            ? const SizedBox(width: double.infinity)
            : KeyedSubtree(
                key: ValueKey(value.runtimeType),
                child: Padding(padding: const EdgeInsets.only(top: 16), child: child),
              ),
      ),
    );
  }
}

/// The pill of a completed request, with what it means behind the info button.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.outcome, required this.result});

  final AuthorizationOutcome outcome;
  final bool result;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      StatusPill(label: outcome.label, tone: outcome.tone, icon: outcome.icon),
      InfoButton(title: 'Request result', code: 'requestAuthorization → $result', message: outcome.explanation),
    ],
  );
}
