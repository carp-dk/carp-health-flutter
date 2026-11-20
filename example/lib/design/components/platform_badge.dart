/// A badge marking something that exists on one platform only.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_typography.dart';

enum _Platform { android, ios }

/// A small outlined pill reading "Android only" or "iOS only", shown next to features that exist on one
/// platform only, so that the app explains them rather than hiding them.
class PlatformBadge extends StatelessWidget {
  /// A badge for something only Android (Health Connect) has.
  const PlatformBadge.android({super.key}) : _platform = _Platform.android;

  /// A badge for something only iOS (Apple Health) has.
  const PlatformBadge.ios({super.key}) : _platform = _Platform.ios;

  final _Platform _platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, label, semantics) = switch (_platform) {
      _Platform.android => (Icons.android, 'Android', 'Android only'),
      _Platform.ios => (Icons.apple, 'iOS', 'iOS only'),
    };
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: scheme.surfaceContainerHighest, shape: const StadiumBorder()),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              Text(label, style: theme.textTheme.labelMediumEmphasized.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
