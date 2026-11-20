part of '../../health.dart';

/// Whether protection was used during sexual activity.
///
/// Maps to Android Health Connect's `SexualActivityRecord.PROTECTION_USED_*`
/// constants and iOS HealthKit's `HKMetadataKeySexualActivityProtectionUsed`
/// boolean metadata key.
enum SexualActivityProtection {
  /// Whether protection was used is unknown or not specified.
  unknown,

  /// Protection was used.
  protected,

  /// Protection was not used.
  unprotected;

  /// Converts an Android Health Connect `SexualActivityRecord.PROTECTION_USED_*`
  /// constant to a [SexualActivityProtection].
  static SexualActivityProtection fromHealthConnect(int? value) => switch (value) {
    1 => SexualActivityProtection.protected,
    2 => SexualActivityProtection.unprotected,
    _ => SexualActivityProtection.unknown,
  };

  /// Converts this value to an Android Health Connect
  /// `SexualActivityRecord.PROTECTION_USED_*` constant.
  int toHealthConnect() => switch (this) {
    SexualActivityProtection.unknown => 0,
    SexualActivityProtection.protected => 1,
    SexualActivityProtection.unprotected => 2,
  };

  /// Converts an iOS HealthKit `HKMetadataKeySexualActivityProtectionUsed`
  /// value (`true`, `false`, or `null` when omitted) to a
  /// [SexualActivityProtection].
  static SexualActivityProtection fromHealthKit(bool? protectionUsed) => switch (protectionUsed) {
    true => SexualActivityProtection.protected,
    false => SexualActivityProtection.unprotected,
    null => SexualActivityProtection.unknown,
  };

  /// Converts this value to an iOS HealthKit
  /// `HKMetadataKeySexualActivityProtectionUsed` boolean, or `null` when
  /// [unknown] (the metadata key is omitted).
  bool? toHealthKit() => switch (this) {
    SexualActivityProtection.unknown => null,
    SexualActivityProtection.protected => true,
    SexualActivityProtection.unprotected => false,
  };
}

/// A [HealthValue] object for sexual activity.
///
/// Represents a Health Connect `SexualActivityRecord` on Android and a
/// HealthKit `HKCategoryTypeIdentifier.sexualActivity` sample on iOS.
@JsonSerializable(includeIfNull: false, explicitToJson: true)
class SexualActivityHealthValue extends HealthValue {
  /// Whether protection was used during the activity.
  final SexualActivityProtection protectionUsed;

  SexualActivityHealthValue({this.protectionUsed = SexualActivityProtection.unknown});

  factory SexualActivityHealthValue.fromHealthDataPoint(dynamic dataPoint) {
    final metadata = dataPoint['metadata'] as Map?;
    final SexualActivityProtection protectionUsed;
    if (Platform.isIOS) {
      protectionUsed = SexualActivityProtection.fromHealthKit(_parseBool(metadata?['HKSexualActivityProtectionUsed']));
    } else if (metadata != null && metadata.containsKey('HKSexualActivityProtectionUsed')) {
      protectionUsed = SexualActivityProtection.fromHealthKit(_parseBool(metadata['HKSexualActivityProtectionUsed']));
    } else {
      final rawValue = (dataPoint['value'] as num?)?.toInt();
      protectionUsed = SexualActivityProtection.fromHealthConnect(rawValue);
    }

    return SexualActivityHealthValue(protectionUsed: protectionUsed);
  }

  static bool? _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return null;
  }

  @override
  Function get fromJsonFunction => _$SexualActivityHealthValueFromJson;

  factory SexualActivityHealthValue.fromJson(Map<String, dynamic> json) =>
      FromJsonFactory().fromJson<SexualActivityHealthValue>(json);

  @override
  Map<String, dynamic> toJson() => _$SexualActivityHealthValueToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SexualActivityHealthValue && runtimeType == other.runtimeType && protectionUsed == other.protectionUsed;

  @override
  int get hashCode => protectionUsed.hashCode;

  @override
  String toString() => '$runtimeType - protectionUsed: ${protectionUsed.name}';
}
