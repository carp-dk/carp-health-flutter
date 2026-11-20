part of '../health.dart';

/// What [Health] and its mixins use from each other. [Health] and its public
/// mixins implement these members.
///
/// The public mixins are `on` this one, or on the read support built on it.
/// That keeps them parts of [Health], so the lint against private types in
/// public APIs is ignored on them.
///
/// The public members are hidden from the docs here, so that dartdoc documents
/// each of them once, where it is implemented, and not again on every mixin.
mixin _HealthSupport {
  // Implemented by Health.
  abstract String? _deviceId;
  DeviceInfoPlugin get _deviceInfo;
  abstract HealthConnectSdkStatus _healthConnectSdkStatus;
  Future<void> _checkIfDataTypeAvailableOnDevice(HealthDataType dataType);
  Future<void> _checkIfHealthConnectAvailableOnAndroid();

  /// @nodoc
  String get deviceId;

  /// @nodoc
  HealthPlatformType get platformType;

  /// @nodoc
  HealthIsolateMode get isolateMode;

  /// @nodoc
  int get pageSize;

  /// @nodoc
  bool isDataTypeAvailable(HealthDataType dataType);

  // Implemented by HealthConnectStatus, used by HealthConnectFeatures.

  /// @nodoc
  Future<HealthConnectSdkStatus?> getHealthConnectSdkStatus();

  // Implemented by HealthDataWrites, used by HealthMeasurementWrites.

  /// @nodoc
  Future<bool> writeHealthData({
    required double value,
    HealthDataUnit? unit,
    required HealthDataType type,
    required DateTime startTime,
    String? clientRecordId,
    double? clientRecordVersion,
    DateTime? endTime,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
  });
}
