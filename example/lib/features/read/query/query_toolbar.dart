/// The floating toolbar of Read > Query: the actions on the results, always within reach however far the
/// list is scrolled.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/design/design.dart';

import 'query_controller.dart';
import 'query_result.dart';

/// A [FloatingToolbar] shown once there are results or a read runs: Read again (or Cancel while a page by
/// page read runs), Remove duplicates (`Health.removeDuplicates`), Newest first and Oldest first (toggles;
/// off shows the plugin's order) and Clear. Place it with `FloatingActionButtonLocation.centerFloat`.
class QueryToolbar extends StatelessWidget {
  /// Creates the toolbar acting on [controller].
  const QueryToolbar({super.key, required this.controller});

  /// The Query section's controller.
  final QueryController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.result.valueOrNull != null || controller.isReading;
        const motion = ExpressiveMotion.effectsDefault;
        return AnimatedSwitcher(
          duration: motion.duration,
          switchInCurve: motion,
          switchOutCurve: motion,
          child: visible
              ? FloatingToolbar(key: const ValueKey('toolbar'), children: _actions(context))
              : const SizedBox.shrink(key: ValueKey('hidden')),
        );
      },
    );
  }

  List<Widget> _actions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = controller.result;
    final data = result is AsyncData<QueryResult> ? result.value : null;
    final order = data?.order ?? SortOrder.asReturned;
    // Selected toggles invert the toolbar's colours, so the active order stands out on the vibrant pill.
    final toggle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : null,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? scheme.onPrimaryContainer.withValues(alpha: 0.38)
            : states.contains(WidgetState.selected)
            ? scheme.primaryContainer
            : scheme.onPrimaryContainer,
      ),
    );
    void sort(SortOrder wanted) => controller.sortBy(order == wanted ? SortOrder.asReturned : wanted);
    return [
      if (controller.canCancel || controller.isCancelling)
        IconButton.filledTonal(
          tooltip: 'Cancel the read',
          onPressed: controller.canCancel ? controller.cancel : null,
          icon: const Icon(Icons.stop_rounded),
        )
      else
        IconButton.filledTonal(
          tooltip: 'Read again',
          onPressed: controller.canRead ? controller.read : null,
          icon: const Icon(Icons.refresh),
        ),
      IconButton(
        tooltip: 'Remove duplicates',
        onPressed: data == null || data.points.isEmpty ? null : controller.removeDuplicates,
        icon: const Icon(Icons.layers_clear_outlined),
      ),
      IconButton(
        tooltip: 'Newest first',
        style: toggle,
        isSelected: order == SortOrder.newestFirst,
        onPressed: data == null ? null : () => sort(SortOrder.newestFirst),
        icon: const Icon(Icons.arrow_downward),
      ),
      IconButton(
        tooltip: 'Oldest first',
        style: toggle,
        isSelected: order == SortOrder.oldestFirst,
        onPressed: data == null ? null : () => sort(SortOrder.oldestFirst),
        icon: const Icon(Icons.arrow_upward),
      ),
      IconButton(
        tooltip: 'Clear the results',
        onPressed: data == null ? null : controller.clear,
        icon: const Icon(Icons.clear_all),
      ),
    ];
  }
}
