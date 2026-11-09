part of '../health.dart';

/// Main class for the Plugin.
///
/// Use this class to get an instance of the Health plugin, like this:
///
///         final health = Health();
///
/// The plugin must be configured using the [configure] method before used.
///
/// Overall, the plugin supports:
///
///  * Handling permissions to access health data using the [hasPermissions],
///    [requestAuthorization], [revokePermissions] methods.
///  * Reading health data using the [getHealthDataFromTypes] method, or page by
///    page with [getHealthDataPages] for large ranges.
///  * Writing health data using the [writeHealthData] method.
///  * Cleaning up duplicate data points via the [removeDuplicates] method.
///
/// In addition, the plugin has a set of specialized methods for reading and writing
/// different types of health data:
///
///  * Reading aggregate health data using the [getHealthIntervalDataFromTypes]
///    and [getHealthAggregateDataFromTypes] methods.
///  * Reading total step counts using the [getTotalStepsInInterval] method.
///  * Writing different types of specialized health data like the [writeWorkoutData],
///    [writeBloodPressure], [writeBloodOxygen], [writeAudiogram], [writeMeal],
///    [writeMenstruationFlow], [writeInsulinDelivery], [writeActivityIntensity] methods.
///
/// On **Android**, this plugin relies on the Google Health Connect (GHC) SDK.
/// Since Health Connect is not installed on SDK level < 34, the plugin has a
/// set of specialized methods to handle GHC:
///
///  * [getHealthConnectSdkStatus] to check the status of GHC
///  * [isHealthConnectAvailable] to check if GHC is installed on this phone
///  * [installHealthConnect] to direct the user to the app store to install GHC
///
/// **Note** that you should check the availability of GHC before using any setter
/// or getter methods. Otherwise, the plugin will throw an exception.
class Health
    with
        _HealthSupport,
        _HealthReadSupport,
        _HealthPageReads,
        HealthDataReads,
        HealthAggregateReads,
        HealthChangeTracking,
        HealthConnectStatus,
        HealthConnectFeatures,
        HealthPermissions,
        HealthDataWrites,
        HealthMeasurementWrites,
        HealthPlatformSpecificWrites,
        HealthMealWrites,
        HealthDataDeletion,
        HealthWorkoutWrites,
        HealthWorkoutRoutes {
  // Reading, permissions and writing are implemented by the public mixins in
  // src/reading/, src/permissions/ and src/writing/.

  static const MethodChannel _channel = MethodChannel('flutter_health');

  /// The default [pageSize].
  static const int defaultPageSize = 20000;

  /// The largest [pageSize] accepted. Bigger pages risk running Android's Java
  /// heap out of memory while a page is built and sent.
  static const int maxPageSize = 50000;

  @override
  String? _deviceId;
  @override
  final DeviceInfoPlugin _deviceInfo;
  @override
  HealthConnectSdkStatus _healthConnectSdkStatus = HealthConnectSdkStatus.sdkUnavailable;

  /// Where data returned by Health Connect or HealthKit is decoded and parsed;
  /// see [HealthIsolateMode]. Read once when a read starts, so it can be
  /// changed at any time.
  @override
  HealthIsolateMode isolateMode;

  int _pageSize = defaultPageSize;

  /// Target number of data points per platform call when reading data, from 1
  /// to [maxPageSize]. Bigger means fewer Health Connect calls, which count
  /// against its API quota, but more memory per call. See the README section
  /// "Health Connect limits".
  ///
  /// Health Connect returns at most 5000 records per call. One heart rate,
  /// speed or skin temperature record holds many samples: heart rate is read
  /// in time slices of at most about this many samples, and speed and skin
  /// temperature read at most `pageSize / 3600` records per call. Sleep
  /// sessions, workouts and workout routes are read in smaller pages, and so
  /// are ECGs and workout routes on iOS. Read once when a read starts, so it
  /// can be changed at any time.
  @override
  int get pageSize => _pageSize;

  set pageSize(int value) {
    RangeError.checkValueInInterval(value, 1, maxPageSize, 'pageSize');
    _pageSize = value;
  }

  /// Get an instance of the health plugin.
  ///
  /// [Health.isolateMode] and [Health.pageSize] control how data is read; see
  /// their documentation. Both can also be changed later. Throws a [RangeError] if
  /// [pageSize] is not between 1 and [maxPageSize].
  Health({DeviceInfoPlugin? deviceInfo, this.isolateMode = HealthIsolateMode.auto, int pageSize = defaultPageSize})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin() {
    this.pageSize = pageSize;
    _registerFromJsonFunctions();
  }

  /// The latest status on availability of Health Connect SDK on this phone.
  HealthConnectSdkStatus get healthConnectSdkStatus => _healthConnectSdkStatus;

  /// The type of platform of this device.
  @override
  HealthPlatformType get platformType =>
      Platform.isIOS ? HealthPlatformType.appleHealth : HealthPlatformType.googleHealthConnect;

  /// The id of this device, which read data points carry as their
  /// [HealthDataPoint.sourceDeviceId].
  ///
  /// On Android this is the [ID](https://developer.android.com/reference/android/os/Build#ID) of the BUILD.
  /// On iOS this is the [identifierForVendor](https://developer.apple.com/documentation/uikit/uidevice/1620059-identifierforvendor) of the UIDevice.
  /// It is 'unknown' until [configure] or the first read has looked it up.
  @override
  String get deviceId => _deviceId ?? 'unknown';

  /// Configure the health plugin. Must be called before using the plugin.
  Future<void> configure() async {
    _deviceId = Platform.isAndroid
        ? (await _deviceInfo.androidInfo).id
        : (await _deviceInfo.iosInfo).identifierForVendor;
  }

  /// Check if a given data type is available on the platform
  @override
  bool isDataTypeAvailable(HealthDataType dataType) =>
      Platform.isAndroid ? dataTypeKeysAndroid.contains(dataType) : dataTypeKeysIOS.contains(dataType);

  /// Check if a given data type is available on this device.
  /// Currently only needed for Android Skin Temperature support.
  @override
  Future<void> _checkIfDataTypeAvailableOnDevice(HealthDataType dataType) async {
    if (!Platform.isAndroid) return;

    if (dataType == HealthDataType.SKIN_TEMPERATURE) {
      final available = await isSkinTemperatureAvailable();
      if (!available) {
        throw HealthException(
          dataType,
          'Not available on this Android device',
          errorCode: HealthErrorCode.notSupported,
        );
      }
    }
  }

  /// Checks if Google Health Connect is available and throws an [UnsupportedError]
  /// if not.
  /// Internal methods used to check availability before any getter or setter methods.
  @override
  Future<void> _checkIfHealthConnectAvailableOnAndroid() async {
    if (!Platform.isAndroid) return;

    if (!(await isHealthConnectAvailable())) {
      throw UnsupportedError(
        "Google Health Connect is not available on this Android device. "
        "You may prompt the user to install it using the 'installHealthConnect' method",
      );
    }
  }
}
