/// The hero card's access panel: what the platform tells about access to the overview's core types,
/// and the "Grant access" button that requests it with `requestAuthorization`.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../model/core_access.dart';
import '../overview_controller.dart';

/// The access status (`hasPermissions` on Android, `getRequestStatusForAuthorization` on iOS) and the
/// button that requests read and write access to all core types (`requestAuthorization`), with what the
/// request returned. The info button names the calls, the types and what the status means.
class CoreAccessPanel extends StatelessWidget {
  /// Creates the panel for [controller]'s core types.
  const CoreAccessPanel({super.key, required this.controller});

  /// The overview's state: the core types, their access and the authorization request.
  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const motion = ExpressiveMotion.spatialDefault;
    final authorization = controller.authorization;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _GrantButton(controller: controller),
            _AccessStatus(controller: controller),
          ],
        ),
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: switch (authorization) {
            AsyncError(:final error) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ErrorCard(error: error, onRetry: controller.authorize),
            ),
            AsyncData(:final value) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(CoreAccess.describeRequest(value, controller.platform), style: theme.textTheme.labelMedium),
            ),
            _ => const SizedBox(width: double.infinity),
          },
        ),
      ],
    );
  }
}

/// The access status as a pill, or the error of the check.
class _AccessStatus extends StatelessWidget {
  const _AccessStatus({required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.canRead) {
      return const StatusPill(label: 'Health Connect needed', tone: StatusTone.neutral, icon: Icons.block);
    }
    final access = controller.access;
    if (access case AsyncError(:final error)) {
      return ErrorCard(error: error, onRetry: controller.checkAccess);
    }
    return switch (access.valueOrNull) {
      final value? => StatusPill(label: value.label, tone: value.tone, icon: value.icon),
      null => const StatusPill(label: 'Checking', tone: StatusTone.neutral, icon: Icons.hourglass_top),
    };
  }
}

/// "Grant access": requests the core types; shows a loading indicator while the platform's dialog or
/// sheet is open.
class _GrantButton extends StatelessWidget {
  const _GrantButton({required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    final busy = controller.isAuthorizing;
    return FilledButton.icon(
      onPressed: busy || !controller.canRead ? null : controller.authorize,
      icon: busy
          ? ExpressiveLoadingIndicator(size: 20, semanticsLabel: 'Requesting access')
          : const Icon(Icons.lock_open),
      label: Text(busy ? 'Requesting access…' : 'Grant access'),
    );
  }
}
