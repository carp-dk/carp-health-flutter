/// The Setup page's runtime permissions section: the Android permissions that the plugin's README asks
/// apps to request with `permission_handler` next to the Health Connect permissions (activity recognition
/// and location), with `Permission.status`, `Permission.request` and `openAppSettings`.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../controllers/runtime_permissions_controller.dart';
import '../models/runtime_permission.dart';
import '../widgets/platform_note.dart';
import '../widgets/responsive_columns.dart';
import 'runtime/runtime_permission_card.dart';

/// On Android, a card per [RuntimePermission] (side by side on wide windows) and the result of opening the
/// system settings when it failed; on iOS, a note on why there is nothing to ask for. Rebuilds when the
/// controller changes.
class RuntimePermissionsSection extends StatelessWidget {
  /// Creates the section for [controller].
  const RuntimePermissionsSection({super.key, required this.controller});

  /// The statuses and the `permission_handler` calls.
  final RuntimePermissionsController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final settings = controller.settings;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Runtime permissions', trailing: PlatformBadge.android()),
          if (!controller.isSupported)
            const PlatformNote.android(title: 'Not needed on iOS', icon: Icons.android, showBadge: false, message: '')
          else ...[
            ResponsiveColumns(
              children: [
                for (final permission in RuntimePermission.values)
                  RuntimePermissionCard(permission: permission, controller: controller),
              ],
            ),
            if (settings case AsyncError(:final error)) ...[
              const SizedBox(height: 12),
              ErrorCard(error: error, onRetry: controller.openSettings),
            ] else if (settings case AsyncData(value: false))
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(
                  'Could not open: Settings > Apps > health_example',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      );
    },
  );
}
