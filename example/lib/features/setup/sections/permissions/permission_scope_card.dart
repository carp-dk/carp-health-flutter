/// The card of the permissions section where the user chooses what to ask for, and asks.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

import '../../controllers/permissions_controller.dart';
import '../../models/permission_request.dart';
import '../../widgets/busy_button.dart';
import '../../widgets/responsive_columns.dart';
import 'authorization_result_view.dart';
import 'category_chips.dart';

/// The scope (all types or one category) and the access (read, or read and write) in connected button
/// groups, what that request holds (with the calls behind an info button), and the buttons for
/// `requestAuthorization` and `hasPermissions`, with the result of the last request under them.
class PermissionScopeCard extends StatelessWidget {
  /// Creates the card for [controller].
  const PermissionScopeCard({super.key, required this.controller});

  /// The selection and the permission calls.
  final PermissionsController controller;

  @override
  Widget build(BuildContext context) {
    // The selection is locked only while a dialog is open or permissions are being revoked; a check in
    // progress is simply replaced by the check of the new selection.
    final locked = controller.isRequesting;
    final categories = controller.categories;
    final scope = controller.scope;
    final request = controller.request;
    final platformName = controller.capabilities.isIOS ? 'HealthKit' : 'Health Connect';
    const motion = ExpressiveMotion.spatialDefault;
    // Outlined, on the surface colour: the button groups' unselected segments have the filled card's colour.
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveColumns(
            breakpoint: 600,
            spacing: 16,
            children: [
              _Labelled(
                label: 'Data types',
                child: ConnectedButtonGroup<bool>(
                  segments: [
                    ButtonGroupSegment(value: true, label: 'All types', icon: Icons.select_all, enabled: !locked),
                    ButtonGroupSegment(
                      value: false,
                      label: 'Category',
                      icon: Icons.category,
                      enabled: !locked && categories.isNotEmpty,
                    ),
                  ],
                  selected: scope.isAll,
                  onSelected: (all) => controller.selectScope(
                    all ? const PermissionScope.all() : PermissionScope.category(categories.first),
                  ),
                ),
              ),
              _Labelled(
                label: 'Access',
                child: ConnectedButtonGroup<HealthDataAccess>(
                  segments: [
                    ButtonGroupSegment(
                      value: HealthDataAccess.READ,
                      label: HealthDataAccess.READ.label,
                      icon: Icons.visibility,
                      enabled: !locked,
                    ),
                    ButtonGroupSegment(
                      value: HealthDataAccess.READ_WRITE,
                      label: HealthDataAccess.READ_WRITE.label,
                      icon: Icons.edit_note,
                      enabled: !locked,
                    ),
                  ],
                  selected: controller.access,
                  onSelected: controller.selectAccess,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: motion.duration,
            curve: motion,
            alignment: Alignment.topCenter,
            child: scope.isAll
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: CategoryChips(
                      categories: categories,
                      selected: scope.category,
                      enabled: !locked,
                      onSelected: (category) => controller.selectScope(PermissionScope.category(category)),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          _RequestSummary(request: request, isIOS: controller.capabilities.isIOS),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BusyButton(
                label: 'Request access',
                busyLabel: 'Waiting for $platformName…',
                icon: Icons.lock_open,
                busy: controller.authorization.isLoading,
                // A check that is running finishes before the dialog opens.
                onPressed: locked || request.isEmpty ? null : controller.requestAuthorization,
              ),
              BusyButton(
                kind: BusyButtonKind.tonal,
                label: 'Check access',
                busyLabel: 'Checking…',
                icon: Icons.fact_check,
                busy: controller.isChecking,
                onPressed: locked || request.isEmpty ? null : controller.check,
              ),
            ],
          ),
          AuthorizationResultView(
            value: controller.authorization,
            isIOS: controller.capabilities.isIOS,
            onRetry: controller.requestAuthorization,
          ),
        ],
      ),
    );
  }
}

/// A small label above a control.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(label, style: theme.textTheme.labelLarge!.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        child,
      ],
    );
  }
}

/// What the request holds: how many types and with which access.
class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.request, required this.isIOS});

  final PermissionRequest request;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readOnly = request.readOnlyTypes;
    final count = request.length == 1 ? '1 type' : '${request.length} types';
    final access = request.preferred.label.toLowerCase();
    final headline = switch (request) {
      PermissionRequest(isEmpty: true) => 'No types on this device',
      _ when readOnly.isEmpty => '$count · $access',
      _ => '$count · ${request.length - readOnly.length} $access, ${readOnly.length} read only',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(headline, style: theme.textTheme.titleSmallEmphasized),
    );
  }
}
