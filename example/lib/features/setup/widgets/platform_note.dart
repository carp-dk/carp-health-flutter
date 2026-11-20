/// The note that stands in for a part of the Setup page that only the other platform has.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'card_heading.dart';

/// An outlined one-line card with the platform's badge, a [title] and an info button with what the
/// plugin does on this platform instead ([message]), so the page names a one-platform feature rather than
/// hiding it.
class PlatformNote extends StatelessWidget {
  /// A note on something only Android (Health Connect) has.
  const PlatformNote.android({
    super.key,
    required this.title,
    required this.message,
    this.code,
    this.icon = Icons.android,
    this.showBadge = true,
  }) : _android = true;

  /// A note on something only iOS (HealthKit) has.
  const PlatformNote.ios({
    super.key,
    required this.title,
    required this.message,
    this.code,
    this.icon = Icons.apple,
    this.showBadge = true,
  }) : _android = false;

  /// What the feature is.
  final String title;

  /// What the plugin does on this platform instead, behind the info button.
  final String message;

  /// The plugin calls involved, shown in monospace above [message].
  final String? code;

  /// The icon in the shape at the start.
  final IconData icon;

  /// Whether the title carries the platform's badge; false where a section header already shows it.
  final bool showBadge;

  final bool _android;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: CardHeading(
        icon: ShapedIcon(
          icon: icon,
          shape: ExpressiveShape.clover4,
          size: 36,
          background: scheme.surfaceContainerHighest,
          foreground: scheme.onSurfaceVariant,
        ),
        title: title,
        badge: showBadge ? (_android ? const PlatformBadge.android() : const PlatformBadge.ios()) : null,
      ),
    );
  }
}
