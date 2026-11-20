part of '../health.dart';

enum HealthChangeType { upsert, delete }

final Map<String, HealthDataType> _healthDataTypesByName = HealthDataType.values.asNameMap();

HealthDataType? _healthDataTypeFromName(String? name) => name == null ? null : _healthDataTypesByName[name];

class HealthChange {
  final HealthChangeType type;
  final HealthDataType? dataType;
  final HealthDataPoint? dataPoint;
  final String? recordId;
  final Map<String, dynamic>? rawDataPoint;

  HealthChange._({required this.type, this.dataType, this.dataPoint, this.recordId, this.rawDataPoint});

  /// [sourceDeviceId] becomes the [HealthDataPoint.sourceDeviceId] of [dataPoint]
  /// ('unknown' if omitted).
  factory HealthChange.fromMethodChannel(Map<dynamic, dynamic> map, {String? sourceDeviceId}) {
    final typeName = map['type'] as String?;
    final type = HealthChangeType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => HealthChangeType.upsert,
    );

    if (type == HealthChangeType.delete) {
      return HealthChange._(type: type, recordId: map['recordId'] as String?);
    }

    final rawPoint = map['dataPoint'] as Map?;
    final dataTypeKey = map['dataTypeKey'] as String?;
    final resolvedDataType = _healthDataTypeFromName(dataTypeKey);

    HealthDataPoint? dataPoint;
    Map<String, dynamic>? rawDataPoint;
    if (rawPoint != null) {
      rawDataPoint = Map<String, dynamic>.from(rawPoint);
      if (dataTypeKey != null && resolvedDataType != null) {
        dataPoint = HealthDataPoint.fromHealthDataPoint(
          resolvedDataType,
          rawDataPoint,
          null,
          sourceDeviceId: sourceDeviceId,
        );
      }
    }

    return HealthChange._(
      type: HealthChangeType.upsert,
      dataType: resolvedDataType,
      dataPoint: dataPoint,
      rawDataPoint: rawDataPoint,
    );
  }
}

class HealthChangesResponse {
  final List<HealthChange> changes;
  final String nextChangesToken;
  final bool hasMore;
  final bool changesTokenExpired;

  HealthChangesResponse({
    required this.changes,
    required this.nextChangesToken,
    required this.hasMore,
    required this.changesTokenExpired,
  });

  List<HealthDataPoint> get upsertedDataPoints => changes
      .where((change) => change.type == HealthChangeType.upsert)
      .map((change) => change.dataPoint)
      .whereType<HealthDataPoint>()
      .toList();

  List<String> get deletedRecordIds => changes
      .where((change) => change.type == HealthChangeType.delete)
      .map((change) => change.recordId)
      .whereType<String>()
      .toList();

  /// [sourceDeviceId] becomes the [HealthDataPoint.sourceDeviceId] of the
  /// changed points ('unknown' if omitted).
  factory HealthChangesResponse.fromMethodChannel(Map<dynamic, dynamic> map, {String? sourceDeviceId}) {
    final rawChanges = map['changes'] as List? ?? const [];
    final changes = rawChanges
        .whereType<Map<dynamic, dynamic>>()
        .map((change) => HealthChange.fromMethodChannel(change, sourceDeviceId: sourceDeviceId))
        .toList();

    return HealthChangesResponse(
      changes: changes,
      nextChangesToken: map['nextChangesToken'] as String? ?? '',
      hasMore: map['hasMore'] as bool? ?? false,
      changesTokenExpired: map['changesTokenExpired'] as bool? ?? false,
    );
  }
}
