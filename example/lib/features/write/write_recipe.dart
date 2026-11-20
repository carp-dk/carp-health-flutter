/// The model behind the Write feature's catalogue: a [WriteRecipe] is one write method of the plugin
/// (or a family of them, such as `writeHealthData` and `writeHealthDataUUID`), with what the app needs
/// to show it, decide whether it works on this device, and open its form.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/design/design.dart';

/// The recipes of the Write page, one per write method (family) of the plugin.
enum WriteRecipeId {
  /// `writeHealthData` and `writeHealthDataUUID`.
  measurement,

  /// `writeBloodPressure`.
  bloodPressure,

  /// `writeBloodOxygen`.
  bloodOxygen,

  /// `writeMeal`.
  meal,

  /// `writeWorkoutData` and `writeWorkoutDataUUID`.
  workout,

  /// `startWorkoutRoute`, `insertWorkoutRouteData`, `finishWorkoutRoute` and `discardWorkoutRoute`.
  workoutRoute,

  /// `writeSleepSession`.
  sleepSession,

  /// `writeMindfulnessSession`.
  mindfulness,

  /// `writeMenstruationFlow`.
  menstruationFlow,

  /// `writeSexualActivity`.
  sexualActivity,

  /// `writeInsulinDelivery` (iOS).
  insulinDelivery,

  /// `writeAudiogram` (iOS).
  audiogram,

  /// `writeActivityIntensity` (Android).
  activityIntensity,
}

/// A Health Connect feature that a recipe needs on Android, where older Health Connect versions lack
/// it (README, "Health Connect features"). Without it the plugin throws `HealthErrorCode.notSupported`.
enum RecipeFeature {
  /// Mindfulness sessions, checked with `isMindfulnessSessionAvailable` (always true on iOS).
  mindfulness('mindfulness sessions', 'isMindfulnessSessionAvailable'),

  /// Activity intensity records, checked with `isActivityIntensityAvailable` (false on iOS).
  activityIntensity('activity intensity', 'isActivityIntensityAvailable');

  const RecipeFeature(this.label, this.check);

  /// What the feature is, such as "mindfulness sessions".
  final String label;

  /// The plugin method that tells whether the device has the feature.
  final String check;

  /// Whether the device has the feature, as [PlatformCapabilities] last read it from the plugin.
  bool availableIn(PlatformCapabilities capabilities) => switch (this) {
    RecipeFeature.mindfulness => capabilities.mindfulnessAvailable,
    RecipeFeature.activityIntensity => capabilities.activityIntensityAvailable,
  };
}

/// One entry of the Write catalogue: what it writes, with which plugin [methods], where it works and
/// the form ([builder]) that writes it.
///
/// Recipes that do not work on this device stay in the catalogue, marked with the reason
/// ([unavailableReason]) and a `PlatformBadge`, so the app explains platform differences instead of
/// hiding them.
@immutable
class WriteRecipe {
  /// Creates a recipe. Without [platforms] it works on both Health Connect and Apple Health.
  const WriteRecipe({
    required this.id,
    required this.title,
    required this.description,
    required this.methods,
    required this.icon,
    required this.shape,
    required this.category,
    required this.types,
    required this.builder,
    this.platforms = bothPlatforms,
    this.feature,
  });

  /// Both health platforms.
  static const Set<HealthPlatformType> bothPlatforms = {
    HealthPlatformType.googleHealthConnect,
    HealthPlatformType.appleHealth,
  };

  /// Which recipe this is.
  final WriteRecipeId id;

  /// The recipe's name, such as "Blood pressure".
  final String title;

  /// What the methods write and how each platform stores it, for the info button of the form page.
  final String description;

  /// The plugin methods the form calls, such as `writeBloodPressure`; the first is the main one, shown
  /// in the catalogue and on the form page.
  final List<String> methods;

  /// The icon on the recipe's card and page.
  final IconData icon;

  /// The expressive shape behind [icon].
  final ExpressiveShape shape;

  /// The category whose colours the icon takes (see `TypeCategoryVisuals`), so a recipe looks like the
  /// data it writes elsewhere in the app.
  final TypeCategory category;

  /// The data types the recipe writes; each must be supported here ([PlatformCapabilities.supports]).
  final List<HealthDataType> types;

  /// Builds the recipe's form. Forms are content, not pages: `RecipeFormPage` places the form in its
  /// scrolling page and provides the `Scaffold` its snack bars show on.
  final WidgetBuilder builder;

  /// The platforms whose plugin implementation has the methods.
  final Set<HealthPlatformType> platforms;

  /// The Health Connect feature the recipe needs on Android, or null.
  final RecipeFeature? feature;

  /// The one platform that has the recipe, or null when both have it: the platform of its badge.
  HealthPlatformType? get onlyOn => platforms.length == 1 ? platforms.single : null;

  /// Why the recipe cannot be used on the device [capabilities] describes, in a few words, or null when
  /// it can.
  ///
  /// It checks, in order, the platform, the Health Connect [feature] and every type of [types] (which
  /// also covers types that need a newer iOS).
  String? unavailableReason(PlatformCapabilities capabilities) {
    final platform = capabilities.platform;
    if (platform == null) return 'Android and iOS only';
    if (!platforms.contains(platform)) {
      return switch (onlyOn) {
        HealthPlatformType.appleHealth => 'Apple Health only',
        HealthPlatformType.googleHealthConnect => 'Health Connect only',
        null => 'Not available in ${capabilities.platformName}',
      };
    }
    final feature = this.feature;
    // On iOS the feature checks answer without a platform call, so only Android can lack a feature.
    if (feature != null && capabilities.isAndroid && !feature.availableIn(capabilities)) {
      return capabilities.isLoaded ? 'No ${feature.label} in this Health Connect' : 'Checking Health Connect…';
    }
    for (final type in types) {
      if (capabilities.unsupportedReason(type) case final reason?) return '${type.name}: $reason';
    }
    return null;
  }

  /// Whether the recipe can be used on the device [capabilities] describes.
  bool isAvailableIn(PlatformCapabilities capabilities) => unavailableReason(capabilities) == null;

  @override
  String toString() => 'WriteRecipe(${id.name})';
}
