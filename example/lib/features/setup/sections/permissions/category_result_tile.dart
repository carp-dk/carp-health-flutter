/// One category's answer in the access check, which opens to the answer for each of its types.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/type_icon.dart';
import 'package:health_example/shared/widgets/async_value_view.dart';

import '../../controllers/permissions_controller.dart';
import '../../models/permission_check.dart';

/// The answer of `hasPermissions` for [category] as a status pill. Tapping the row opens it and checks
/// each of its types on their own (`PermissionsController.checkTypesOf`), the way to find the types
/// that keep a category from being granted.
class CategoryResultTile extends StatefulWidget {
  /// Creates the row of [category], answered with [check], in [controller]'s current check.
  const CategoryResultTile({super.key, required this.category, required this.check, required this.controller});

  /// The category.
  final TypeCategory category;

  /// What `hasPermissions` answered for its types.
  final PermissionCheck check;

  /// Checks the category's types on request.
  final PermissionsController controller;

  @override
  State<CategoryResultTile> createState() => _CategoryResultTileState();
}

class _CategoryResultTileState extends State<CategoryResultTile> {
  bool? _open; // Null until the user taps: open by default once the types were checked.

  void _toggle(bool open) {
    setState(() => _open = !open);
    final checks = widget.controller.typeChecksOf(widget.category);
    if (!open && (checks is AsyncIdle || checks is AsyncError)) widget.controller.checkTypesOf(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final checks = controller.typeChecksOf(widget.category);
    final open = _open ?? checks is! AsyncIdle;
    final view = widget.check.describe(isGroup: true);
    final count = controller.catalog.byCategory[widget.category]?.length ?? 0;
    const motion = ExpressiveMotion.spatialDefault;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _toggle(open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              spacing: 16,
              children: [
                TypeIcon.category(category: widget.category, size: 44),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        '${widget.category.label} · ${count == 1 ? '1 type' : '$count types'}',
                        style: theme.textTheme.titleSmallEmphasized,
                      ),
                      // What the answers mean is said once, behind the info button of the summary.
                      StatusPill(label: view.label, tone: view.tone, icon: view.icon),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: motion.duration,
                  curve: motion,
                  child: const Icon(Icons.expand_more),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: motion.duration,
          curve: motion,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: AsyncValueView<TypeChecks>(
                    value: checks,
                    loadingLabel: 'Checking each type…',
                    onRetry: () => controller.checkTypesOf(widget.category),
                    data: (context, checks) => _TypeChecksList(checks: checks),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The answer for each type of a category.
class _TypeChecksList extends StatelessWidget {
  const _TypeChecksList({required this.checks});

  final Map<HealthDataType, PermissionCheck> checks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final MapEntry(key: type, value: check) in checks.entries)
          Row(
            spacing: 12,
            children: [
              TypeIcon(type: type, size: 32),
              // The pill sits at the end where it fits and moves under the name on narrow screens.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(type.label, style: theme.textTheme.bodyMedium),
                    _pill(check.describe(isGroup: false)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  static Widget _pill(PermissionCheckView view) => StatusPill(label: view.label, tone: view.tone, icon: view.icon);
}
