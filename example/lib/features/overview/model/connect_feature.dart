/// The optional Health Connect features the overview lists, and how each one stands on this device.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';

/// The state of one feature on this device: a short [label] and its [tone].
typedef FeatureState = ({String label, StatusTone tone});

/// An optional Health Connect feature (README, "Health Connect features"), checked by the plugin's
/// `is...Available` and `is...Authorized` methods, which `PlatformCapabilities.refresh` calls.
enum ConnectFeature {
  /// Reading data older than 30 days: `isHealthDataHistoryAvailable` and
  /// `isHealthDataHistoryAuthorized`.
  history('History (30+ days)', Icons.history, 'isHealthDataHistoryAvailable / ...Authorized'),

  /// Reading in the background: `isHealthDataInBackgroundAvailable` and
  /// `isHealthDataInBackgroundAuthorized`.
  background('Background reads', Icons.nights_stay, 'isHealthDataInBackgroundAvailable / ...Authorized'),

  /// The `SKIN_TEMPERATURE` type: `isSkinTemperatureAvailable`.
  skinTemperature('Skin temperature', Icons.thermostat, 'isSkinTemperatureAvailable'),

  /// The `MINDFULNESS` type: `isMindfulnessSessionAvailable`.
  mindfulness('Mindfulness', Icons.self_improvement, 'isMindfulnessSessionAvailable'),

  /// The `ACTIVITY_INTENSITY` type: `isActivityIntensityAvailable`.
  activityIntensity('Activity intensity', Icons.speed, 'isActivityIntensityAvailable');

  const ConnectFeature(this.label, this.icon, this.methods);

  /// The feature's name in a few words.
  final String label;

  /// An icon for the feature.
  final IconData icon;

  /// The plugin methods that check it.
  final String methods;

  /// How the feature stands on the device [capabilities] describes.
  ///
  /// History and background reads are permissions on top of being available, so they read
  /// "Granted", "Not granted" or "Not available"; the types are just there or not. Until the first
  /// refresh, and while Health Connect itself is not available, nothing is known.
  FeatureState stateIn(PlatformCapabilities capabilities) {
    if (!capabilities.isLoaded) return (label: 'Checking', tone: StatusTone.neutral);
    if (!capabilities.healthConnectAvailable) return (label: 'Unknown', tone: StatusTone.neutral);
    FeatureState permission(bool available, bool authorized) => switch ((available, authorized)) {
      (_, true) => (label: 'Granted', tone: StatusTone.success),
      (true, false) => (label: 'Not granted', tone: StatusTone.warning),
      (false, false) => (label: 'Not available', tone: StatusTone.neutral),
    };
    FeatureState type(bool available) =>
        available ? (label: 'Available', tone: StatusTone.success) : (label: 'Not available', tone: StatusTone.neutral);
    return switch (this) {
      history => permission(capabilities.historyAvailable, capabilities.historyAuthorized),
      background => permission(capabilities.backgroundAvailable, capabilities.backgroundAuthorized),
      skinTemperature => type(capabilities.skinTemperatureAvailable),
      mindfulness => type(capabilities.mindfulnessAvailable),
      activityIntensity => type(capabilities.activityIntensityAvailable),
    };
  }
}
