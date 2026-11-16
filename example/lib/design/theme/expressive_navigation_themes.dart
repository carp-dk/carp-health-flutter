/// Navigation themes of the Material 3 Expressive theme: navigation bar and rail with pill indicators and
/// emphasized labels, the app bar, and the platform page transitions.
library;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'expressive_shapes.dart';
import 'expressive_typography.dart';

/// Builds the themes of the navigation components and the page transitions.
abstract final class ExpressiveNavigationThemes {
  /// The bottom `NavigationBar` of compact windows: a pill indicator in the secondary container colour
  /// behind the selected icon, and an emphasized label under it.
  static NavigationBarThemeData navigationBar(ColorScheme scheme, TextTheme text) => NavigationBarThemeData(
    height: 76,
    elevation: 0,
    backgroundColor: scheme.surfaceContainer,
    indicatorColor: scheme.secondaryContainer,
    indicatorShape: ExpressiveShapes.stadium,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? text.labelMediumEmphasized.copyWith(color: scheme.onSurface)
          : text.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        size: 24,
        color: states.contains(WidgetState.selected) ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
      ),
    ),
  );

  /// The `NavigationRail` of medium and expanded windows, matching [navigationBar]. The label type is left
  /// to the rail itself, because an extended rail must not show labels under its icons.
  static NavigationRailThemeData navigationRail(ColorScheme scheme, TextTheme text) => NavigationRailThemeData(
    elevation: 0,
    backgroundColor: scheme.surfaceContainer,
    useIndicator: true,
    indicatorColor: scheme.secondaryContainer,
    indicatorShape: ExpressiveShapes.stadium,
    groupAlignment: -0.85,
    selectedLabelTextStyle: text.labelMediumEmphasized.copyWith(color: scheme.onSurface),
    unselectedLabelTextStyle: text.labelMedium!.copyWith(color: scheme.onSurfaceVariant),
    selectedIconTheme: IconThemeData(size: 24, color: scheme.onSecondaryContainer),
    unselectedIconTheme: IconThemeData(size: 24, color: scheme.onSurfaceVariant),
  );

  /// App bars: flat on the surface at rest, tinted with the surface container colour once content
  /// scrolls under them.
  ///
  /// No title style is set on purpose: for `SliverAppBar.large` a theme title style would replace the
  /// large expanded title by the small collapsed one; `ExpressivePage` emphasizes its titles itself.
  static AppBarThemeData appBar(ColorScheme scheme) => AppBarThemeData(
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: WidgetStateColor.resolveWith(
      (states) => states.contains(WidgetState.scrolledUnder) ? scheme.surfaceContainer : scheme.surface,
    ),
    foregroundColor: scheme.onSurface,
    surfaceTintColor: Colors.transparent,
  );

  /// Page transitions: Android's predictive back transition (the page follows the back gesture) and the
  /// Cupertino slide on Apple platforms.
  static PageTransitionsTheme pageTransitions() => const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );
}
