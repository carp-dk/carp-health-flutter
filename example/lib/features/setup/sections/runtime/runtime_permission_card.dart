/// One Android runtime permission of the Setup page: its status and what the user can do about it.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controllers/runtime_permissions_controller.dart';
import '../../models/runtime_permission.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/setup_tile.dart';

/// The card of [permission]: its status (`Permission.status`) as a pill, why a health app needs it behind
/// the info button, and the action its status allows: request it (`Permission.request`) or, once Android shows no dialog any
/// more, open the app's system settings (`openAppSettings`).
class RuntimePermissionCard extends StatelessWidget {
  /// Creates the card of [permission] in [controller].
  const RuntimePermissionCard({super.key, required this.permission, required this.controller});

  /// The permission.
  final RuntimePermission permission;

  /// Its status and the calls.
  final RuntimePermissionsController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = controller.statusOf(permission);
    final view = switch (status.valueOrNull) {
      final value? => RuntimeStatusView.of(value),
      null => null,
    };
    final granted = status.valueOrNull == PermissionStatus.granted;
    return ExpressiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SetupTile(
            // The shape settles into a calm cookie once the permission is granted.
            leading: ShapedIcon(
              icon: permission.icon,
              shape: granted ? ExpressiveShape.cookie9 : ExpressiveShape.clover8,
              size: 44,
              background: granted ? scheme.primaryContainer : scheme.secondaryContainer,
              foreground: granted ? scheme.onPrimaryContainer : scheme.onSecondaryContainer,
            ),
            title: permission.label,
            status: [
              if (view != null)
                StatusPill(label: view.label, tone: view.tone, icon: view.icon)
              else if (status.isLoading)
                ExpressiveLoadingIndicator(size: 32, semanticsLabel: 'Reading the ${permission.label} status'),
            ],
            footer: switch (view) {
              // Before the first status (or after it failed) the permission can still be requested.
              null when status.isLoading => null,
              null => _action(RuntimePermissionAction.request, status),
              final view => _action(view.action, status),
            },
          ),
          if (status case AsyncError(:final error)) ErrorCard(error: error, onRetry: controller.refresh),
        ],
      ),
    );
  }

  /// The button for [action]; nothing when the status allows none.
  Widget? _action(RuntimePermissionAction action, AsyncValue<PermissionStatus> status) => switch (action) {
    RuntimePermissionAction.none => null,
    RuntimePermissionAction.request => BusyButton(
      kind: BusyButtonKind.tonal,
      label: 'Request',
      busyLabel: 'Waiting for Android…',
      icon: Icons.how_to_reg,
      busy: controller.isRequesting(permission),
      // A status read (when the app resumes) only disables the button for a moment.
      onPressed: status.isLoading ? null : () => controller.request(permission),
    ),
    // From Android 11 on, a permission denied twice shows no dialog any more: only the settings can grant it.
    RuntimePermissionAction.openSettings => BusyButton(
      kind: BusyButtonKind.outlined,
      label: 'Open app settings',
      busyLabel: 'Opening the settings…',
      icon: Icons.settings,
      busy: controller.settings.isLoading,
      onPressed: controller.openSettings,
    ),
  };
}
