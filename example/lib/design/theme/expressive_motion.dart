/// Material 3 Expressive motion: the six springs of the expressive motion scheme as animation [Curve]s,
/// with the durations to use them over.
library;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A spring that moves from 0 to 1, usable wherever Flutter takes a [Curve] (implicit animations,
/// `AnimationController.animateTo`, transitions) together with its [duration].
///
/// The spring has unit mass, the given [stiffness] and [dampingRatio], and starts at rest. A damping
/// ratio below 1 overshoots and settles back (the bouncy "spatial" springs); a ratio of 1 never
/// overshoots (the "effects" springs for colour and opacity). The curve follows a [SpringSimulation]
/// in real time over [duration], by which the spring has settled to within a fraction of a percent.
class SpringCurve extends Curve {
  /// Creates the curve of a spring with [stiffness] and [dampingRatio], played over [duration].
  const SpringCurve({required this.dampingRatio, required this.stiffness, required this.duration});

  /// The damping ratio: below 1 bounces, 1 is critically damped.
  final double dampingRatio;

  /// The stiffness of the spring, for unit mass.
  final double stiffness;

  /// How long animations with this curve should run: about the spring's settling time.
  final Duration duration;

  /// The spring itself, for physics-driven animations.
  SpringDescription get description =>
      SpringDescription.withDampingRatio(mass: 1, stiffness: stiffness, ratio: dampingRatio);

  /// A simulation of this spring from [from] to [to], starting at [velocity] (units per second): use it
  /// with `AnimationController.animateWith` to keep the momentum of an interrupted animation. It snaps
  /// exactly to [to] when it has settled.
  SpringSimulation simulation({double from = 0, double to = 1, double velocity = 0}) =>
      SpringSimulation(description, from, to, velocity, snapToEnd: true);

  @override
  double transformInternal(double t) {
    final spring = SpringSimulation(description, 0, 1, 0);
    final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
    // By [duration] the spring is within a fraction of a percent of 1; spreading that last difference
    // over the curve makes it end exactly at 1, as a Curve must, without a visible jump.
    return spring.x(t * seconds) + t * (1 - spring.x(seconds));
  }

  @override
  String toString() => 'SpringCurve(dampingRatio: $dampingRatio, stiffness: $stiffness)';
}

/// The springs of the Material 3 Expressive motion scheme.
///
/// Use the spatial springs for anything that moves or changes size or shape (they overshoot a little,
/// which makes the motion feel physical) and the effects springs for colour and opacity (they never
/// overshoot). Fast springs suit small elements such as buttons and switches, default springs most
/// components, slow springs large surfaces such as sheets and full-screen transitions. Each curve carries
/// its [SpringCurve.duration]:
///
/// ```dart
/// AnimatedContainer(
///   duration: ExpressiveMotion.spatialDefault.duration,
///   curve: ExpressiveMotion.spatialDefault,
///   ...
/// )
/// ```
abstract final class ExpressiveMotion {
  /// Duration of [spatialFast].
  static const Duration spatialFastDuration = Duration(milliseconds: 350);

  /// Duration of [spatialDefault].
  static const Duration spatialDefaultDuration = Duration(milliseconds: 500);

  /// Duration of [spatialSlow].
  static const Duration spatialSlowDuration = Duration(milliseconds: 650);

  /// Duration of [effectsFast].
  static const Duration effectsFastDuration = Duration(milliseconds: 150);

  /// Duration of [effectsDefault].
  static const Duration effectsDefaultDuration = Duration(milliseconds: 200);

  /// Duration of [effectsSlow].
  static const Duration effectsSlowDuration = Duration(milliseconds: 300);

  /// Bouncy and quick: pressed buttons, toggles, small shape morphs (damping 0.6, stiffness 800).
  static const SpringCurve spatialFast = SpringCurve(dampingRatio: 0.6, stiffness: 800, duration: spatialFastDuration);

  /// The default for moving, resizing and reshaping components (damping 0.8, stiffness 380).
  static const SpringCurve spatialDefault = SpringCurve(
    dampingRatio: 0.8,
    stiffness: 380,
    duration: spatialDefaultDuration,
  );

  /// Large surfaces and page-level motion (damping 0.8, stiffness 200).
  static const SpringCurve spatialSlow = SpringCurve(dampingRatio: 0.8, stiffness: 200, duration: spatialSlowDuration);

  /// Quick colour and opacity changes, such as pressed and hovered states (damping 1, stiffness 3800).
  static const SpringCurve effectsFast = SpringCurve(dampingRatio: 1, stiffness: 3800, duration: effectsFastDuration);

  /// The default for colour and opacity changes (damping 1, stiffness 1600).
  static const SpringCurve effectsDefault = SpringCurve(
    dampingRatio: 1,
    stiffness: 1600,
    duration: effectsDefaultDuration,
  );

  /// Slow fades, such as content appearing after a load (damping 1, stiffness 800).
  static const SpringCurve effectsSlow = SpringCurve(dampingRatio: 1, stiffness: 800, duration: effectsSlowDuration);

  /// Whether the user asked the platform to reduce motion; components then skip decorative movement.
  static bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Clamps an animation that a spatial spring drives (and so overshoots) to 0..1, for an opacity:
  /// `FadeTransition(opacity: animation.drive(ExpressiveMotion.clampToUnit), ...)`. A [Curve] cannot do
  /// this, as curves only accept values from 0 to 1.
  static const Animatable<double> clampToUnit = _ClampToUnit();
}

class _ClampToUnit extends Animatable<double> {
  const _ClampToUnit();

  @override
  double transform(double t) => t.clamp(0.0, 1.0);
}
