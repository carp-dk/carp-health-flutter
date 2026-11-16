/// The app's Material 3 Expressive themes, light and dark.
library;

import 'package:flutter/material.dart';

import 'expressive_colors.dart';
import 'expressive_component_themes.dart';
import 'expressive_typography.dart';

/// Builds the light and dark Material 3 Expressive [ThemeData]: the expressive colour scheme
/// ([ExpressiveColors]), the complete type scale ([ExpressiveTypography]), the status colours
/// ([ExpressiveStatusColors]) and the component themes ([ExpressiveComponentThemes]).
///
/// Flutter has no Material 3 Expressive components yet (only the expressive scheme variant), so the
/// tokens live in `lib/design/theme` and the components in `lib/design/components`.
abstract final class ExpressiveTheme {
  /// The light theme.
  static ThemeData light() => fromScheme(ExpressiveColors.scheme(Brightness.light));

  /// The dark theme.
  static ThemeData dark() => fromScheme(ExpressiveColors.scheme(Brightness.dark));

  /// The expressive theme for any [scheme], for example a dynamic (wallpaper) scheme.
  static ThemeData fromScheme(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: ExpressiveTypography.textTheme(scheme),
      scaffoldBackgroundColor: scheme.surface,
      extensions: [ExpressiveStatusColors.from(scheme)],
    );
    return ExpressiveComponentThemes.apply(base);
  }
}
