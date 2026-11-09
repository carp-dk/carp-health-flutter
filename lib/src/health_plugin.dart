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
class Health with _HealthReadSupport, _HealthPageReads, _HealthDataReads, _HealthAggregateReads, _HealthChanges {
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

  /// Determines if the health data [types] have been granted with the specified
  /// access rights [permissions].
  ///
  /// Returns:
  ///
  ///  * true - if all of the data types have been granted with the specified access rights.
  ///  * false - if any of the data types has not been granted with the specified access right(s).
  ///  * null - if it can not be determined if the data types have been granted with the specified access right(s).
  ///
  /// Parameters:
  ///
  ///  * [types]  - List of [HealthDataType] whose permissions are to be checked.
  ///  * [permissions] - Optional.
  ///    + If unspecified, this method checks if each HealthDataType in [types] has been granted READ access.
  ///    + If specified, this method checks if each [HealthDataType] in [types] has been granted with the access specified in its
  ///   corresponding entry in this list. The length of this list must be equal to that of [types].
  ///
  /// Caveat:
  ///
  ///  * As Apple HealthKit will not disclose if READ access has been granted for a data type due to privacy concern,
  ///   this method can only return null to represent an undetermined status, if it is called on iOS
  ///   with a READ or READ_WRITE access.
  ///
  ///  * On Android, this function returns true or false, depending on whether the specified access right has been granted.
  Future<bool?> hasPermissions(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (permissions != null && permissions.length != types.length) {
      throw ArgumentError("The lists of types and permissions must be of same length.");
    }

    final mTypes = List<HealthDataType>.from(types, growable: true);
    final mPermissions = permissions == null
        ? List<int>.filled(types.length, HealthDataAccess.READ.index, growable: true)
        : permissions.map((permission) => permission.index).toList();

    /// On Android, if BMI is requested, then also ask for weight and height
    if (Platform.isAndroid) {
      _handleBMI(mTypes, mPermissions);
      _handleWorkoutRoute(mTypes, mPermissions);
    }

    return await _channel.invokeMethod('hasPermissions', {
      "types": mTypes.map((type) => type.name).toList(),
      "permissions": mPermissions,
    });
  }

  /// Revokes Google Health Connect permissions on Android of all types.
  ///
  /// NOTE: The app must be completely killed and restarted for the changes to take effect.
  /// Not implemented on iOS as there is no way to programmatically remove access.
  ///
  /// Android only. On iOS this does nothing.
  Future<void> revokePermissions() async {
    if (Platform.isIOS) return;

    await _checkIfHealthConnectAvailableOnAndroid();
    try {
      await _channel.invokeMethod('revokePermissions');
    } catch (e) {
      debugPrint('$runtimeType - Exception in revokePermissions(): $e');
    }
  }

  /// Checks the current status of Health Connect availability.
  ///
  /// See this for more info:
  /// https://developer.android.com/reference/kotlin/androidx/health/connect/client/HealthConnectClient#getSdkStatus(android.content.Context,kotlin.String)
  ///
  /// Android only. Returns null on iOS or if an error occurs.
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus() async {
    if (Platform.isIOS) return null;

    try {
      final status = await _channel.invokeMethod<int>('getHealthConnectSdkStatus');
      _healthConnectSdkStatus = status != null
          ? HealthConnectSdkStatus.fromNativeValue(status)
          : HealthConnectSdkStatus.sdkUnavailable;

      return _healthConnectSdkStatus;
    } catch (e) {
      debugPrint('$runtimeType - Exception in getHealthConnectSdkStatus(): $e');
      return null;
    }
  }

  /// Is Google Health Connect available on this phone?
  ///
  /// Android only. Returns always true on iOS.
  Future<bool> isHealthConnectAvailable() async =>
      !Platform.isAndroid ? true : (await getHealthConnectSdkStatus() == HealthConnectSdkStatus.sdkAvailable);

