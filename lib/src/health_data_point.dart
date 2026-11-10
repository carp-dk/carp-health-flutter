part of '../health.dart';

/// Types of health platforms.
enum HealthPlatformType { appleHealth, googleHealthConnect }

/// A [HealthDataPoint] object corresponds to a data point capture from
/// Apple HealthKit or Google Health Connect with a [HealthValue]
/// as value.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class HealthDataPoint {
  /// UUID of the data point.
  String uuid;

  /// The quantity value of the data point
  HealthValue value;

  /// The type of the data point.
  HealthDataType type;

  /// The data point type as a string.
  String get typeString => type.name;

  /// The unit of the data point.
  HealthDataUnit unit;

  /// The data point unit as a string.
  String get unitString => unit.name;

  /// The start of the time interval.
  DateTime dateFrom;

  /// The end of the time interval.
  DateTime dateTo;

  /// The health platform that this data point was fetched.
  HealthPlatformType sourcePlatform;

  /// The id of the device from which the data point was fetched.
  String sourceDeviceId;

  /// The id of the source from which the data point was fetched.
  String sourceId;

  /// The name of the source from which the data point was fetched.
  String sourceName;

  /// How the data point was recorded
  /// (on Android: https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata#summary)
  /// on iOS: either user entered or manual https://developer.apple.com/documentation/healthkit/hkmetadatakeywasuserentered)
  RecordingMethod recordingMethod;

  /// The summary of the workout data point, if available.
  WorkoutSummary? workoutSummary;

  /// The metadata for this data point.
  Map<String, dynamic>? metadata;

  /// The model of the device that recorded the data: on iOS HealthKit's `HKDevice.model`, such as `iPhone`
  /// or `Watch`, and on Android the `model` of Health Connect's `Device`, such as `Pixel Watch 2`. Null when
  /// the app that wrote the data reported no device, or no model for it.
  String? deviceModel;

  HealthDataPoint({
    required this.uuid,
    required this.value,
    required this.type,
    required this.unit,
    required this.dateFrom,
    required this.dateTo,
    required this.sourcePlatform,
    required this.sourceDeviceId,
    required this.sourceId,
    required this.sourceName,
    this.recordingMethod = RecordingMethod.unknown,
    this.workoutSummary,
    this.metadata,
    this.deviceModel,
  });

  /// The types whose native value is a category, not an amount:
  /// [HealthDataPoint.fromHealthDataPoint] sets their value to the minutes
  /// from `date_from` to `date_to` instead.
  static const _durationTypes = {
    HealthDataType.MINDFULNESS,
    HealthDataType.HEADACHE_UNSPECIFIED,
    HealthDataType.HEADACHE_NOT_PRESENT,
    HealthDataType.HEADACHE_MILD,
    HealthDataType.HEADACHE_MODERATE,
    HealthDataType.HEADACHE_SEVERE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_AWAKE_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_UNKNOWN,
    HealthDataType.SLEEP_OUT_OF_BED,
  };

  static final Map<String, HealthDataUnit> _unitsByName = HealthDataUnit.values.asNameMap();

  /// The minutes from [from] to [to].
  static NumericHealthValue _minutesBetween(DateTime from, DateTime to) =>
      NumericHealthValue(numericValue: (to.millisecondsSinceEpoch - from.millisecondsSinceEpoch) / (1000 * 60));

  /// Create a [HealthDataPoint] from json.
  factory HealthDataPoint.fromJson(Map<String, dynamic> json) => _$HealthDataPointFromJson(json);

  /// Convert this [HealthDataPoint] to json.
  Map<String, dynamic> toJson() => _$HealthDataPointToJson(this);

  /// Create a [HealthDataPoint] based on a health data point from native data format.
  ///
  /// [sourceDeviceId] is 'unknown' if omitted. The plugin passes the id of the
  /// device it runs on (see [Health.deviceId]).
  factory HealthDataPoint.fromHealthDataPoint(
    HealthDataType dataType,
    dynamic dataPoint,
    String? unitName, {
    String? sourceDeviceId,
  }) {
    // Parsing can run in a worker isolate, which has its own registry.
    _registerFromJsonFunctions();

    final DateTime from = DateTime.fromMillisecondsSinceEpoch(dataPoint['date_from'] as int);
    final DateTime to = DateTime.fromMillisecondsSinceEpoch(dataPoint['date_to'] as int);

    // Handling different [HealthValue] types
    HealthValue value = switch (dataType) {
      _ when _durationTypes.contains(dataType) => _minutesBetween(from, to),
      HealthDataType.AUDIOGRAM => AudiogramHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.WORKOUT => WorkoutHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.WORKOUT_ROUTE => WorkoutRouteHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.ELECTROCARDIOGRAM => ElectrocardiogramHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.NUTRITION => NutritionHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.INSULIN_DELIVERY => InsulinDeliveryHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.MENSTRUATION_FLOW => MenstruationFlowHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.ACTIVITY_INTENSITY => ActivityIntensityHealthValue.fromHealthDataPoint(dataPoint),
      HealthDataType.SKIN_TEMPERATURE => SkinTemperatureHealthValue.fromHealthDataPoint(dataPoint),
      _ => NumericHealthValue.fromHealthDataPoint(dataPoint),
    };

    final String sourceId = dataPoint["source_id"] as String;
    final String sourceName = dataPoint["source_name"] as String;
    final Map<String, dynamic>? metadata = dataPoint["metadata"] == null
        ? null
        : Map<String, dynamic>.from(dataPoint['metadata'] as Map);
    final HealthDataUnit unit = _unitsByName[unitName] ?? dataTypeToUnit[dataType] ?? HealthDataUnit.UNKNOWN_UNIT;
    final String? uuid = dataPoint["uuid"] as String?;
    final String? deviceModel = dataPoint["device_model"] as String?;

    // Set WorkoutSummary, if available. Android sends only the camelCase keys.
    WorkoutSummary? workoutSummary;
    if (dataPoint["workout_type"] != null ||
        dataPoint["total_distance"] != null ||
        dataPoint["total_energy_burned"] != null ||
        dataPoint["total_steps"] != null ||
        dataPoint["workoutActivityType"] != null) {
      workoutSummary = WorkoutSummary.fromHealthDataPoint(dataPoint);
    }

    var recordingMethod = dataPoint["recording_method"] as int?;

    return HealthDataPoint(
      uuid: uuid ?? "",
      value: value,
      type: dataType,
      unit: unit,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: Platform.isIOS ? HealthPlatformType.appleHealth : HealthPlatformType.googleHealthConnect,
      sourceDeviceId: sourceDeviceId ?? 'unknown',
      sourceId: sourceId,
      sourceName: sourceName,
      recordingMethod: RecordingMethod.fromInt(recordingMethod),
      workoutSummary: workoutSummary,
      metadata: metadata,
      deviceModel: deviceModel,
    );
  }

  @override
  String toString() =>
      """$runtimeType -
    uuid: $uuid,
    value: ${value.toString()},
    unit: ${unit.name},
    dateFrom: $dateFrom,
    dateTo: $dateTo,
    dataType: ${type.name},
    platform: $sourcePlatform,
    deviceId: $sourceDeviceId,
    sourceId: $sourceId,
    sourceName: $sourceName
    recordingMethod: $recordingMethod
    workoutSummary: $workoutSummary
    metadata: $metadata
    deviceModel: $deviceModel""";

  @override
  bool operator ==(Object other) =>
      other is HealthDataPoint &&
      uuid == other.uuid &&
      value == other.value &&
      unit == other.unit &&
      dateFrom == other.dateFrom &&
      dateTo == other.dateTo &&
      type == other.type &&
      sourcePlatform == other.sourcePlatform &&
      sourceDeviceId == other.sourceDeviceId &&
      sourceId == other.sourceId &&
      sourceName == other.sourceName &&
      recordingMethod == other.recordingMethod &&
      _deepEquals(metadata, other.metadata) &&
      deviceModel == other.deviceModel;

  @override
  int get hashCode => Object.hash(
    uuid,
    value,
    unit,
    dateFrom,
    dateTo,
    type,
    sourcePlatform,
    sourceDeviceId,
    sourceId,
    sourceName,
    _deepHash(metadata),
    deviceModel,
  );
}
