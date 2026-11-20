/// The floating toolbar of Read > Changes: the sync actions, within reach however long the list of recent
/// changes gets.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'changes_controller.dart';

/// A [FloatingToolbar] shown on Android once a changes token exists: Fetch changes (`getChanges`, with
/// a loading indicator while a sync runs), Make a new token (`getChangesToken`) and Clear the local copy.
/// Place it with `FloatingActionButtonLocation.centerFloat`.
class ChangesToolbar extends StatelessWidget {
  /// Creates the toolbar acting on [controller].
  const ChangesToolbar({super.key, required this.controller});

  /// The Changes section's controller.
  final ChangesController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.isSupported && controller.token != null;
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
    final syncing = controller.sync.isLoading;
    return [
      IconButton.filledTonal(
        tooltip: 'Fetch changes',
        onPressed: controller.canSync ? controller.fetchChanges : null,
        icon: syncing
            ? const ExpressiveLoadingIndicator(size: 24, semanticsLabel: 'Fetching changes')
            : const Icon(Icons.sync),
      ),
      IconButton(
        tooltip: 'New token',
        onPressed: controller.canCreateToken ? controller.createToken : null,
        icon: const Icon(Icons.add_link),
      ),
      IconButton(
        tooltip: 'Clear the local copy',
        onPressed: controller.canClearLocalCopy ? controller.clearLocalCopy : null,
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ];
  }
}
