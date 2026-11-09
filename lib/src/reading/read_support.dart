part of '../../health.dart';

/// What the reads of [Health] share: the checks before a read, the id of this
/// device, and the platform call whose reply is parsed.
mixin _HealthReadSupport on _HealthSupport {
  /// The id of this device as [HealthDataPoint.sourceDeviceId]: looked up once,
  /// and 'unknown' (but looked up again next time) if that fails.
  Future<String> _resolveDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    try {
      final String? id = Platform.isAndroid
          ? (await _deviceInfo.androidInfo).id
          : (await _deviceInfo.iosInfo).identifierForVendor;
      if (id != null && id.isNotEmpty) _deviceId = id;
    } catch (e) {
      debugPrint('$runtimeType - could not resolve device id: $e');
    }
    return deviceId;
  }

  /// The checks before a read: Health Connect must be installed and every type
  /// available, before anything is read and so before any quota is spent.
  /// Returns [types] without duplicates, in order, and the id of this device.
  /// Once [cancellation] is set, no further platform call is made.
  Future<({List<HealthDataType> types, String deviceId})> _prepareRead(
    List<HealthDataType> types, [
    _ReadCancellation? cancellation,
  ]) async {
    cancellation?.throwIfCancelled();
    await _checkIfHealthConnectAvailableOnAndroid();
    final uniqueTypes = LinkedHashSet<HealthDataType>.of(types).toList();
    if (uniqueTypes.isEmpty) return (types: uniqueTypes, deviceId: deviceId);
    await _checkTypesAvailable(uniqueTypes, cancellation);
    cancellation?.throwIfCancelled();
    return (types: uniqueTypes, deviceId: await _resolveDeviceId());
  }

  /// The units Health Connect values are converted to besides the default unit
  /// of their type ([dataTypeToUnit]); the Android side returns every other type
  /// in its default unit.
  static const _androidUnits = <HealthDataType, Set<HealthDataUnit>>{
    HealthDataType.WEIGHT: {HealthDataUnit.POUND},
    HealthDataType.HEIGHT: {HealthDataUnit.CENTIMETER, HealthDataUnit.INCH},
    HealthDataType.BODY_TEMPERATURE: {HealthDataUnit.DEGREE_FAHRENHEIT, HealthDataUnit.KELVIN},
    HealthDataType.SKIN_TEMPERATURE: {HealthDataUnit.DEGREE_FAHRENHEIT, HealthDataUnit.KELVIN},
    HealthDataType.BLOOD_GLUCOSE: {HealthDataUnit.MILLIMOLES_PER_LITER},
  };

  /// Throws an [HealthErrorCode.invalidArgument] [HealthException] if a unit in
  /// [preferredUnits] for one of [types] is one that Health Connect values are
  /// not converted to: they would be labelled with a unit they are not in.
  /// HealthKit converts to any unit of the same kind and reports other units
  /// itself.
  void _checkPreferredUnits(List<HealthDataType> types, Map<HealthDataType, HealthDataUnit>? preferredUnits) {
    if (!Platform.isAndroid || preferredUnits == null) return;
    for (final type in types) {
      final unit = preferredUnits[type];
      if (unit == null || unit == dataTypeToUnit[type] || (_androidUnits[type]?.contains(unit) ?? false)) continue;
      throw HealthException(
        type,
        'Health Connect values of $type are not converted to ${unit.name}',
        errorCode: HealthErrorCode.invalidArgument,
      );
    }
  }

  /// Checks every type before the first read, so an unsupported type does not
  /// fail a multi-type read after quota was spent on the others.
  Future<void> _checkTypesAvailable(List<HealthDataType> types, [_ReadCancellation? cancellation]) async {
    for (final type in types) {
      cancellation?.throwIfCancelled();
      await _checkIfDataTypeAvailableOnDevice(type);
      if (!isDataTypeAvailable(type)) {
        throw HealthException(type, 'Not available on platform $platformType', errorCode: HealthErrorCode.notSupported);
      }
    }
  }

  /// Sends [method] and turns the reply into a [T] with [parse], in a worker
  /// isolate or in this one depending on [mode]. Errors reported by the
  /// platform are thrown as [HealthPlatformException]s; a missing native
  /// implementation as a [MissingPluginException].
  Future<T> _invokeAndParse<T>(
    String method,
    Object? arguments,
    T Function(Object?, _ParseRequest) parse,
    _ParseRequest request,
    HealthIsolateMode mode,
  ) async {
    // Sent from the calling isolate, so mocks on the root isolate and calls
    // from background isolates both work.
    final reply = await Health._channel.binaryMessenger.send(
      Health._channel.name,
      Health._channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    );
    if (reply == null) {
      throw MissingPluginException('No implementation found for method $method on channel ${Health._channel.name}');
    }
    // A StandardMethodCodec envelope starts with 0 for success, 1 for an error.
    // Error envelopes are small and decoded here, keeping the caller's stack trace.
    final isSuccess = reply.lengthInBytes > 0 && reply.getUint8(0) == 0;
    if (isSuccess && _useWorker(mode, reply.lengthInBytes)) {
      return _parseInWorker(reply, parse, request);
    }
    final Object? decoded;
    try {
      decoded = Health._channel.codec.decodeEnvelope(reply);
    } on PlatformException catch (error) {
      throw HealthPlatformException(request.dataType, error);
    }
    return parse(decoded, request);
  }
}
