part of '../health.dart';

enum HealthChangeType { upsert, delete }

HealthDataType? _healthDataTypeFromName(String? name) {
  if (name == null) {
    return null;
  }

  for (final type in HealthDataType.values) {
    if (type.name == name) {
      return type;
    }
  }
  return null;
}

class HealthChange {
  final HealthChangeType type;
  final HealthDataType? dataType;
  final HealthDataPoint? dataPoint;
  final String? recordId;
  final Map<String, dynamic>? rawDataPoint;

  HealthChange._({
    required this.type,
    this.dataType,
    this.dataPoint,
    this.recordId,
    this.rawDataPoint,
  });

  factory HealthChange.fromMethodChannel(Map<dynamic, dynamic> map) {
    final typeName = map['type'] as String?;
    final type = HealthChangeType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => HealthChangeType.upsert,
    );

    if (type == HealthChangeType.delete) {
      return HealthChange._(
        type: type,
        recordId: map['recordId'] as String?,
      );
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

  List<HealthDataPoint> get upsertedDataPoints =>
      changes.where((change) => change.type == HealthChangeType.upsert).map((change) => change.dataPoint).whereType<HealthDataPoint>().toList();

  List<String> get deletedRecordIds =>
      changes.where((change) => change.type == HealthChangeType.delete).map((change) => change.recordId).whereType<String>().toList();

  factory HealthChangesResponse.fromMethodChannel(Map<dynamic, dynamic> map) {
    final rawChanges = map['changes'] as List? ?? const [];
    final changes = rawChanges
      .whereType<Map<dynamic, dynamic>>()
      .map((change) => HealthChange.fromMethodChannel(change))
      .toList();

    return HealthChangesResponse(
      changes: changes,
      nextChangesToken: map['nextChangesToken'] as String? ?? '',
      hasMore: map['hasMore'] as bool? ?? false,
      changesTokenExpired: map['changesTokenExpired'] as bool? ?? false,
    );
  }
}
