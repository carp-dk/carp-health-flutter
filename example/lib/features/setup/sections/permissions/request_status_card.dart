/// Whether requesting the chosen types would show HealthKit's sheet: `getRequestStatusForAuthorization`.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../../controllers/permissions_controller.dart';
import '../../models/request_status_info.dart';
import '../../widgets/platform_note.dart';
import '../../widgets/setup_tile.dart';

/// The plugin call behind the card.
const _call = 'getRequestStatusForAuthorization';

/// On iOS, the status of the current selection, read again whenever it changes and after a request. On
/// Android, a note: the plugin returns null there, as `hasPermissions` tells what was granted.
class RequestStatusCard extends StatelessWidget {
  /// Creates the card for [controller]'s selection.
  const RequestStatusCard({super.key, required this.controller});

  /// The selection and its request status.
  final PermissionsController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.capabilities.isIOS) {
      return const PlatformNote.ios(
        title: 'Request status',
        icon: Icons.pending_actions,
        code: _call,
        message:
            "Tells an iOS app whether requestAuthorization would show HealthKit's sheet. On Android it returns "
            'null: hasPermissions tells what was granted.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final status = controller.requestStatus;
    final info = switch (status.valueOrNull) {
      final value? => RequestStatusInfo.of(value),
      null when status is AsyncData => RequestStatusInfo.of(null),
      null => null,
    };
    return ExpressiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          SetupTile(
            leading: ShapedIcon(
              icon: info?.icon ?? Icons.pending_actions,
              shape: ExpressiveShape.puffy,
              size: 44,
              background: scheme.secondary,
              foreground: scheme.onSecondary,
            ),
            title: 'Request status',
            badge: const PlatformBadge.ios(),
            status: [
              if (status.isLoading)
                const ExpressiveLoadingIndicator(size: 32, semanticsLabel: 'Reading the request status')
              else if (info != null)
                StatusPill(label: info.label, tone: info.tone, icon: info.icon),
            ],
          ),
          if (status case AsyncError(:final error)) ErrorCard(error: error, onRetry: controller.refreshRequestStatus),
        ],
      ),
    );
  }
}
