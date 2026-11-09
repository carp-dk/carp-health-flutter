part of '../../main.dart';

/// Skin temperature on Android: checking the feature availability and writing a sample record.
extension _SkinTemperatureActions on HealthAppState {
  /// Gets the Skin Temperature feature availability on Android.
  Future<void> getSkinTemperatureFeatureStatus() async {
    if (!Platform.isAndroid) {
      setState(() {
        _contentSkinTemperatureFeatureStatus = const Text('Skin Temperature feature is Android only.');
        _state = AppState.SKIN_TEMPERATURE_FEATURE_STATUS;
      });
      return;
    }

    final available = await health.isSkinTemperatureAvailable();
    setState(() {
      _contentSkinTemperatureFeatureStatus = Text(
        'Skin Temperature Feature: ${available ? "AVAILABLE" : "NOT AVAILABLE"}',
      );
      _state = AppState.SKIN_TEMPERATURE_FEATURE_STATUS;
    });
  }

  Future<bool> _ensureSkinTemperaturePermissions({required HealthDataAccess access}) async {
    if (!Platform.isAndroid) return false;

    final available = await health.isSkinTemperatureAvailable();
    if (!available) {
      setState(() {
        _contentSkinTemperatureFeatureStatus = const Text('Skin Temperature Feature: NOT AVAILABLE');
        _state = AppState.SKIN_TEMPERATURE_FEATURE_STATUS;
      });
      return false;
    }

    bool? hasPermissions = await health.hasPermissions([HealthDataType.SKIN_TEMPERATURE], permissions: [access]);

    if (hasPermissions != true) {
      hasPermissions = await health.requestAuthorization([HealthDataType.SKIN_TEMPERATURE], permissions: [access]);
    }

    return hasPermissions == true;
  }

  /// Write a sample skin temperature record (Android only).
  Future<void> writeSkinTemperatureSample() async {
    if (!Platform.isAndroid) {
      setState(() => _state = AppState.DATA_NOT_ADDED);
      return;
    }

    final authorized = await _ensureSkinTemperaturePermissions(access: HealthDataAccess.READ_WRITE);
    if (!authorized) {
      setState(() => _state = AppState.DATA_NOT_ADDED);
      return;
    }

    final now = DateTime.now();
    final earlier = now.subtract(const Duration(minutes: 20));
    await health.writeHealthData(
      value: 33.6,
      type: HealthDataType.SKIN_TEMPERATURE,
      startTime: earlier,
      endTime: now,
      recordingMethod: RecordingMethod.manual,
    );
  }
}
