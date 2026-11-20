part of '../../health.dart';

/// Part of [Health]: the optional Health Connect features (reading health data
/// history, reading in the background, skin temperature, mindfulness sessions
/// and activity intensity), and the permissions for the two reads. Android
/// only.
// ignore: library_private_types_in_public_api
mixin HealthConnectFeatures on _HealthSupport {
  /// Checks if the Health Data History feature is available: on Android 15
  /// and later, on Android 14 with SDK extension 13, and on Android 13 and
  /// lower with a recent Health Connect app (see the README section
  /// "Health Connect features").
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

  /// Checks if the Health Data in Background feature is available, which
  /// depends on the Health Connect version as [isHealthDataHistoryAvailable]
  /// does.
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

  /// Checks whether Skin Temperature is available on this Android device,
  /// which depends on the Health Connect version as
  /// [isHealthDataHistoryAvailable] does. Where it is not, reading or writing
  /// [HealthDataType.SKIN_TEMPERATURE] throws a [HealthException] with
  /// [HealthErrorCode.notSupported].
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

  /// Checks whether the Health Connect on this Android device has mindfulness
  /// sessions ([HealthDataType.MINDFULNESS]). Health Connect added them after
  /// its first release, so this depends on the Health Connect version on the
  /// device: Android 16 and later, Android 14 and 15 with SDK extension 15,
  /// or on Android 13 and lower a recent Health Connect app. Where it does
  /// not have them, reading or writing
  /// [HealthDataType.MINDFULNESS] throws a [HealthException] with
  /// [HealthErrorCode.notSupported].
  ///
  /// [Health.hasPermissions] is no such check: Android 15 at SDK extension 13
  /// defines the mindfulness permissions, so they can be granted (for example
  /// with `adb shell pm grant`) while this returns false. The Health Connect
  /// permission dialog does not offer them there, and
  /// [Health.requestAuthorization] for only [HealthDataType.MINDFULNESS]
  /// returns false at once.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/HealthConnectFeatures#FEATURE_MINDFULNESS_SESSION()
  ///
  /// Returns true on iOS, where HealthKit has mindful sessions, and false if
  /// Health Connect is not available or an error occurs.
  Future<bool> isMindfulnessSessionAvailable() async {
    if (platformType == HealthPlatformType.appleHealth) return true;

    try {
      final status = await getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        return false;
      }

      final available = await Health._channel.invokeMethod<bool>('isMindfulnessSessionAvailable');
      return available ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isMindfulnessSessionAvailable(): $e');
      return false;
    }
  }

  /// Checks whether the Health Connect on this Android device has activity
  /// intensity records ([HealthDataType.ACTIVITY_INTENSITY]). Health Connect
  /// added them after its first release, so this depends on the Health Connect
  /// version on the device: Android 16 and later, Android 14 and 15 with SDK
  /// extension 16, or on Android 13 and lower a recent Health Connect app. A
  /// base Android 15 device does not have them. Where it does not have them,
  /// reading, writing or tracking the changes of
  /// [HealthDataType.ACTIVITY_INTENSITY] throws a [HealthException] with
  /// [HealthErrorCode.notSupported]. Its permissions are not defined before
  /// SDK extension 16, so there [Health.hasPermissions] returns false for it
  /// and the Health Connect permission dialog does not offer it.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/HealthConnectFeatures#FEATURE_ACTIVITY_INTENSITY()
  ///
  /// Android only. Returns false on iOS, which has no activity intensity, and
  /// if Health Connect is not available or an error occurs.
  Future<bool> isActivityIntensityAvailable() async {
    if (platformType == HealthPlatformType.appleHealth) return false;

    try {
      final status = await getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        return false;
      }

      final available = await Health._channel.invokeMethod<bool>('isActivityIntensityAvailable');
      return available ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isActivityIntensityAvailable(): $e');
      return false;
    }
  }
}