  /// Prompt the user to install the Google Health Connect app via the
  /// installed store (most likely Play Store).
  ///
  /// Android only. On iOS this does nothing.
  Future<void> installHealthConnect() async {
    if (Platform.isIOS) return;

    try {
      await _channel.invokeMethod('installHealthConnect');
    } catch (e) {
      debugPrint('$runtimeType - Exception in installHealthConnect(): $e');
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

  /// Checks if the Health Data History feature is available.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()
  ///
  ///
  /// Android only. Returns false on iOS or if an error occurs.
  Future<bool> isHealthDataHistoryAvailable() async {
    if (Platform.isIOS) return false;

    try {
      final status = await _channel.invokeMethod<bool>('isHealthDataHistoryAvailable');
      return status ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isHealthDataHistoryAvailable(): $e');
      return false;
    }
  }

  /// Checks the current status of the Health Data History permission.
  /// Make sure to check [isHealthConnectAvailable] before calling this method.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_HISTORY()
  ///
  ///
  /// Android only. Returns true on iOS or false if an error occurs.
  Future<bool> isHealthDataHistoryAuthorized() async {
    if (Platform.isIOS) return true;

    try {
      final status = await _channel.invokeMethod<bool>('isHealthDataHistoryAuthorized');
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
      final bool? isAuthorized = await _channel.invokeMethod('requestHealthDataHistoryAuthorization');
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
      final status = await _channel.invokeMethod<bool>('isHealthDataInBackgroundAvailable');
      return status ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isHealthDataInBackgroundAvailable(): $e');
      return false;
    }
  }

  /// Checks the current status of the Health Data in Background permission.
  /// Make sure to check [isHealthConnectAvailable] before calling this method.
  ///
  /// See this for more info: https://developer.android.com/reference/androidx/health/connect/client/permission/HealthPermission#PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND()
  ///
  ///
  /// Android only. Returns true on iOS or false if an error occurs.
  Future<bool> isHealthDataInBackgroundAuthorized() async {
    if (Platform.isIOS) return true;

    try {
      final status = await _channel.invokeMethod<bool>('isHealthDataInBackgroundAuthorized');
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
      final bool? isAuthorized = await _channel.invokeMethod('requestHealthDataInBackgroundAuthorization');
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

      final available = await _channel.invokeMethod<bool>('isSkinTemperatureAvailable');
      return available ?? false;
    } catch (e) {
      debugPrint('$runtimeType - Exception in isSkinTemperatureAvailable(): $e');
      return false;
    }
  }

  /// Requests permissions to access health data [types].
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///
  /// * [types] - a list of [HealthDataType] which the permissions are requested for.
  /// * [permissions] - Optional.
  ///   + If unspecified, each [HealthDataType] in [types] is requested for READ [HealthDataAccess].
  ///   + If specified, each [HealthDataAccess] in this list is requested for its corresponding indexed
  ///   entry in [types]. In addition, the length of this list must be equal to that of [types].
  ///
  ///  Caveats:
  ///
  ///  * This method may block if permissions are already granted. Hence, check
  ///    [hasPermissions] before calling this method.
  ///  * As Apple HealthKit will not disclose if READ access has been granted for
  ///    a data type due to privacy concern, this method will return **true if
  ///    the window asking for permission was showed to the user without errors**
  ///    if it is called on iOS with a READ or READ_WRITE access.
  Future<bool> requestAuthorization(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (permissions != null && permissions.length != types.length) {
      throw ArgumentError('The length of [types] must be same as that of [permissions].');
    }

    if (permissions != null) {
      for (int i = 0; i < types.length; i++) {
        final type = types[i];
        final permission = permissions[i];
        if ((type == HealthDataType.ELECTROCARDIOGRAM ||
                type == HealthDataType.HIGH_HEART_RATE_EVENT ||
                type == HealthDataType.LOW_HEART_RATE_EVENT ||
                type == HealthDataType.IRREGULAR_HEART_RATE_EVENT ||
                type == HealthDataType.WALKING_HEART_RATE ||
                type == HealthDataType.ATRIAL_FIBRILLATION_BURDEN) &&
            permission != HealthDataAccess.READ) {
          throw ArgumentError(
            'Requesting WRITE permission on ELECTROCARDIOGRAM / HIGH_HEART_RATE_EVENT / LOW_HEART_RATE_EVENT / IRREGULAR_HEART_RATE_EVENT / WALKING_HEART_RATE / ATRIAL_FIBRILLATION_BURDEN is not allowed.',
          );
        }
      }
    }

    final mTypes = List<HealthDataType>.from(types, growable: true);
    final mPermissions = permissions == null
        ? List<int>.filled(types.length, HealthDataAccess.READ.index, growable: true)
        : permissions.map((permission) => permission.index).toList();

    // on Android, if BMI is requested, then also ask for weight and height
    if (Platform.isAndroid) {
      _handleBMI(mTypes, mPermissions);
      _handleWorkoutRoute(mTypes, mPermissions);
    }

    List<String> keys = mTypes.map((e) => e.name).toList();
    final bool? isAuthorized = await _channel.invokeMethod('requestAuthorization', {
      'types': keys,
      "permissions": mPermissions,
    });
    return isAuthorized ?? false;
  }

  /// Obtains health and weight if BMI is requested on Android.
  void _handleBMI(List<HealthDataType> mTypes, List<int> mPermissions) {
    final index = mTypes.indexOf(HealthDataType.BODY_MASS_INDEX);

    if (index != -1 && Platform.isAndroid) {
      if (!mTypes.contains(HealthDataType.WEIGHT)) {
        mTypes.add(HealthDataType.WEIGHT);
        mPermissions.add(mPermissions[index]);
      }
      if (!mTypes.contains(HealthDataType.HEIGHT)) {
        mTypes.add(HealthDataType.HEIGHT);
        mPermissions.add(mPermissions[index]);
      }
      mTypes.remove(HealthDataType.BODY_MASS_INDEX);
      mPermissions.removeAt(index);
    }
  }

  /// Ensures workout permission is requested whenever workout routes are requested on Android.
  void _handleWorkoutRoute(List<HealthDataType> mTypes, List<int> mPermissions) {
    final index = mTypes.indexOf(HealthDataType.WORKOUT_ROUTE);
    if (index == -1) {
      return;
    }

    if (!mTypes.contains(HealthDataType.WORKOUT)) {
      mTypes.add(HealthDataType.WORKOUT);
      mPermissions.add(mPermissions[index]);
    }
  }

  /// Write health data.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [value] - the health data's value in double
  ///  * [unit] - **iOS ONLY** the unit the health data is measured in.
  ///  * [type] - the value's HealthDataType
  ///  * [startTime] - the start time when this [value] is measured.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    It must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the [value] is measured
  ///    only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point, automatic by default.
  ///    (on iOS this must be manual or automatic)
  ///
  /// Values for Sleep and Headache are ignored and will be automatically assigned
  /// the default value.
  Future<bool> writeHealthData({
    required double value,
    HealthDataUnit? unit,
    required HealthDataType type,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    await _checkIfDataTypeAvailableOnDevice(type);
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    if (type == HealthDataType.WORKOUT) {
      throw ArgumentError("Adding workouts should be done using the writeWorkoutData method.");
    }
    if (type == HealthDataType.ACTIVITY_INTENSITY) {
      throw ArgumentError("Adding activity intensity data should be done using the writeActivityIntensity method.");
    }
    // If not implemented on platform, throw an exception
    if (!isDataTypeAvailable(type)) {
      throw HealthException(type, 'Not available on platform $platformType', errorCode: HealthErrorCode.notSupported);
    }
    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }
    if ({
          HealthDataType.HIGH_HEART_RATE_EVENT,
          HealthDataType.LOW_HEART_RATE_EVENT,
          HealthDataType.IRREGULAR_HEART_RATE_EVENT,
          HealthDataType.ELECTROCARDIOGRAM,
        }.contains(type) &&
        Platform.isIOS) {
      throw ArgumentError("$type - iOS does not support writing this data type in HealthKit");
    }

    // Assign default unit if not specified
    unit ??= dataTypeToUnit[type]!;

    // Align values to type in cases where the type defines the value.
    // E.g. SLEEP_IN_BED should have value 0
    if (type == HealthDataType.SLEEP_ASLEEP ||
        type == HealthDataType.SLEEP_AWAKE ||
        type == HealthDataType.SLEEP_IN_BED ||
        type == HealthDataType.SLEEP_DEEP ||
        type == HealthDataType.SLEEP_REM ||
        type == HealthDataType.SLEEP_LIGHT ||
        type == HealthDataType.HEADACHE_NOT_PRESENT ||
        type == HealthDataType.HEADACHE_MILD ||
        type == HealthDataType.HEADACHE_MODERATE ||
        type == HealthDataType.HEADACHE_SEVERE ||
        type == HealthDataType.HEADACHE_UNSPECIFIED) {
      value = _alignValue(type).toDouble();
    }

    Map<String, dynamic> args = {
      'value': value,
      'dataTypeKey': type.name,
      'dataUnitKey': unit.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };
    bool? success = await _channel.invokeMethod('writeData', args);
    return success ?? false;
  }

  /// Write health data and return UUID on success.
  ///
  /// Returns the UUID of the written record if successful, null otherwise.
  ///
  /// Parameters:
  ///  * [value] - the health data's value in double
  ///  * [unit] - **iOS ONLY** the unit the health data is measured in.
  ///  * [type] - the value's HealthDataType
  ///  * [startTime] - the start time when this [value] is measured.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    It must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the [value] is measured
  ///    only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point, automatic by default.
  ///    (on iOS this must be manual or automatic)
  ///
  /// Values for Sleep and Headache are ignored and will be automatically assigned
  /// the default value.
  Future<String?> writeHealthDataUUID({
    required double value,
    HealthDataUnit? unit,
    required HealthDataType type,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    if (type == HealthDataType.WORKOUT) {
      throw ArgumentError("Adding workouts should be done using the writeWorkoutData method.");
    }
    // If not implemented on platform, throw an exception
    if (!isDataTypeAvailable(type)) {
      throw HealthException(type, 'Not available on platform $platformType', errorCode: HealthErrorCode.notSupported);
    }

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    if ({
          HealthDataType.HIGH_HEART_RATE_EVENT,
          HealthDataType.LOW_HEART_RATE_EVENT,
          HealthDataType.IRREGULAR_HEART_RATE_EVENT,
          HealthDataType.ELECTROCARDIOGRAM,
        }.contains(type) &&
        Platform.isIOS) {
      throw ArgumentError("$type - iOS does not support writing this data type in HealthKit");
    }

    // Assign default unit if not specified
    unit ??= dataTypeToUnit[type]!;

    // Align values to type in cases where the type defines the value.
    // E.g. SLEEP_IN_BED should have value 0
    if (type == HealthDataType.SLEEP_ASLEEP ||
        type == HealthDataType.SLEEP_AWAKE ||
        type == HealthDataType.SLEEP_IN_BED ||
        type == HealthDataType.SLEEP_DEEP ||
        type == HealthDataType.SLEEP_REM ||
        type == HealthDataType.SLEEP_LIGHT ||
        type == HealthDataType.HEADACHE_NOT_PRESENT ||
        type == HealthDataType.HEADACHE_MILD ||
        type == HealthDataType.HEADACHE_MODERATE ||
        type == HealthDataType.HEADACHE_SEVERE ||
        type == HealthDataType.HEADACHE_UNSPECIFIED) {
      value = _alignValue(type).toDouble();
    }

    Map<String, dynamic> args = {
      'value': value,
      'dataTypeKey': type.name,
      'dataUnitKey': unit.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };

    String uuid = '${await _channel.invokeMethod('writeDataUUID', args)}';

    debugPrint("Added health data point: $uuid");

    return uuid;
  }

  /// Writes an [ActivityIntensityRecord] to Google Health Connect.
  ///
  /// This API is Android only.
  Future<bool> writeActivityIntensity({
    required ActivityIntensityLevel intensityLevel,
    required DateTime startTime,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
    String? clientRecordId,
    double? clientRecordVersion,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('writeActivityIntensity is only available on Android');
    }

    await _checkIfHealthConnectAvailableOnAndroid();

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    final intensityValue = intensityLevel.toAndroidValue();
    if (intensityValue == -1) {
      throw ArgumentError('Unknown activity intensity level provided.');
    }

    Map<String, dynamic> args = {
      'intensityType': intensityValue,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };

    final bool? success = await _channel.invokeMethod('writeActivityIntensity', args);
    return success ?? false;
  }

  /// Deletes all records of the given [type] for a given period of time.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [type] - the value's HealthDataType.
  ///  * [startTime] - the start time when this [value] is measured.
  ///    Must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    Must be equal to or later than [startTime].
  Future<bool> delete({required HealthDataType type, required DateTime startTime, DateTime? endTime}) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    Map<String, dynamic> args = {
      'dataTypeKey': type.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
    };
    bool? success = await _channel.invokeMethod('delete', args);
    return success ?? false;
  }

  /// Deletes a specific health record by its UUID.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [uuid] - The UUID of the health record to delete.
  ///  * [type] - The health data type of the record. Required on iOS.
  ///
  /// On Android, only the UUID is required. On iOS, both UUID and type are required.
  Future<bool> deleteByUUID({required String uuid, HealthDataType? type}) async {
    await _checkIfHealthConnectAvailableOnAndroid();

    if (uuid.isEmpty || uuid == "") {
      throw ArgumentError("UUID must not be empty.");
    }

    if (Platform.isIOS && type == null) {
      throw ArgumentError("On iOS, both UUID and type are required to delete a record.");
    }

    Map<String, dynamic> args = {'uuid': uuid, 'dataTypeKey': type?.name};

    bool? success = await _channel.invokeMethod('deleteByUUID', args);
    return success ?? false;
  }

  Future<bool> deleteByClientRecordId({
    required HealthDataType dataTypeKey,
    required String clientRecordId,
    String? recordId,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();

    Map<String, dynamic> args = {
      'dataTypeKey': dataTypeKey.name,
      'recordId': recordId,
      'clientRecordId': clientRecordId,
    };
    bool? success = await _channel.invokeMethod('deleteByClientRecordId', args);
    return success ?? false;
  }

  /// Saves a blood pressure record.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [systolic] - the systolic part of the blood pressure.
  ///  * [diastolic] - the diastolic part of the blood pressure.
  ///  * [startTime] - the start time when this [value] is measured.
  ///    Must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [value] is measured.
  ///    Must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the blood pressure is measured
  ///    only at a specific point in time. If omitted, [endTime] is set to [startTime].
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeBloodPressure({
    required int systolic,
    required int diastolic,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    Map<String, dynamic> args = {
      'systolic': systolic,
      'diastolic': diastolic,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'recordingMethod': recordingMethod.toInt(),
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
    };
    return await _channel.invokeMethod('writeBloodPressure', args) == true;
  }

  /// Saves blood oxygen saturation record.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [saturation] - the saturation of the blood oxygen in percentage
  ///  * [startTime] - the start time when this [saturation] is measured.
  ///    Must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when this [saturation] is measured.
  ///    Must be equal to or later than [startTime].
  ///    Simply set [endTime] equal to [startTime] if the blood oxygen saturation
  ///    is measured only at a specific point in time (default).
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeBloodOxygen({
    required double saturation,
    required DateTime startTime,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }
    bool? success;

    if (Platform.isIOS) {
      success = await writeHealthData(
        value: saturation,
        type: HealthDataType.BLOOD_OXYGEN,
        startTime: startTime,
        endTime: endTime,
        recordingMethod: recordingMethod,
      );
    } else if (Platform.isAndroid) {
      Map<String, dynamic> args = {
        'value': saturation,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'dataTypeKey': HealthDataType.BLOOD_OXYGEN.name,
        'recordingMethod': recordingMethod.toInt(),
      };
      success = await _channel.invokeMethod('writeBloodOxygen', args);
    }
    return success ?? false;
  }

  /// Saves meal record into Apple Health or Health Connect.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [mealType] - the type of meal.
  ///  * [startTime] - the start time when the meal was consumed.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when the meal was consumed.
  ///    It must be equal to or later than [startTime].
  ///  * [name] - optional name information about this meal.
  ///  * [caloriesConsumed] - total calories consumed with this meal.
  ///  * [carbohydrates] - optional carbohydrates information.
  ///  * [protein] - optional protein information.
  ///  * [fatTotal] - optional total fat information.
  ///  * [caffeine] - optional caffeine information.
  ///  * [vitaminA] - optional vitamin A information.
  ///  * [b1Thiamin] - optional vitamin B1 (thiamin) information.
  ///  * [b2Riboflavin] - optional vitamin B2 (riboflavin) information.
  ///  * [b3Niacin] - optional vitamin B3 (niacin) information.
  ///  * [b5PantothenicAcid] - optional vitamin B5 (pantothenic acid) information.
  ///  * [b6Pyridoxine] - optional vitamin B6 (pyridoxine) information.
  ///  * [b7Biotin] - optional vitamin B7 (biotin) information.
  ///  * [b9Folate] - optional vitamin B9 (folate) information.
  ///  * [b12Cobalamin] - optional vitamin B12 (cobalamin) information.
  ///  * [vitaminC] - optional vitamin C information.
  ///  * [vitaminD] - optional vitamin D information.
  ///  * [vitaminE] - optional vitamin E information.
  ///  * [vitaminK] - optional vitamin K information.
  ///  * [calcium] - optional calcium information.
  ///  * [cholesterol] - optional cholesterol information.
  ///  * [chloride] - optional chloride information.
  ///  * [chromium] - optional chromium information.
  ///  * [copper] - optional copper information.
  ///  * [fatUnsaturated] - optional unsaturated fat information.
  ///  * [fatMonounsaturated] - optional monounsaturated fat information.
  ///  * [fatPolyunsaturated] - optional polyunsaturated fat information.
  ///  * [fatSaturated] - optional saturated fat information.
  ///  * [fatTransMonoenoic] - optional trans-monoenoic fat information.
  ///  * [fiber] - optional fiber information.
  ///  * [iodine] - optional iodine information.
  ///  * [iron] - optional iron information.
  ///  * [magnesium] - optional magnesium information.
  ///  * [manganese] - optional manganese information.
  ///  * [molybdenum] - optional molybdenum information.
  ///  * [phosphorus] - optional phosphorus information.
  ///  * [potassium] - optional potassium information.
  ///  * [selenium] - optional selenium information.
  ///  * [sodium] - optional sodium information.
  ///  * [sugar] - optional sugar information.
  ///  * [water] - optional water information.
  ///  * [zinc] - optional zinc information.
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeMeal({
    required MealType mealType,
    required DateTime startTime,
    required DateTime endTime,
    String? clientRecordId,
    double? clientRecordVersion,
    double? caloriesConsumed,
    double? carbohydrates,
    double? protein,
    double? fatTotal,
    String? name,
    double? caffeine,
    double? vitaminA,
    double? b1Thiamin,
    double? b2Riboflavin,
    double? b3Niacin,
    double? b5PantothenicAcid,
    double? b6Pyridoxine,
    double? b7Biotin,
    double? b9Folate,
    double? b12Cobalamin,
    double? vitaminC,
    double? vitaminD,
    double? vitaminE,
    double? vitaminK,
    double? calcium,
    double? cholesterol,
    double? chloride,
    double? chromium,
    double? copper,
    double? fatUnsaturated,
    double? fatMonounsaturated,
    double? fatPolyunsaturated,
    double? fatSaturated,
    double? fatTransMonoenoic,
    double? fiber,
    double? iodine,
    double? iron,
    double? magnesium,
    double? manganese,
    double? molybdenum,
    double? phosphorus,
    double? potassium,
    double? selenium,
    double? sodium,
    double? sugar,
    double? water,
    double? zinc,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    Map<String, dynamic> args = {
      'name': name,
      'meal_type': mealType.name,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime.millisecondsSinceEpoch,
      'clientRecordId': clientRecordId,
      'clientRecordVersion': clientRecordVersion,
      'calories': caloriesConsumed,
      'carbs': carbohydrates,
      'protein': protein,
      'fat': fatTotal,
      'caffeine': caffeine,
      'vitamin_a': vitaminA,
      'b1_thiamin': b1Thiamin,
      'b2_riboflavin': b2Riboflavin,
      'b3_niacin': b3Niacin,
      'b5_pantothenic_acid': b5PantothenicAcid,
      'b6_pyridoxine': b6Pyridoxine,
      'b7_biotin': b7Biotin,
      'b9_folate': b9Folate,
      'b12_cobalamin': b12Cobalamin,
      'vitamin_c': vitaminC,
      'vitamin_d': vitaminD,
      'vitamin_e': vitaminE,
      'vitamin_k': vitaminK,
      'calcium': calcium,
      'cholesterol': cholesterol,
      'chloride': chloride,
      'chromium': chromium,
      'copper': copper,
      'fat_unsaturated': fatUnsaturated,
      'fat_monounsaturated': fatMonounsaturated,
      'fat_polyunsaturated': fatPolyunsaturated,
      'fat_saturated': fatSaturated,
      'fat_trans_monoenoic': fatTransMonoenoic,
      'fiber': fiber,
      'iodine': iodine,
      'iron': iron,
      'magnesium': magnesium,
      'manganese': manganese,
      'molybdenum': molybdenum,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'selenium': selenium,
      'sodium': sodium,
      'sugar': sugar,
      'water': water,
      'zinc': zinc,
      'recordingMethod': recordingMethod.toInt(),
    };
    bool? success = await _channel.invokeMethod('writeMeal', args);
    return success ?? false;
  }

  /// Save menstruation flow into Apple Health and Google Health Connect.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [flow] - the menstrual flow
  ///  * [startTime] - the start time when the menstrual flow is measured.
  ///  * [endTime] - the start time when the menstrual flow is measured.
  ///  * [isStartOfCycle] - A bool that indicates whether the sample represents
  ///    the start of a menstrual cycle.
  ///  * [recordingMethod] - the recording method of the data point.
  Future<bool> writeMenstruationFlow({
    required MenstrualFlow flow,
    required DateTime startTime,
    required DateTime endTime,
    required bool isStartOfCycle,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    var value = Platform.isAndroid ? MenstrualFlow.toHealthConnect(flow) : flow.index;

    if (value == -1) {
      throw ArgumentError("$flow is not a valid menstrual flow value for $platformType");
    }

    Map<String, dynamic> args = {
      'value': value,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'isStartOfCycle': isStartOfCycle,
      'dataTypeKey': HealthDataType.MENSTRUATION_FLOW.name,
      'recordingMethod': recordingMethod.toInt(),
    };
    return await _channel.invokeMethod('writeMenstruationFlow', args) == true;
  }

  /// Saves audiogram into Apple Health. Not supported on Android.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///   * [frequencies] - array of frequencies of the test
  ///   * [leftEarSensitivities] threshold in decibel for the left ear
  ///   * [rightEarSensitivities] threshold in decibel for the left ear
  ///   * [startTime] - the start time when the audiogram is measured.
  ///     It must be equal to or earlier than [endTime].
  ///   * [endTime] - the end time when the audiogram is measured.
  ///     It must be equal to or later than [startTime].
  ///     Simply set [endTime] equal to [startTime] if the audiogram is measured
  ///     only at a specific point in time (default).
  ///   * [metadata] - optional map of keys, both HKMetadataKeyExternalUUID
  ///     and HKMetadataKeyDeviceName are required
  Future<bool> writeAudiogram({
    required List<double> frequencies,
    required List<double> leftEarSensitivities,
    required List<double> rightEarSensitivities,
    required DateTime startTime,
    DateTime? endTime,
    Map<String, dynamic>? metadata,
  }) async {
    if (frequencies.isEmpty || leftEarSensitivities.isEmpty || rightEarSensitivities.isEmpty) {
      throw ArgumentError("frequencies, leftEarSensitivities and rightEarSensitivities can't be empty");
    }
    if (frequencies.length != leftEarSensitivities.length ||
        rightEarSensitivities.length != leftEarSensitivities.length) {
      throw ArgumentError("frequencies, leftEarSensitivities and rightEarSensitivities need to be of the same length");
    }
    endTime ??= startTime;
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }
    if (Platform.isAndroid) {
      throw UnsupportedError("writeAudiogram is not supported on Android");
    }

    Map<String, dynamic> args = {
      'frequencies': frequencies,
      'leftEarSensitivities': leftEarSensitivities,
      'rightEarSensitivities': rightEarSensitivities,
      'dataTypeKey': HealthDataType.AUDIOGRAM.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'metadata': metadata,
    };
    return await _channel.invokeMethod('writeAudiogram', args) == true;
  }

  /// Saves insulin delivery record into Apple Health.
  ///
  /// Returns true if successful, false otherwise.
  ///
  /// Parameters:
  ///  * [units] - the number of units of insulin taken.
  ///  * [reason] - the insulin reason, basal or bolus.
  ///  * [startTime] - the start time when the meal was consumed.
  ///    It must be equal to or earlier than [endTime].
  ///  * [endTime] - the end time when the meal was consumed.
  ///    It must be equal to or later than [startTime].
  Future<bool> writeInsulinDelivery(
    double units,
    InsulinDeliveryReason reason,
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (startTime.isAfter(endTime)) {
      throw ArgumentError("startTime must be equal or earlier than endTime");
    }

    if (reason == InsulinDeliveryReason.NOT_SET) {
      throw ArgumentError("set a valid insulin delivery reason");
    }

    if (Platform.isAndroid) {
      throw UnsupportedError("writeInsulinDelivery is not supported on Android");
    }

    Map<String, dynamic> args = {
      'units': units,
      'reason': reason.index,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
    };

    bool? success = await _channel.invokeMethod('writeInsulinDelivery', args);
    return success ?? false;
  }

  // The reads are implemented by the mixins in src/reading/ and declared here
  // too, so that dartdoc documents them as members of Health.

  /// Fetch a `HealthDataPoint` by `uuid` and `type`. Returns `null` if no matching record.
  ///
  /// Parameters:
  ///  * [uuid] - UUID of your saved health data point (e.g. A91A2F10-3D7B-486A-B140-5ADCD3C9C6D0)
  ///  * [type] - Data type of your saved health data point (e.g. HealthDataType.WORKOUT)
  ///
  /// Assuming above data are coming from your database.
  ///
  /// Throws a [HealthPlatformException] if Health Connect or HealthKit reports
  /// an error other than the record not being found.
  @override
  Future<HealthDataPoint?> getHealthDataByUUID({required String uuid, required HealthDataType type});

  /// Fetch a list of health data points based on [types].
  /// You can also specify the [recordingMethodsToFilter] to filter the data points.
  /// If not specified, all data points will be included.
  ///
  /// Types are read in the order of [types], each type once. Within a type,
  /// points are oldest first on Android (by start time) and newest first on
  /// iOS (by end time), without duplicates.
  ///
  /// Data is read about [pageSize] points per platform call and parsed as set
  /// by [isolateMode], so neither the native side nor the UI has to handle the
  /// whole range at once. The returned list does hold all points: for large
  /// ranges, use [getHealthDataPages] and process the data page by page.
  ///
  /// Throws a [HealthException] with [HealthErrorCode.notSupported] if a type
  /// is not available on this platform or device (before anything is read),
  /// and a [HealthPlatformException] if Health Connect or HealthKit reports an
  /// error, for example [HealthErrorCode.rateLimitExceeded]. The call then
  /// fails as a whole, so do not record sync progress for any of [types].
  /// A missing read permission is not an error: that type simply returns no data.
  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  });

  /// Read health data of [types] between [startTime] and [endTime] page by page.
  ///
  /// Use this instead of [getHealthDataFromTypes] for large ranges, for example
  /// a first sync of months of heart rate data. Each page holds about
  /// [pageSize] points (default [Health.pageSize]). The stream is lazy: nothing
  /// is read until it is listened to, and the next page is read only when the
  /// listener is ready for it (with `await for`, once the loop body has
  /// finished). Memory therefore stays bounded if you process each page and
  /// let it go. [isolateMode] and [Health.pageSize] are read when the stream is
  /// listened to.
  ///
  /// Types are read one after another, in the order of [types], each type
  /// once. Within a type, points are oldest first: in the order of their
  /// records' start times on Android (the samples of a heart rate, speed or
  /// skin temperature record come together), by end time on iOS. Each type ends with exactly one page whose
  /// [HealthDataPage.isLastPageForType] is true (empty if the type has no more
  /// data); other pages are never empty. This is a finite read of the data
  /// stored now, not a live stream of new data, and not a snapshot: data
  /// written while it runs may or may not be included.
  ///
  /// An error ends the stream; pages already delivered stay valid. The error is
  /// a [RangeError] for an invalid [pageSize], a [HealthException] with
  /// [HealthErrorCode.notSupported] if a type is not available on this platform
  /// or device (before anything is read), or a [HealthPlatformException] if
  /// Health Connect or HealthKit reports an error. Cancelling the subscription
  /// stops the read: no platform call is made after the one in flight, whose
  /// page or error is dropped, and the future that `cancel` returns completes
  /// once that call has returned. A missing read permission is not an error:
  /// that type returns one empty page, with
  /// [HealthDataPage.readPermissionDenied] set on Android.
  ///
  /// On Android every page costs Health Connect calls, which count against its
  /// API quota. See the README section "Health Connect limits".
  @override
  Stream<HealthDataPage> getHealthDataPages({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
    Map<HealthDataType, HealthDataUnit>? preferredUnits,
    List<RecordingMethod> recordingMethodsToFilter = const [],
    int? pageSize,
  });

  /// Fetch a list of health data points based on [types].
  /// You can also specify the [recordingMethodsToFilter] to filter the data points.
  /// If not specified, all data points will be included.
  ///
  /// Throws a [HealthPlatformException] if Health Connect or HealthKit reports an error.
  @override
  Future<List<HealthDataPoint>> getHealthIntervalDataFromTypes({
    required DateTime startDate,
    required DateTime endDate,
    required List<HealthDataType> types,
    required int interval,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  });

  /// Fetch a list of health data points based on [types].
  ///
  /// Throws a [HealthPlatformException] if Health Connect or HealthKit reports an error.
  @override
  Future<List<HealthDataPoint>> getHealthAggregateDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startDate,
    required DateTime endDate,
    int activitySegmentDuration = 1,
    bool includeManualEntry = true,
  });

  /// Create a Health Connect changes token for the provided [types].
  ///
  /// Android only. Returns null on iOS or if an error occurs.
  @override
  Future<String?> getChangesToken({required List<HealthDataType> types});

  /// Fetch the next page of changes for a previously created token.
  ///
  /// Android only. Returns null on iOS or if an error occurs, for example when
  /// Health Connect's API quota is used up; try again later.
  ///
  /// [HealthChangesResponse.changesTokenExpired] means the token can no longer
  /// be used: read the data since your last sync (for example with
  /// [getHealthDataPages]) and create a new token. This is also returned when
  /// Health Connect cannot return the pending changes because they are too
  /// large ("Too many records in the cursor"), so poll often enough to keep
  /// the batches small.
  @override
  Future<HealthChangesResponse?> getChanges({required String changesToken, bool includeSelf = false});

  /// Return a list of [HealthDataPoint] based on [points] with no duplicates.
  @override
  List<HealthDataPoint> removeDuplicates(List<HealthDataPoint> points);

  /// Get the total number of steps within a specific time period.
  /// Returns null if not successful, for example when Health Connect's API
  /// quota is used up.
  @override
  Future<int?> getTotalStepsInInterval(DateTime startTime, DateTime endTime, {bool includeManualEntry = true});

  /// Assigns numbers to specific [HealthDataType]s.
  int _alignValue(HealthDataType type) => switch (type) {
    HealthDataType.SLEEP_IN_BED => 0,
    HealthDataType.SLEEP_ASLEEP => 1,
    HealthDataType.SLEEP_AWAKE => 2,
    HealthDataType.SLEEP_LIGHT => 3,
    HealthDataType.SLEEP_DEEP => 4,
    HealthDataType.SLEEP_REM => 5,
    HealthDataType.HEADACHE_UNSPECIFIED => 0,
    HealthDataType.HEADACHE_NOT_PRESENT => 1,
    HealthDataType.HEADACHE_MILD => 2,
    HealthDataType.HEADACHE_MODERATE => 3,
    HealthDataType.HEADACHE_SEVERE => 4,
    _ => throw HealthException(
      type,
      "HealthDataType was not aligned correctly - please report bug at https://github.com/carp-dk/carp-health-flutter/issues",
    ),
  };

  /// Write workout data to Apple Health or Google Health Connect.
  ///
  /// Returns true if the workout data was successfully added.
  ///
  /// Parameters:
  ///  - [activityType] The type of activity performed.
  ///  - [start] The start time of the workout.
  ///  - [end] The end time of the workout.
  ///  - [totalEnergyBurned] The total energy burned during the workout.
  ///  - [totalEnergyBurnedUnit] The UNIT used to measure [totalEnergyBurned]
  ///    *ONLY FOR IOS* Default value is KILOCALORIE.
  ///  - [totalDistance] The total distance traveled during the workout.
  ///  - [totalDistanceUnit] The UNIT used to measure [totalDistance]
  ///    *ONLY FOR IOS* Default value is METER.
  ///  - [title] The title of the workout.
  ///    *ONLY FOR HEALTH CONNECT* Default value is the [activityType], e.g. "STRENGTH_TRAINING".
  ///  - [recordingMethod] The recording method of the data point, automatic by default (on iOS this can only be automatic or manual).
  Future<bool> writeWorkoutData({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalEnergyBurned,
    HealthDataUnit totalEnergyBurnedUnit = HealthDataUnit.KILOCALORIE,
    int? totalDistance,
    HealthDataUnit totalDistanceUnit = HealthDataUnit.METER,
    String? title,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    // Check that value is on the current Platform
    if (Platform.isIOS && !_isOnIOS(activityType)) {
      throw HealthException(activityType, "Workout activity type $activityType is not supported on iOS");
    } else if (Platform.isAndroid && !_isOnAndroid(activityType)) {
      throw HealthException(activityType, "Workout activity type $activityType is not supported on Android");
    }
    final args = <String, dynamic>{
      'activityType': activityType.name,
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
      'totalEnergyBurned': totalEnergyBurned,
      'totalEnergyBurnedUnit': totalEnergyBurnedUnit.name,
      'totalDistance': totalDistance,
      'totalDistanceUnit': totalDistanceUnit.name,
      'title': title,
      'recordingMethod': recordingMethod.toInt(),
    };
    return await _channel.invokeMethod('writeWorkoutData', args) == true;
  }

  /// Write workout data to Apple Health or Google Health Connect and return UUID.
  ///
  /// Returns UUID if the workout data was successfully added, null otherwise.
  ///
  /// Parameters:
  ///  - [activityType] The type of activity performed.
  ///  - [start] The start time of the workout.
  ///  - [end] The end time of the workout.
  ///  - [totalEnergyBurned] The total energy burned during the workout.
  ///  - [totalEnergyBurnedUnit] The UNIT used to measure [totalEnergyBurned]
  ///    *ONLY FOR IOS* Default value is KILOCALORIE.
  ///  - [totalDistance] The total distance traveled during the workout.
  ///  - [totalDistanceUnit] The UNIT used to measure [totalDistance]
  ///    *ONLY FOR IOS* Default value is METER.
  ///  - [title] The title of the workout.
  ///    *ONLY FOR HEALTH CONNECT* Default value is the [activityType], e.g. "STRENGTH_TRAINING".
  ///  - [recordingMethod] The recording method of the data point, automatic by default (on iOS this can only be automatic or manual).
  Future<String?> writeWorkoutDataUUID({
    required HealthWorkoutActivityType activityType,
    required DateTime start,
    required DateTime end,
    int? totalEnergyBurned,
    HealthDataUnit totalEnergyBurnedUnit = HealthDataUnit.KILOCALORIE,
    int? totalDistance,
    HealthDataUnit totalDistanceUnit = HealthDataUnit.METER,
    String? title,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  }) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (Platform.isIOS && [RecordingMethod.active, RecordingMethod.unknown].contains(recordingMethod)) {
      throw ArgumentError("recordingMethod must be manual or automatic on iOS");
    }

    // Check that value is on the current Platform
    if (Platform.isIOS && !_isOnIOS(activityType)) {
      throw HealthException(activityType, "Workout activity type $activityType is not supported on iOS");
    } else if (Platform.isAndroid && !_isOnAndroid(activityType)) {
      throw HealthException(activityType, "Workout activity type $activityType is not supported on Android");
    }
    final args = <String, dynamic>{
      'activityType': activityType.name,
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
      'totalEnergyBurned': totalEnergyBurned,
      'totalEnergyBurnedUnit': totalEnergyBurnedUnit.name,
      'totalDistance': totalDistance,
      'totalDistanceUnit': totalDistanceUnit.name,
      'title': title,
      'recordingMethod': recordingMethod.toInt(),
    };

    String uuid = '${await _channel.invokeMethod('writeWorkoutDataUUID', args)}';

    debugPrint("Added workout data point: $uuid");

    return uuid;
  }

  /// Start a new workout route recording session on iOS or Android.
  ///
  /// Returns a builder identifier that must be supplied in subsequent calls
  /// to [insertWorkoutRouteData], [finishWorkoutRoute], or
  /// [discardWorkoutRoute].
  Future<String> startWorkoutRoute() async {
    final identifier = await _channel.invokeMethod<String>('startWorkoutRoute');
    if (identifier == null) {
      throw PlatformException(code: 'ROUTE_ERROR', message: 'Failed to start workout route builder.');
    }
    return identifier;
  }

  /// Append a batch of [locations] to an active workout route builder.
  ///
  /// The [builderId] must come from [startWorkoutRoute]. Locations should
  /// be ordered by ascending timestamp to mirror HealthKit’s expectations.
  Future<bool> insertWorkoutRouteData({
    required String builderId,
    required List<WorkoutRouteLocation> locations,
  }) async {
    final args = <String, dynamic>{
      'builderId': builderId,
      'locations': locations.map(_serializeWorkoutRouteLocationForNative).toList(),
    };
    return await _channel.invokeMethod<bool>('insertWorkoutRouteData', args) == true;
  }

  /// Finalises the workout route and associates it with an existing workout.
  ///
  /// Provide the [builderId] from [startWorkoutRoute], the platform-specific
  /// [workoutUuid] (as returned from [writeWorkoutData] or another mechanism),
  /// and optional [metadata] that will be stored on the resulting route.
  ///
  /// Returns the created route’s UUID string.
  Future<String> finishWorkoutRoute({
    required String builderId,
    required String workoutUuid,
    Map<String, dynamic>? metadata,
  }) async {
    final args = <String, dynamic>{
      'builderId': builderId,
      'workoutUUID': workoutUuid,
      if (metadata != null) 'metadata': Map<String, dynamic>.from(metadata),
    };
    final response = await _channel.invokeMapMethod<String, dynamic>('finishWorkoutRoute', args);
    final routeUuid = response?['uuid'] as String?;
    if (routeUuid == null) {
      throw PlatformException(code: 'ROUTE_ERROR', message: 'Workout route completion failed.');
    }
    return routeUuid;
  }

  /// Discards any progress for the specified workout route builder.
  ///
  /// Returns `true` if the builder existed and was discarded successfully.
  Future<bool> discardWorkoutRoute(String builderId) async {
    final args = <String, dynamic>{'builderId': builderId};
    return await _channel.invokeMethod<bool>('discardWorkoutRoute', args) == true;
  }

  /// Check if the given [HealthWorkoutActivityType] is supported on the iOS platform
  bool _isOnIOS(HealthWorkoutActivityType type) {
    // Returns true if the type is part of the iOS set
    return {
      HealthWorkoutActivityType.AMERICAN_FOOTBALL,
      HealthWorkoutActivityType.ARCHERY,
      HealthWorkoutActivityType.AUSTRALIAN_FOOTBALL,
      HealthWorkoutActivityType.BADMINTON,
      HealthWorkoutActivityType.BARRE,
      HealthWorkoutActivityType.BASEBALL,
      HealthWorkoutActivityType.BASKETBALL,
      HealthWorkoutActivityType.BIKING,
      HealthWorkoutActivityType.BOWLING,
      HealthWorkoutActivityType.BOXING,
      HealthWorkoutActivityType.CARDIO_DANCE,
      HealthWorkoutActivityType.CLIMBING,
      HealthWorkoutActivityType.COOLDOWN,
      HealthWorkoutActivityType.CORE_TRAINING,
      HealthWorkoutActivityType.CRICKET,
      HealthWorkoutActivityType.CROSS_COUNTRY_SKIING,
      HealthWorkoutActivityType.CROSS_TRAINING,
      HealthWorkoutActivityType.CURLING,
      HealthWorkoutActivityType.DISC_SPORTS,
      HealthWorkoutActivityType.DOWNHILL_SKIING,
      HealthWorkoutActivityType.ELLIPTICAL,
      HealthWorkoutActivityType.EQUESTRIAN_SPORTS,
      HealthWorkoutActivityType.FENCING,
      HealthWorkoutActivityType.FISHING,
      HealthWorkoutActivityType.FITNESS_GAMING,
      HealthWorkoutActivityType.FLEXIBILITY,
      HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
      HealthWorkoutActivityType.GOLF,
      HealthWorkoutActivityType.GYMNASTICS,
      HealthWorkoutActivityType.HAND_CYCLING,
      HealthWorkoutActivityType.HANDBALL,
      HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
      HealthWorkoutActivityType.HIKING,
      HealthWorkoutActivityType.HOCKEY,
      HealthWorkoutActivityType.HUNTING,
      HealthWorkoutActivityType.JUMP_ROPE,
      HealthWorkoutActivityType.KICKBOXING,
      HealthWorkoutActivityType.LACROSSE,
      HealthWorkoutActivityType.MARTIAL_ARTS,
      HealthWorkoutActivityType.MIND_AND_BODY,
      HealthWorkoutActivityType.MIXED_CARDIO,
      HealthWorkoutActivityType.OTHER,
      HealthWorkoutActivityType.PADDLE_SPORTS,
      HealthWorkoutActivityType.PICKLEBALL,
      HealthWorkoutActivityType.PILATES,
      HealthWorkoutActivityType.PLAY,
      HealthWorkoutActivityType.PREPARATION_AND_RECOVERY,
      HealthWorkoutActivityType.RACQUETBALL,
      HealthWorkoutActivityType.ROWING,
      HealthWorkoutActivityType.RUGBY,
      HealthWorkoutActivityType.RUNNING,
      HealthWorkoutActivityType.SAILING,
      HealthWorkoutActivityType.SKATING,
      HealthWorkoutActivityType.SNOW_SPORTS,
      HealthWorkoutActivityType.SNOWBOARDING,
      HealthWorkoutActivityType.SOCCER,
      HealthWorkoutActivityType.SOCIAL_DANCE,
      HealthWorkoutActivityType.SOFTBALL,
      HealthWorkoutActivityType.SQUASH,
      HealthWorkoutActivityType.STAIR_CLIMBING,
      HealthWorkoutActivityType.STAIRS,
      HealthWorkoutActivityType.STEP_TRAINING,
      HealthWorkoutActivityType.SURFING,
      HealthWorkoutActivityType.SWIMMING,
      HealthWorkoutActivityType.TABLE_TENNIS,
      HealthWorkoutActivityType.TAI_CHI,
      HealthWorkoutActivityType.TENNIS,
      HealthWorkoutActivityType.TRACK_AND_FIELD,
      HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
      HealthWorkoutActivityType.VOLLEYBALL,
      HealthWorkoutActivityType.WALKING,
      HealthWorkoutActivityType.WATER_FITNESS,
      HealthWorkoutActivityType.WATER_POLO,
      HealthWorkoutActivityType.WATER_SPORTS,
      HealthWorkoutActivityType.WHEELCHAIR_RUN_PACE,
      HealthWorkoutActivityType.WHEELCHAIR_WALK_PACE,
      HealthWorkoutActivityType.WRESTLING,
      HealthWorkoutActivityType.YOGA,
      HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
      HealthWorkoutActivityType.SWIMMING_POOL,
      HealthWorkoutActivityType.UNDERWATER_DIVING,
    }.contains(type);
  }

  /// Check if the given [HealthWorkoutActivityType] is supported on the Android platform
  bool _isOnAndroid(HealthWorkoutActivityType type) {
    // Returns true if the type is part of the Android set
    return {
      // Both
      HealthWorkoutActivityType.AMERICAN_FOOTBALL,
      HealthWorkoutActivityType.ARCHERY,
      HealthWorkoutActivityType.AUSTRALIAN_FOOTBALL,
      HealthWorkoutActivityType.BADMINTON,
      HealthWorkoutActivityType.BASEBALL,
      HealthWorkoutActivityType.BASKETBALL,
      HealthWorkoutActivityType.BIKING,
      HealthWorkoutActivityType.BOXING,
      HealthWorkoutActivityType.CARDIO_DANCE,
      HealthWorkoutActivityType.CRICKET,
      HealthWorkoutActivityType.CROSS_COUNTRY_SKIING,
      HealthWorkoutActivityType.CURLING,
      HealthWorkoutActivityType.DOWNHILL_SKIING,
      HealthWorkoutActivityType.ELLIPTICAL,
      HealthWorkoutActivityType.FENCING,
      HealthWorkoutActivityType.GOLF,
      HealthWorkoutActivityType.GYMNASTICS,
      HealthWorkoutActivityType.HANDBALL,
      HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
      HealthWorkoutActivityType.HIKING,
      HealthWorkoutActivityType.HOCKEY,
      HealthWorkoutActivityType.MARTIAL_ARTS,
      HealthWorkoutActivityType.PILATES,
      HealthWorkoutActivityType.RACQUETBALL,
      HealthWorkoutActivityType.ROWING,
      HealthWorkoutActivityType.RUGBY,
      HealthWorkoutActivityType.RUNNING,
      HealthWorkoutActivityType.SAILING,
      HealthWorkoutActivityType.SKATING,
      HealthWorkoutActivityType.SNOWBOARDING,
      HealthWorkoutActivityType.SOCCER,
      HealthWorkoutActivityType.SOCIAL_DANCE,
      HealthWorkoutActivityType.SOFTBALL,
      HealthWorkoutActivityType.SQUASH,
      HealthWorkoutActivityType.STAIR_CLIMBING,
      HealthWorkoutActivityType.TABLE_TENNIS,
      HealthWorkoutActivityType.TENNIS,
      HealthWorkoutActivityType.VOLLEYBALL,
      HealthWorkoutActivityType.WALKING,
      HealthWorkoutActivityType.WATER_POLO,
      HealthWorkoutActivityType.WHEELCHAIR_RUN_PACE,
      HealthWorkoutActivityType.WHEELCHAIR_WALK_PACE,
      HealthWorkoutActivityType.YOGA,

      // Android only
      HealthWorkoutActivityType.BIKING_STATIONARY,
      HealthWorkoutActivityType.CALISTHENICS,
      HealthWorkoutActivityType.DANCING,
      HealthWorkoutActivityType.FRISBEE_DISC,
      HealthWorkoutActivityType.GUIDED_BREATHING,
      HealthWorkoutActivityType.ICE_SKATING,
      HealthWorkoutActivityType.PARAGLIDING,
      HealthWorkoutActivityType.ROCK_CLIMBING,
      HealthWorkoutActivityType.ROWING_MACHINE,
      HealthWorkoutActivityType.RUNNING_TREADMILL,
      HealthWorkoutActivityType.SCUBA_DIVING,
      HealthWorkoutActivityType.SKIING,
      HealthWorkoutActivityType.SNOWSHOEING,
      HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE,
      HealthWorkoutActivityType.STRENGTH_TRAINING,
      HealthWorkoutActivityType.SURFING,
      HealthWorkoutActivityType.SWIMMING_OPEN_WATER,
      HealthWorkoutActivityType.SWIMMING_POOL,
      HealthWorkoutActivityType.WALKING_TREADMILL,
      HealthWorkoutActivityType.WEIGHTLIFTING,
      HealthWorkoutActivityType.WHEELCHAIR,
      HealthWorkoutActivityType.OTHER,
    }.contains(type);
  }
}

Map<String, dynamic> _serializeWorkoutRouteLocationForNative(WorkoutRouteLocation location) {
  final map = <String, dynamic>{
    'latitude': location.latitude,
    'longitude': location.longitude,
    'timestamp': location.timestamp.toUtc().millisecondsSinceEpoch,
  };
  void addIfNotNull(String key, Object? value) {
    if (value != null) map[key] = value;
  }

  addIfNotNull('altitude', location.altitude);
  addIfNotNull('horizontalAccuracy', location.horizontalAccuracy);
  addIfNotNull('verticalAccuracy', location.verticalAccuracy);
  addIfNotNull('speed', location.speed);
  addIfNotNull('course', location.course);
  addIfNotNull('speedAccuracy', location.speedAccuracy);
  addIfNotNull('courseAccuracy', location.courseAccuracy);

  return map;
}
