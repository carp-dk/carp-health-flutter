/// Colour tokens of the Material 3 Expressive theme: the seed colour, the generated light and dark
/// [ColorScheme]s, and the status colours ([ExpressiveStatusColors]) that a scheme has no roles for.
library;

import 'package:flutter/material.dart';

/// The colour roles of the app's Material 3 Expressive theme.
///
/// Everything else takes its colours from the [ColorScheme] roles: the surface container roles
/// (`surfaceContainerLowest` up to `surfaceContainerHighest`) layer cards and lists on the page, and the
/// container roles (`primaryContainer`, `tertiaryContainer`) give the vibrant accents.
abstract final class ExpressiveColors {
  /// The seed of both schemes: a deep teal.
  static const Color seed = Color(0xFF00696E);

  /// The scheme for [brightness], generated from [seed] with [DynamicSchemeVariant.expressive], whose
  /// palettes are more colourful than the baseline's and whose secondary and tertiary hues move further
  /// away from the seed.
  static ColorScheme scheme(Brightness brightness) => ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  );
}

/// Container and on-container colours for statuses ("granted", "needs an update", "failed"), which the
/// [ColorScheme] has no roles for, as a [ThemeExtension] so that they follow light and dark mode and
/// animate with theme changes.
///
/// [success] and [warning] are tonal palettes of fixed green and amber seeds in the scheme's brightness;
/// [info], [error] and [neutral] reuse the scheme's own roles. Read them with [ExpressiveStatusColors.of].
@immutable
class ExpressiveStatusColors extends ThemeExtension<ExpressiveStatusColors> {
  /// Creates the status colours from explicit colours; [ExpressiveStatusColors.from] derives them.
  const ExpressiveStatusColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.error,
    required this.onError,
    required this.neutral,
    required this.onNeutral,
  });

  /// Derives the status colours that go with [scheme].
  factory ExpressiveStatusColors.from(ColorScheme scheme) {
    final success = ColorScheme.fromSeed(
      seedColor: _successSeed,
      brightness: scheme.brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );
    final warning = ColorScheme.fromSeed(
      seedColor: _warningSeed,
      brightness: scheme.brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    );
    return ExpressiveStatusColors(
      success: success.primaryContainer,
      onSuccess: success.onPrimaryContainer,
      warning: warning.primaryContainer,
      onWarning: warning.onPrimaryContainer,
      info: scheme.secondaryContainer,
      onInfo: scheme.onSecondaryContainer,
      error: scheme.errorContainer,
      onError: scheme.onErrorContainer,
      neutral: scheme.surfaceContainerHighest,
      onNeutral: scheme.onSurfaceVariant,
    );
  }

  static const Color _successSeed = Color(0xFF2E7D32);
  static const Color _warningSeed = Color(0xFFF9A825);

  /// The status colours of the ambient theme, or colours derived from its scheme when the theme was not
  /// built by `ExpressiveTheme` (in tests, for example).
  static ExpressiveStatusColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<ExpressiveStatusColors>() ?? ExpressiveStatusColors.from(theme.colorScheme);
  }

  /// Container and content colours for something that worked or is granted.
  final Color success, onSuccess;

  /// Container and content colours for something that needs attention but did not fail.
  final Color warning, onWarning;

  /// Container and content colours for neutral information.
  final Color info, onInfo;

  /// Container and content colours for failures.
  final Color error, onError;

  /// Container and content colours for unknown or not yet checked states.
  final Color neutral, onNeutral;

  @override
  ExpressiveStatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? error,
    Color? onError,
    Color? neutral,
    Color? onNeutral,
  }) => ExpressiveStatusColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    info: info ?? this.info,
    onInfo: onInfo ?? this.onInfo,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    neutral: neutral ?? this.neutral,
    onNeutral: onNeutral ?? this.onNeutral,
  );

  @override
  ExpressiveStatusColors lerp(ExpressiveStatusColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return ExpressiveStatusColors(
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      info: mix(info, other.info),
      onInfo: mix(onInfo, other.onInfo),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      neutral: mix(neutral, other.neutral),
      onNeutral: mix(onNeutral, other.onNeutral),
    );
  }
}
