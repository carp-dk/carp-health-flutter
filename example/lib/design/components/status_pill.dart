/// A small pill that shows a status ("Granted", "Not installed") in a colour that says how it is.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_colors.dart';
import '../theme/expressive_motion.dart';
import '../theme/expressive_shapes.dart';
import '../theme/expressive_typography.dart';

/// How a status reads, which picks a [StatusPill]'s colours from [ExpressiveStatusColors].
enum StatusTone {
  /// Worked, available or granted.
  success,

  /// Needs attention: an update, a missing optional feature.
  warning,

  /// Failed, denied or unavailable.
  error,

  /// Neutral information.
  info,

  /// Unknown or not checked yet.
  neutral;

  /// The container and content colours of this tone in [colors].
  (Color background, Color foreground) colorsIn(ExpressiveStatusColors colors) => switch (this) {
    success => (colors.success, colors.onSuccess),
    warning => (colors.warning, colors.onWarning),
    error => (colors.error, colors.onError),
    info => (colors.info, colors.onInfo),
    neutral => (colors.neutral, colors.onNeutral),
  };
}

/// A stadium-shaped status label with an optional leading [icon], coloured by [tone]. A change of tone
/// fades the colours over on the default effects spring.
class StatusPill extends StatelessWidget {
  /// Creates a status pill.
  const StatusPill({super.key, required this.label, this.tone = StatusTone.neutral, this.icon});

  /// The status, in a word or two.
  final String label;

  /// How the status reads.
  final StatusTone tone;

  /// An icon before the label.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = tone.colorsIn(ExpressiveStatusColors.of(context));
    const motion = ExpressiveMotion.effectsDefault;
    return AnimatedContainer(
      duration: motion.duration,
      curve: motion,
      padding: EdgeInsetsDirectional.fromSTEB(icon == null ? 10 : 8, 4, 10, 4),
      decoration: ShapeDecoration(color: background, shape: ExpressiveShapes.stadium),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          if (icon case final icon?) Icon(icon, size: 15, color: foreground),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMediumEmphasized.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
