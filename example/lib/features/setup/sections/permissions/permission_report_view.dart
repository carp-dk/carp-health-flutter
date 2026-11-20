/// The answers of the last access check of the permissions section.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/async_value_view.dart';

import '../../controllers/permissions_controller.dart';
import '../../models/permission_check.dart';
import '../../models/permission_report.dart';
import '../../models/permission_request.dart';
import 'category_result_tile.dart';

/// Nothing before the first check (or, without Health Connect, why there is none), the loading indicator
/// while `hasPermissions` runs, an `ErrorCard` when it failed, and otherwise a summary over one row per
/// category ([CategoryResultTile]).
class PermissionReportView extends StatelessWidget {
  /// Creates the view of [controller]'s check.
  const PermissionReportView({super.key, required this.controller});

  /// The check and its answers.
  final PermissionsController controller;

  @override
  Widget build(BuildContext context) => AsyncValueView<PermissionReport>(
    value: controller.report,
    loadingLabel: 'Checking access…',
    onRetry: controller.check,
    // Without Health Connect every permission call would throw: the refresh checks nothing.
    idle: controller.capabilities.healthConnectAvailable ? null : const _NotChecked(),
    data: (context, report) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportHeader(report: report, isIOS: controller.capabilities.isIOS),
        const SizedBox(height: 12),
        SegmentedList(
          children: [
            for (final MapEntry(key: category, value: check) in report.categories.entries)
              CategoryResultTile(key: ValueKey(category), category: category, check: check, controller: controller),
          ],
        ),
      ],
    ),
  );
}

/// The summary of a report: the result in a line, with what the answers mean behind the info button, and
/// what was checked when.
class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.report, required this.isIOS});

  final PermissionReport report;
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allGranted = report.count(PermissionAnswer.granted) == report.categories.length;
    final denied = report.count(PermissionAnswer.denied) > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        spacing: 16,
        children: [
          ShapedIcon(
            icon: allGranted ? Icons.verified_user : (denied ? Icons.shield_outlined : Icons.help_outline),
            shape: allGranted ? ExpressiveShape.cookie9 : ExpressiveShape.pentagon,
            size: 48,
            background: allGranted ? scheme.primaryContainer : scheme.tertiaryContainer,
            foreground: allGranted ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.summary, style: theme.textTheme.titleMediumEmphasized),
                Text(
                  '${report.scope.label} · ${report.access.label} · ${formatRelative(report.checkedAt)}',
                  style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Why nothing was checked: Health Connect is not available, so every permission call would throw.
class _NotChecked extends StatelessWidget {
  const _NotChecked();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        'Not checked: Health Connect unavailable',
        style: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
