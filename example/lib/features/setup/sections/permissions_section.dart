/// The Setup page's permissions section: choosing data types and access, and the plugin's permission
/// calls for them: `requestAuthorization`, `hasPermissions`, `getRequestStatusForAuthorization` (iOS)
/// and `revokePermissions` (Android).
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import '../controllers/permissions_controller.dart';
import 'permissions/permission_report_view.dart';
import 'permissions/permission_scope_card.dart';
import 'permissions/request_status_card.dart';
import 'permissions/revoke_card.dart';

/// The selection card, the access check and the platform's extra call (iOS: the request status, next
/// to the selection it belongs to; Android: revoking). The other platform's call follows as a note at
/// the end. Rebuilds when the controller or the capabilities (and with them the catalog) change.
class PermissionsSection extends StatelessWidget {
  /// Creates the section for [controller].
  const PermissionsSection({super.key, required this.controller});

  /// The selection and the permission calls.
  final PermissionsController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.capabilities]),
    builder: (context, _) {
      final isIOS = controller.capabilities.isIOS;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Permissions'),
          PermissionScopeCard(controller: controller),
          if (isIOS) ...[const SizedBox(height: 12), RequestStatusCard(controller: controller)],
          const SizedBox(height: 20),
          PermissionReportView(controller: controller),
          const SizedBox(height: 12),
          RevokeCard(controller: controller),
          if (!isIOS) ...[const SizedBox(height: 12), RequestStatusCard(controller: controller)],
        ],
      );
    },
  );
}
