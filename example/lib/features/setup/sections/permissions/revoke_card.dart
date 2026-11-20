/// Taking back the app's Health Connect permissions: `revokePermissions`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../../controllers/permissions_controller.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/platform_note.dart';
import '../../widgets/setup_tile.dart';

/// On Android, a card that revokes every Health Connect permission of the app after a confirmation. On
/// iOS, a note: HealthKit has no way for an app to give up its access.
class RevokeCard extends StatelessWidget {
  /// Creates the card for [controller].
  const RevokeCard({super.key, required this.controller});

  /// Revokes the permissions.
  final PermissionsController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.capabilities.isAndroid) {
      return const PlatformNote.android(
        title: 'Revoke permissions',
        icon: Icons.lock_reset,
        code: 'revokePermissions',
        message:
            'HealthKit lets no app give up its access, so this does nothing on iOS. Users change access in the '
            'Health or Settings app.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final revocation = controller.revocation;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SetupTile(
            leading: ShapedIcon(
              icon: Icons.lock_reset,
              shape: ExpressiveShape.cookie4,
              size: 44,
              background: scheme.errorContainer,
              foreground: scheme.onErrorContainer,
            ),
            title: 'Revoke all permissions',
            badge: const PlatformBadge.android(),
            status: [
              if (revocation is AsyncData<void>)
                const StatusPill(label: 'Revoked: restart the app', tone: StatusTone.info, icon: Icons.restart_alt),
            ],
            footer: BusyButton(
              kind: BusyButtonKind.outlined,
              label: 'Revoke',
              busyLabel: 'Revoking…',
              icon: Icons.lock_reset,
              busy: revocation.isLoading,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
              ),
              onPressed: controller.isRequesting ? null : () => unawaited(_confirmAndRevoke(context)),
            ),
          ),
          if (revocation case AsyncError(:final error)) ErrorCard(error: error, onRetry: controller.revokePermissions),
        ],
      ),
    );
  }

  /// Asks before revoking: the user has to grant everything again afterwards.
  Future<void> _confirmAndRevoke(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.lock_reset),
        title: const Text('Revoke all permissions?'),
        content: const Text('The app must ask for them again, and restart for it to apply fully.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.revokePermissions();
  }
}
