/// The placeholder a screen shows when there is nothing to show (yet).
library;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import '../theme/expressive_typography.dart';
import 'shaped_icon.dart';

/// A centred empty state: a large shaped [icon] that springs in, a [title], an optional [message] that
/// explains why there is nothing (and what to do about it) and an optional [action].
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.shape = ExpressiveShape.softBurst,
  });

  /// The icon in the shape.
  final IconData icon;

  /// What is empty, in a few words.
  final String title;

  /// Why it is empty, or what to do.
  final String? message;

  /// A button that helps, such as "Request access".
  final Widget? action;

  /// The shape behind the icon.
  final ExpressiveShape shape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const motion = ExpressiveMotion.spatialDefault;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.6, end: 1),
                duration: motion.duration,
                curve: motion,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: ShapedIcon(
                  icon: icon,
                  shape: shape,
                  size: 96,
                  background: scheme.tertiaryContainer,
                  foreground: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLargeEmphasized.copyWith(color: scheme.onSurface),
              ),
              if (message case final message?) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (action case final action?) ...[const SizedBox(height: 20), action],
            ],
          ),
        ),
      ),
    );
  }
}
