/// Corner radius tokens of the Material 3 Expressive shape scale, and the shapes built from them.
library;

import 'package:flutter/material.dart';

/// The Material 3 Expressive corner radius scale, in logical pixels, with helpers that turn the tokens
/// into [BorderRadius]es and [OutlinedBorder]s.
///
/// The app uses them consistently: cards [extraLarge], sheets and dialogs [extraLarge] to
/// [extraLargeIncreased], text fields [large], and buttons fully rounded ([stadium]) morphing to [medium]
/// corners while pressed ([morphingButtonShape]).
abstract final class ExpressiveShapes {
  /// Square corners.
  static const double none = 0;

  /// 4 dp: the inner corners of segmented lists, small badges.
  static const double extraSmall = 4;

  /// 8 dp: the inner corners of connected button groups, chips' inner shapes.
  static const double small = 8;

  /// 12 dp: pressed buttons, small FABs.
  static const double medium = 12;

  /// 16 dp: text fields, FABs, snack bars, menus.
  static const double large = 16;

  /// 20 dp: the outer corners of segmented lists, pressed cards.
  static const double largeIncreased = 20;

  /// 28 dp: cards, dialogs, bottom sheets.
  static const double extraLarge = 28;

  /// 32 dp: large sheets.
  static const double extraLargeIncreased = 32;

  /// 48 dp: hero surfaces.
  static const double extraExtraLarge = 48;

  /// Fully rounded ends (the "full" token): half the height of whatever it shapes. Use this rather than a
  /// huge radius, which would not morph evenly into rounded rectangles.
  static const StadiumBorder stadium = StadiumBorder();

  /// All four corners rounded by [value].
  static BorderRadius radius(double value) => BorderRadius.all(Radius.circular(value));

  /// Only the top corners rounded by [value], as on bottom sheets.
  static BorderRadius top(double value) => BorderRadius.vertical(top: Radius.circular(value));

  /// A rounded rectangle with [value] corners and an optional outline [side].
  static RoundedRectangleBorder rounded(double value, {BorderSide side = BorderSide.none}) =>
      RoundedRectangleBorder(borderRadius: radius(value), side: side);

  /// The expressive button shape: [stadium] at rest, morphing to [pressedRadius] corners while pressed.
  ///
  /// With [squareWhenSelected] a selected toggle (an `IconButton` with `isSelected: true`) keeps the
  /// squarer shape too, as Material 3 Expressive toggle buttons do. `Material` animates between the two
  /// shapes, and Flutter can interpolate a [StadiumBorder] into a [RoundedRectangleBorder] smoothly.
  static WidgetStateProperty<OutlinedBorder?> morphingButtonShape({
    double pressedRadius = medium,
    bool squareWhenSelected = false,
  }) => WidgetStateProperty.resolveWith((states) {
    final squared =
        states.contains(WidgetState.pressed) || (squareWhenSelected && states.contains(WidgetState.selected));
    return squared ? rounded(pressedRadius) : stadium;
  });
}
