/// The Material 3 Expressive type scale: the baseline Material 3 scale plus emphasized variants.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Builds the app's text theme and the emphasized styles that Material 3 Expressive adds to the type
/// scale for headlines, big numbers and selected labels.
abstract final class ExpressiveTypography {
  /// The weight steps an emphasized style adds (+200: regular becomes semi-bold, medium becomes bold).
  static const int emphasisWeight = 200;

  /// The complete Material 3 (2021) text theme for [scheme]: platform font, colours and sizes.
  ///
  /// `ThemeData` keeps the sizes (the "geometry") apart and only merges them in when `Theme.of` localizes
  /// the theme; merging them here gives complete styles that the component themes can use directly.
  static TextTheme textTheme(ColorScheme scheme, {TargetPlatform? platform}) {
    final typography = Typography.material2021(platform: platform ?? defaultTargetPlatform, colorScheme: scheme);
    final colours = scheme.brightness == Brightness.dark ? typography.white : typography.black;
    return typography.englishLike.merge(colours);
  }

  /// The emphasized variant of [style]: [emphasisWeight] heavier and, from headline sizes up (24 sp),
  /// tracked slightly tighter so big type reads as one shape.
  static TextStyle emphasized(TextStyle style) {
    final size = style.fontSize ?? 14;
    return style.copyWith(
      fontWeight: heavier(style.fontWeight ?? FontWeight.w400),
      letterSpacing: size >= 24 ? math.min(style.letterSpacing ?? 0, 0) - (size >= 45 ? 0.5 : 0.25) : null,
    );
  }

  /// [weight] made heavier by [by] weight units, at most [FontWeight.w900].
  static FontWeight heavier(FontWeight weight, {int by = emphasisWeight}) =>
      FontWeight(math.min(weight.value + by, FontWeight.w900.value));
}

/// The emphasized styles of a [TextTheme], named as in the Material 3 Expressive type scale
/// (`Theme.of(context).textTheme.headlineLargeEmphasized`). Each is [ExpressiveTypography.emphasized]
/// applied to the baseline style, so it keeps the theme's colour and font.
extension EmphasizedTextTheme on TextTheme {
  /// Display large, emphasized: hero numbers.
  TextStyle get displayLargeEmphasized => ExpressiveTypography.emphasized(displayLarge!);

  /// Display medium, emphasized.
  TextStyle get displayMediumEmphasized => ExpressiveTypography.emphasized(displayMedium!);

  /// Display small, emphasized: big metric values.
  TextStyle get displaySmallEmphasized => ExpressiveTypography.emphasized(displaySmall!);

  /// Headline large, emphasized: metric values in tiles.
  TextStyle get headlineLargeEmphasized => ExpressiveTypography.emphasized(headlineLarge!);

  /// Headline medium, emphasized: page titles.
  TextStyle get headlineMediumEmphasized => ExpressiveTypography.emphasized(headlineMedium!);

  /// Headline small, emphasized: dialog and sheet titles.
  TextStyle get headlineSmallEmphasized => ExpressiveTypography.emphasized(headlineSmall!);

  /// Title large, emphasized: section headers.
  TextStyle get titleLargeEmphasized => ExpressiveTypography.emphasized(titleLarge!);

  /// Title medium, emphasized: card titles.
  TextStyle get titleMediumEmphasized => ExpressiveTypography.emphasized(titleMedium!);

  /// Title small, emphasized.
  TextStyle get titleSmallEmphasized => ExpressiveTypography.emphasized(titleSmall!);

  /// Label large, emphasized: selected buttons and pills.
  TextStyle get labelLargeEmphasized => ExpressiveTypography.emphasized(labelLarge!);

  /// Label medium, emphasized: selected navigation labels.
  TextStyle get labelMediumEmphasized => ExpressiveTypography.emphasized(labelMedium!);

  /// Body large, emphasized.
  TextStyle get bodyLargeEmphasized => ExpressiveTypography.emphasized(bodyLarge!);

  /// Body medium, emphasized.
  TextStyle get bodyMediumEmphasized => ExpressiveTypography.emphasized(bodyMedium!);
}
