/// Component themes of the Material 3 Expressive theme: surfaces (cards, sheets, dialogs, snack bars,
/// menus), inputs (text fields, chips, pickers, search), lists, and progress and selection controls.
/// Buttons and navigation have their own files; [ExpressiveComponentThemes.apply] wires them all in.
library;

import 'package:flutter/material.dart';

import 'expressive_button_themes.dart';
import 'expressive_navigation_themes.dart';
import 'expressive_shapes.dart';
import 'expressive_typography.dart';

/// Applies the expressive style to every Material component the app uses.
abstract final class ExpressiveComponentThemes {
  /// [base] with all component themes set; its colour scheme and (complete) text theme are used.
  static ThemeData apply(ThemeData base) {
    final scheme = base.colorScheme;
    final text = base.textTheme;
    return base.copyWith(
      filledButtonTheme: ExpressiveButtonThemes.filled(),
      outlinedButtonTheme: ExpressiveButtonThemes.outlined(),
      textButtonTheme: ExpressiveButtonThemes.text(),
      elevatedButtonTheme: ExpressiveButtonThemes.elevated(),
      iconButtonTheme: ExpressiveButtonThemes.icon(),
      floatingActionButtonTheme: ExpressiveButtonThemes.floatingActionButton(scheme),
      segmentedButtonTheme: ExpressiveButtonThemes.segmented(scheme),
      navigationBarTheme: ExpressiveNavigationThemes.navigationBar(scheme, text),
      navigationRailTheme: ExpressiveNavigationThemes.navigationRail(scheme, text),
      appBarTheme: ExpressiveNavigationThemes.appBar(scheme),
      pageTransitionsTheme: ExpressiveNavigationThemes.pageTransitions(),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHighest,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
        clipBehavior: Clip.antiAlias,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: ExpressiveShapes.top(ExpressiveShapes.extraLargeIncreased)),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
        titleTextStyle: text.headlineSmallEmphasized.copyWith(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium!.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.large),
        elevation: 3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.large),
      ),
      menuTheme: MenuThemeData(style: _menuStyle(scheme)),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: scheme.inverseSurface,
          shape: ExpressiveShapes.rounded(ExpressiveShapes.small),
        ),
        textStyle: text.bodySmall!.copyWith(color: scheme.onInverseSurface),
      ),
      inputDecorationTheme: _inputDecoration(scheme),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: _menuStyle(scheme),
        inputDecorationTheme: _inputDecoration(scheme),
      ),
      chipTheme: ChipThemeData(
        shape: ExpressiveShapes.stadium,
        labelStyle: text.labelLarge,
        selectedColor: scheme.secondaryContainer,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        shape: const WidgetStatePropertyAll(ExpressiveShapes.stadium),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
        headerHeadlineStyle: text.headlineLargeEmphasized,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge),
        hourMinuteShape: ExpressiveShapes.rounded(ExpressiveShapes.large),
        dayPeriodShape: ExpressiveShapes.rounded(ExpressiveShapes.medium),
      ),
      listTileTheme: ListTileThemeData(
        shape: ExpressiveShapes.rounded(ExpressiveShapes.large),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
        horizontalTitleGap: 16,
        iconColor: scheme.onSurfaceVariant,
        selectedColor: scheme.onSecondaryContainer,
        selectedTileColor: scheme.secondaryContainer,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: ExpressiveShapes.rounded(ExpressiveShapes.large),
        collapsedShape: ExpressiveShapes.rounded(ExpressiveShapes.large),
      ),
      carouselViewTheme: CarouselViewThemeData(shape: ExpressiveShapes.rounded(ExpressiveShapes.extraLarge)),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      progressIndicatorTheme: _progressIndicator(scheme),
      sliderTheme: _slider(),
      switchTheme: SwitchThemeData(
        // A check mark in the thumb of a switched-on switch, as Material 3 Expressive switches show.
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? const Icon(Icons.check_rounded) : null,
        ),
      ),
    );
  }

  /// Filled text fields: the container in the highest surface container colour with all corners
  /// [ExpressiveShapes.large], no line at rest and an underline in the primary colour while focused. The
  /// underline border (not an outline) keeps the floating label inside the container.
  static InputDecorationThemeData _inputDecoration(ColorScheme scheme) {
    UnderlineInputBorder field(BorderSide side) =>
        UnderlineInputBorder(borderRadius: ExpressiveShapes.radius(ExpressiveShapes.large), borderSide: side);
    return InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      border: field(BorderSide.none),
      enabledBorder: field(BorderSide.none),
      disabledBorder: field(BorderSide.none),
      focusedBorder: field(BorderSide(color: scheme.primary, width: 2)),
      errorBorder: field(BorderSide(color: scheme.error)),
      focusedErrorBorder: field(BorderSide(color: scheme.error, width: 2)),
    );
  }

  /// Menus (`MenuAnchor`, `DropdownMenu`): rounded [ExpressiveShapes.large] on the surface container.
  static MenuStyle _menuStyle(ColorScheme scheme) => MenuStyle(
    backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
    shape: WidgetStatePropertyAll(ExpressiveShapes.rounded(ExpressiveShapes.large)),
  );

  /// Progress indicators in the 2024 Material 3 look (rounded track, gap and stop indicator), which the
  /// app's own `WavyProgressIndicator` and `ExpressiveLoadingIndicator` match.
  static ProgressIndicatorThemeData _progressIndicator(ColorScheme scheme) => ProgressIndicatorThemeData(
    color: scheme.primary,
    linearTrackColor: scheme.secondaryContainer,
    circularTrackColor: scheme.secondaryContainer,
    refreshBackgroundColor: scheme.primaryContainer,
    // The flag is the only switch to the 2024 look in this Flutter version: its replacement properties
    // are ignored while it is true, and Flutter deprecated it before flipping its default.
    // ignore: deprecated_member_use
    year2023: false,
  );

  /// Sliders in the 2024 Material 3 look: a tall rounded track with a gap around the handle thumb.
  static SliderThemeData _slider() => const SliderThemeData(
    // As for the progress indicators, the flag is the only way to the 2024 look in this Flutter version.
    // ignore: deprecated_member_use
    year2023: false,
  );
}
