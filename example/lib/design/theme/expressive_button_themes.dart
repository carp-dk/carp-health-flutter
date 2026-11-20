/// Button themes of the Material 3 Expressive theme: every button is fully rounded at rest and morphs to
/// squarer corners while it is pressed.
library;

import 'package:flutter/material.dart';

import 'expressive_motion.dart';
import 'expressive_shapes.dart';

/// Builds the themes of Flutter's buttons (filled and tonal, outlined, text, elevated, icon and floating
/// action buttons) in the expressive style.
abstract final class ExpressiveButtonThemes {
  /// The style all buttons share: [ExpressiveShapes.morphingButtonShape], animated by `Material` over a
  /// quick effects duration so the press morph keeps up with a tap.
  static ButtonStyle get _morphing => ButtonStyle(
    shape: ExpressiveShapes.morphingButtonShape(),
    animationDuration: ExpressiveMotion.effectsDefaultDuration,
  );

  /// `FilledButton` and `FilledButton.tonal`: the primary and the tonal call to action.
  static FilledButtonThemeData filled() => FilledButtonThemeData(style: _morphing);

  /// `OutlinedButton`: medium-emphasis actions; keeps the default outline.
  static OutlinedButtonThemeData outlined() => OutlinedButtonThemeData(style: _morphing);

  /// `TextButton`: low-emphasis actions; the shape shows in its press highlight.
  static TextButtonThemeData text() => TextButtonThemeData(style: _morphing);

  /// `ElevatedButton`, for completeness: the app prefers tonal buttons.
  static ElevatedButtonThemeData elevated() => ElevatedButtonThemeData(style: _morphing);

  /// `IconButton` and its filled, tonal and outlined variants: round at rest, square while pressed, and
  /// square while selected when used as a toggle (`isSelected: true`).
  static IconButtonThemeData icon() => IconButtonThemeData(
    style: ButtonStyle(
      shape: ExpressiveShapes.morphingButtonShape(squareWhenSelected: true),
      animationDuration: ExpressiveMotion.effectsDefaultDuration,
    ),
  );

  /// Floating action buttons in the tonal primary container colour, sitting a little lower than the
  /// baseline (elevation 3 instead of 6) on the flatter, tonal expressive surfaces.
  ///
  /// The shape is left to the Material 3 defaults on purpose: they already pick the expressive corner per
  /// size (12 dp small, 16 dp regular and extended, 28 dp large), which one theme shape would flatten.
  static FloatingActionButtonThemeData floatingActionButton(ColorScheme scheme) => FloatingActionButtonThemeData(
    backgroundColor: scheme.primaryContainer,
    foregroundColor: scheme.onPrimaryContainer,
    elevation: 3,
    focusElevation: 3,
    hoverElevation: 4,
    highlightElevation: 3,
  );

  /// `SegmentedButton`, which the app replaces by `ConnectedButtonGroup` but which stays consistent if a
  /// screen uses it: fully rounded, with the selected segment in the secondary container colour.
  static SegmentedButtonThemeData segmented(ColorScheme scheme) => SegmentedButtonThemeData(
    style: ButtonStyle(
      shape: const WidgetStatePropertyAll(ExpressiveShapes.stadium),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? scheme.secondaryContainer : null,
      ),
    ),
  );
}
