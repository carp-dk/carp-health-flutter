/// The gate of a write that needs an optional Health Connect feature, as the Mindfulness and Activity
/// intensity forms have.
library;

import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/write_recipe.dart';

/// Why the device [capabilities] describes cannot make a write that needs [feature] (one short line), or
/// null when it can.
///
/// Only Android can lack a feature: Health Connect added mindfulness sessions and activity intensity
/// after its first release (README, "Health Connect features"), and without them the plugin throws a
/// `HealthException` with `HealthErrorCode.notSupported`. The device lacks the feature when its check
/// (`RecipeFeature.check`) returned false. Until the feature checks have run, it says that they are running.
String? missingFeatureReason(RecipeFeature feature, PlatformCapabilities capabilities) {
  if (!capabilities.isAndroid || feature.availableIn(capabilities)) return null;
  return capabilities.isLoaded ? 'This Health Connect lacks ${feature.label}.' : 'Checking Health Connect…';
}
