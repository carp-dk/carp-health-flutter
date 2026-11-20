/// One of Health Connect's two extra read permissions: whether it exists here, whether it is granted, and
/// the request.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../../controllers/connect_features_controller.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/setup_tile.dart';

/// What each extra read permission is, for its card.
extension ExtraReadPermissionText on ExtraReadPermission {
  /// The permission's name in the app.
  String get title => switch (this) {
    ExtraReadPermission.history => 'Health data history',
    ExtraReadPermission.background => 'Background reads',
  };

  /// What it allows, for the info button.
  String get description => switch (this) {
    ExtraReadPermission.history =>
      'Reads of data older than the default 30 days. Records the app wrote itself are never limited.',
    ExtraReadPermission.background =>
      'Reads while the app is in the background. Without it, a background app reads only its own records, '
          'and no intervals or step totals.',
  };

  /// The plugin methods that tell whether it exists here and whether it is granted.
  String get checkMethods => switch (this) {
    ExtraReadPermission.history => 'isHealthDataHistoryAvailable · isHealthDataHistoryAuthorized',
    ExtraReadPermission.background => 'isHealthDataInBackgroundAvailable · isHealthDataInBackgroundAuthorized',
  };

  /// The plugin method that requests it.
  String get requestMethod => switch (this) {
    ExtraReadPermission.history => 'requestHealthDataHistoryAuthorization',
    ExtraReadPermission.background => 'requestHealthDataInBackgroundAuthorization',
  };

  /// An icon for it.
  IconData get icon => switch (this) {
    ExtraReadPermission.history => Icons.history,
    ExtraReadPermission.background => Icons.nights_stay,
  };
}

/// The card of [permission]: not available, or granted or not, a Request button where it can be asked
/// for, and a short line when the last request returned false. The calls sit behind the info button.
class ExtraReadCard extends StatelessWidget {
  /// Creates the card of [permission] in [controller].
  const ExtraReadCard({super.key, required this.permission, required this.controller});

  /// The permission.
  final ExtraReadPermission permission;

  /// Its state and request.
  final ConnectFeaturesController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = controller.isAvailable(permission);
    final authorized = controller.isAuthorized(permission);
    final request = controller.requestOf(permission);
    // A permission this Health Connect does not have is shown quietly, outlined.
    return ExpressiveCard(
      variant: available ? ExpressiveCardVariant.filled : ExpressiveCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SetupTile(
            leading: ShapedIcon(
              icon: permission.icon,
              shape: authorized ? ExpressiveShape.cookie9 : ExpressiveShape.clover8,
              size: 44,
              background: authorized ? scheme.primaryContainer : scheme.secondaryContainer,
              foreground: authorized ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
            ),
            title: permission.title,
            subtitle: available ? null : 'Android 15+ / ext 13',
            status: [
              if (!available)
                const StatusPill(label: 'Not available', tone: StatusTone.neutral, icon: Icons.block)
              else if (authorized)
                const StatusPill(label: 'Granted', tone: StatusTone.success, icon: Icons.lock_open)
              else
                const StatusPill(label: 'Not granted', tone: StatusTone.warning, icon: Icons.lock_outline),
            ],
            footer: available && !authorized
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      BusyButton(
                        kind: BusyButtonKind.tonal,
                        label: 'Request',
                        busyLabel: 'Waiting for Health Connect…',
                        icon: Icons.lock_open,
                        busy: request.isLoading,
                        onPressed: () => controller.request(permission),
                      ),
                      // The plugin returns false rather than throwing when the dialog fails; it logs why.
                      if (request case AsyncData(value: false))
                        Text(
                          'Denied, or the dialog failed',
                          style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  )
                : null,
          ),
          if (request case AsyncError(:final error))
            ErrorCard(error: error, onRetry: () => controller.request(permission)),
        ],
      ),
    );
  }
}
