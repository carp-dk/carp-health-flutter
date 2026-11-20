part of '../../health.dart';

/// Part of [Health]: checking, requesting and revoking the permissions to read
/// and write health data types. The Health Connect permissions to read health
/// data history and in the background are in [HealthConnectFeatures].
// ignore: library_private_types_in_public_api
mixin HealthPermissions on _HealthSupport {
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
  ///    It returns true only if every type has it, so check one type per call to tell which are missing.
  ///
  ///  * On Android, a granted permission does not mean that the device's Health Connect has the type: on Android 15
  ///    at SDK extension 13, the [HealthDataType.MINDFULNESS] permissions can be granted (for example with
  ///    `adb shell pm grant`) while [Health.isMindfulnessSessionAvailable] is false. Check the type's feature with the
  ///    `is...Available` methods instead.
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

    return await Health._channel.invokeMethod('hasPermissions', {
      "types": mTypes.map((type) => type.name).toList(),
      "permissions": mPermissions,
    });
  }

  /// Requests permissions to access health data [types].
  ///
  /// Returns:
  ///
  ///  * on Android, true if at least one of the requested permissions is
  ///    granted when the Health Connect permission dialog closes (also one
  ///    granted before), and false if none is, if the dialog cannot be shown
  ///    (for example when the app's activity is not a
  ///    `FlutterFragmentActivity`), or while another permission request waits
  ///    for the dialog. True does not mean that every requested permission
  ///    was granted: the user may allow only some, and the dialog does not
  ///    offer the permissions of a type the device's Health Connect does not
  ///    have (on Android 15 at SDK extension 13, a request for only
  ///    [HealthDataType.MINDFULNESS] returns false at once). Check
  ///    [hasPermissions] for each type that matters;
  ///  * on iOS, true if HealthKit completed the request, whether or not it
  ///    showed the authorization sheet and whatever the user chose, and false
  ///    if HealthKit reported an error or this iOS version has none of
  ///    [types].
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
  ///    a data type due to privacy concern, true on iOS does not mean that read
  ///    access was granted (see [getRequestStatusForAuthorization]).
  ///
  /// Throws an [ArgumentError] for WRITE or READ_WRITE access to a type that
  /// HealthKit lets apps only read, where HealthKit would crash the app:
  /// [HealthDataType.ELECTROCARDIOGRAM], the heart rate events,
  /// [HealthDataType.WALKING_HEART_RATE],
  /// [HealthDataType.ATRIAL_FIBRILLATION_BURDEN],
  /// [HealthDataType.APPLE_STAND_HOUR], [HealthDataType.APPLE_MOVE_TIME],
  /// [HealthDataType.APPLE_STAND_TIME], [HealthDataType.EXERCISE_TIME],
  /// [HealthDataType.SLEEP_WRIST_TEMPERATURE],
  /// [HealthDataType.WALKING_ASYMMETRY_PERCENTAGE],
  /// [HealthDataType.APPLE_WALKING_STEADINESS] and
  /// [HealthDataType.APPLE_SLEEPING_BREATHING_DISTURBANCES].
  Future<bool> requestAuthorization(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async {
    await _checkIfHealthConnectAvailableOnAndroid();
    if (permissions != null && permissions.length != types.length) {
      throw ArgumentError('The length of [types] must be same as that of [permissions].');
    }
    if (permissions != null) _checkWriteAccess(types, permissions);

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
    final bool? isAuthorized = await Health._channel.invokeMethod('requestAuthorization', {
      'types': keys,
      "permissions": mPermissions,
    });
    return isAuthorized ?? false;
  }

  /// Whether [requestAuthorization] with the same [types] and [permissions]
  /// would show the authorization sheet, so apps can tell a first request from
  /// one the user has already answered. Uses HealthKit's
  /// [`getRequestStatusForAuthorization`](https://developer.apple.com/documentation/healthkit/hkhealthstore/2994346-getrequeststatusforauthorization).
  ///
  /// It does not tell whether read access was granted, which HealthKit does
  /// not disclose (this is why [hasPermissions] returns null for read access on
  /// iOS).
  ///
  /// [permissions] are as for [requestAuthorization]: if given, its length
  /// must be that of [types]; if not, read access is asked for every type.
  /// Throws an [ArgumentError] for write access to a type that HealthKit only
  /// lets apps read, as [requestAuthorization] does, and a [PlatformException]
  /// if HealthKit fails to determine the status, which HealthKit reports as
  /// [HealthAuthorizationRequestStatus.unknown] together with an error.
  ///
  /// iOS only. Returns null on Android, where [hasPermissions] tells whether
  /// the permissions were granted.
  Future<HealthAuthorizationRequestStatus?> getRequestStatusForAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async {
    if (permissions != null && permissions.length != types.length) {
      throw ArgumentError('The length of [types] must be same as that of [permissions].');
    }
    if (platformType != HealthPlatformType.appleHealth) return null;
    if (permissions != null) _checkWriteAccess(types, permissions);

    final status = await Health._channel.invokeMethod<String>('getRequestStatusForAuthorization', {
      'types': types.map((type) => type.name).toList(),
      'permissions': permissions == null
          ? List<int>.filled(types.length, HealthDataAccess.READ.index)
          : permissions.map((permission) => permission.index).toList(),
    });
    return HealthAuthorizationRequestStatus.fromString(status);
  }

  /// Throws an [ArgumentError] if [permissions] asks for write access to one
  /// of the [_readOnlyTypesIOS] at the same index in [types].
  void _checkWriteAccess(List<HealthDataType> types, List<HealthDataAccess> permissions) {
    for (int i = 0; i < types.length; i++) {
      if (_readOnlyTypesIOS.contains(types[i]) && permissions[i] != HealthDataAccess.READ) {
        throw ArgumentError(
          'Requesting WRITE permission on ${types[i].name} is not allowed: HealthKit only lets apps read it.',
        );
      }
    }
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
      await Health._channel.invokeMethod('revokePermissions');
    } catch (e) {
      debugPrint('$runtimeType - Exception in revokePermissions(): $e');
    }
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
}
