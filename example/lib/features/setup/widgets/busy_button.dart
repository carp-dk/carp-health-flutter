/// The button of a Setup action that calls the plugin, showing the call's progress.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// The Material button a [BusyButton] is drawn as.
enum BusyButtonKind {
  /// `FilledButton`: the main action of a card.
  filled,

  /// `FilledButton.tonal`: a secondary action.
  tonal,

  /// `OutlinedButton`: a rare or destructive action.
  outlined,
}

/// A button whose plugin call is in progress while [busy]: it is disabled then and its icon turns into
/// an [ExpressiveLoadingIndicator], so the call cannot be sent twice.
///
/// The progress comes from the controller's `AsyncValue` rather than from the button, so it also shows
/// when the same call was started elsewhere (the page's menu, pull to refresh).
class BusyButton extends StatelessWidget {
  /// Creates a button that runs [onPressed]; null disables it.
  const BusyButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.kind = BusyButtonKind.filled,
    this.style,
  });

  /// What the button does, such as "Request access".
  final String label;

  /// The icon before the label.
  final IconData icon;

  /// Starts the call.
  final VoidCallback? onPressed;

  /// Whether the call runs.
  final bool busy;

  /// The label while [busy], such as "Waiting for Health Connect…"; [label] by default.
  final String? busyLabel;

  /// The kind of button.
  final BusyButtonKind kind;

  /// Overrides of the theme's button style, such as error colours for a destructive action.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const motion = ExpressiveMotion.spatialFast;
    final iconWidget = AnimatedSwitcher(
      duration: motion.duration,
      switchInCurve: motion,
      switchOutCurve: ExpressiveMotion.effectsFast,
      child: busy
          ? ExpressiveLoadingIndicator(
              key: const ValueKey('busy'),
              size: 22,
              color: scheme.primary,
              semanticsLabel: busyLabel ?? label,
            )
          : Icon(icon, key: const ValueKey('idle')),
    );
    final text = Text(busy ? (busyLabel ?? label) : label, overflow: TextOverflow.ellipsis);
    final pressed = busy ? null : onPressed;
    return switch (kind) {
      BusyButtonKind.filled => FilledButton.icon(style: style, onPressed: pressed, icon: iconWidget, label: text),
      BusyButtonKind.tonal => FilledButton.tonalIcon(style: style, onPressed: pressed, icon: iconWidget, label: text),
      BusyButtonKind.outlined => OutlinedButton.icon(style: style, onPressed: pressed, icon: iconWidget, label: text),
    };
  }
}
