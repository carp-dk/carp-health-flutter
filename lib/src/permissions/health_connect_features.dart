part of '../../health.dart';

/// Part of [Health]: the optional Health Connect features (reading health data
/// history, reading in the background, and skin temperature), and the
/// permissions for the two reads. Android only.
// ignore: library_private_types_in_public_api
mixin HealthConnectFeatures on _HealthSupport {
  /// Checks if the Health Data History feature is available.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()
  ///
  ///
  /// Android only. Returns false on iOS or if an error occurs.
  Future<bool> isHealthDataHistoryAvailable() async {
    if (Platform.isIOS) return false;

    try {
      final status = await Health._channel.invokeMethod<bool>('isHealthDataHistoryAvailable');
      return status ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isHealthDataHistoryAvailable(): $e');
      return false;
    }
  }

  /// Checks the current status of the Health Data History permission.
  /// Make sure to check [Health.isHealthConnectAvailable] before calling this
  /// method.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()
  ///
  ///
  /// Android only. Returns true on iOS or false if an error occurs.
  Future<bool> isHealthDataHistoryAuthorized() async {
    if (Platform.isIOS) return true;

    try {
      final status = await Health._channel.invokeMethod<bool>('isHealthDataHistoryAuthorized');
      return status ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isHealthDataHistoryAuthorized(): $e');
      return false;
    }
  }

  /// Requests the Health Data History permission.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()
  ///
  ///
  /// Android only. Returns true on iOS or false if an error occurs.
  Future<bool> requestHealthDataHistoryAuthorization() async {
    if (Platform.isIOS) return true;

    await _checkIfHealthConnectAvailableOnAndroid();
    try {
      final bool? isAuthorized = await Health._channel.invokeMethod('requestHealthDataHistoryAuthorization');
      return isAuthorized ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in requestHealthDataHistoryAuthorization(): $e');
      return false;
    }
  }

  /// Checks if the Health Data in Background feature is available.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND()
  ///
  ///
  /// Android only. Returns false on iOS or if an error occurs.
  Future<bool> isHealthDataInBackgroundAvailable() async {
    if (Platform.isIOS) return false;

    try {
      final status = await Health._channel.invokeMethod<bool>('isHealthDataInBackgroundAvailable');
      return status ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isHealthDataInBackgroundAvailable(): $e');
      return false;
    }
  }

  /// Checks the current status of the Health Data in Background permission.
  /// Make sure to check [Health.isHealthConnectAvailable] before calling this
  /// method.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND()
  ///
  ///
  /// Android only. Returns true on iOS or false if an error occurs.
  Future<bool> isHealthDataInBackgroundAuthorized() async {
    if (Platform.isIOS) return true;

    try {
      final status = await Health._channel.invokeMethod<bool>('isHealthDataInBackgroundAuthorized');
      return status ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isHealthDataInBackgroundAuthorized(): $e');
      return false;
    }
  }

  /// Requests the Health Data in Background permission.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND()
  ///
  ///
  /// Android only. Returns true on iOS or false if an error occurs.
  Future<bool> requestHealthDataInBackgroundAuthorization() async {
    if (Platform.isIOS) return true;

    await _checkIfHealthConnectAvailableOnAndroid();
    try {
      final bool? isAuthorized = await Health._channel.invokeMethod('requestHealthDataInBackgroundAuthorization');
      return isAuthorized ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in requestHealthDataInBackgroundAuthorization(): $e');
      return false;
    }
  }

  /// Checks whether Skin Temperature is available on this Android device.
  ///
  /// Android only. Returns false on iOS or if an error occurs.
  Future<bool> isSkinTemperatureAvailable() async {
    if (Platform.isIOS) return false;

    try {
      final status = await getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        return false;
      }

      final available = await Health._channel.invokeMethod<bool>('isSkinTemperatureAvailable');
      return available ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isSkinTemperatureAvailable(): $e');
      return false;
    }
  }
}
