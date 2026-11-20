/// A tile that shows one number (a metric) with its label, unit and icon, including while it loads or
/// when it could not be read.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import '../theme/expressive_typography.dart';
import 'expressive_card.dart';
import 'loading_indicator.dart';
import 'shaped_icon.dart';

/// A metric: a shaped [icon], a [label], a big emphasized [value] with its [unit], and a [footnote].
///
/// Each tile handles its own states: [loading] shows a loading indicator in place of the value, [error]
/// shows the problem instead, and a null [value] shows a dash (no data). Switching between the states
/// cross-fades and springs, and the icon morphs with it. Values shrink to fit narrow tiles. With [onTap]
/// the whole tile is a button.
class MetricTile extends StatelessWidget {
  /// Creates a metric tile.
  const MetricTile({
    super.key,
    required this.label,
    this.value,
    this.unit,
    required this.icon,
    this.shape = ExpressiveShape.cookie9,
    this.variant = ExpressiveCardVariant.filled,
    this.iconBackground,
    this.iconForeground,
    this.footnote,
    this.loading = false,
    this.error,
    this.onTap,
  });

  /// What the number is ("Steps today").
  final String label;

  /// The number, already formatted; null when there is no data.
  final String? value;

  /// The unit after the number ("bpm").
  final String? unit;

  /// The icon in the shape at the top.
  final IconData icon;

  /// The shape behind the icon.
  final ExpressiveShape shape;

  /// The card colour style.
  final ExpressiveCardVariant variant;

  /// Optional container colour behind [icon]; defaults to `ShapedIcon`'s primary container.
  final Color? iconBackground;

  /// Optional icon colour; defaults to `ShapedIcon`'s on-primary-container.
  final Color? iconForeground;

  /// A short line under the number, such as when it was measured.
  final String? footnote;

  /// Whether the value is being read.
  final bool loading;

  /// Why the value could not be read; shown instead of it.
  final String? error;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const motion = ExpressiveMotion.spatialDefault;
    return ExpressiveCard(
      variant: variant,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The icon is a plain circle while loading and springs into its shape when the value arrives;
          // an error turns it into the error colours.
          ShapedIcon(
            icon: icon,
            shape: loading ? ExpressiveShape.circle : shape,
            size: 40,
            background: error == null ? iconBackground : scheme.errorContainer,
            foreground: error == null ? iconForeground : scheme.onErrorContainer,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 44,
            child: AnimatedSwitcher(
              duration: motion.duration,
              switchInCurve: motion,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation.drive(ExpressiveMotion.clampToUnit),
                child: ScaleTransition(scale: animation.drive(Tween<double>(begin: 0.8, end: 1)), child: child),
              ),
              layoutBuilder: (current, previous) =>
                  Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
              child: _state(context),
            ),
          ),
          if (footnote case final footnote?)
            Text(
              footnote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  /// The value line for the current state, keyed so that the switcher animates state changes.
  Widget _state(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (loading) {
      return const ExpressiveLoadingIndicator(key: ValueKey('loading'), size: 36);
    }
    if (error case final error?) {
      return Row(
        key: const ValueKey('error'),
        spacing: 6,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          Expanded(
            child: Text(
              error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!.copyWith(color: scheme.error),
            ),
          ),
        ],
      );
    }
    return FittedBox(
      key: ValueKey('value:$value'),
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text.rich(
        TextSpan(
          text: value ?? '—',
          style: theme.textTheme.headlineLargeEmphasized.tabular.copyWith(color: scheme.onSurface),
          children: [
            if (unit != null && value != null)
              TextSpan(
                text: ' $unit',
                style: theme.textTheme.titleMedium!.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}
