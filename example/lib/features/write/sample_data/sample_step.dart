/// One step of the Write page's sample data: a single plugin write, what it writes, and when the device
/// cannot make it.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_rules.dart';

import '../forms/common/write_outcome.dart';

/// Makes a step's plugin call through [health] and describes what the call returned. It may throw:
/// the sample data controller catches it.
typedef SampleWrite = Future<WriteOutcome> Function(Health health);

/// One write of the sample data, such as "Height, 1.925 m with `writeHealthData`".
///
/// [requires] are the data types the device must support for the step to run
/// ([PlatformCapabilities.supports]); a step whose type is Android-only, needs a newer iOS or a Health
/// Connect feature is skipped on other devices instead of failing. [extraAccess] are the types whose
/// write access the step also needs where the platform has them: on Android a workout's distance and
/// energy are records of their own.
@immutable
class SampleStep {
  /// Creates a step that runs [write].
  const SampleStep({
    required this.title,
    required this.method,
    required this.type,
    required this.description,
    required this.write,
    this.requiredTypes,
    this.extraAccess = const [],
    this.clientRecordId,
  });

  /// What the step writes, such as "Heart rate (manual)".
  final String title;

  /// The plugin method the step calls, such as `writeHealthData`.
  final String method;

  /// The data type the step writes, as it is logged in the recent writes.
  final HealthDataType type;

  /// The value written, such as "72 bpm".
  final String description;

  /// The plugin call.
  final SampleWrite write;

  /// The data types the device must support for the step to run; [type] when null (see [requires]).
  final List<HealthDataType>? requiredTypes;

  /// Types whose write access the step needs too, where the platform has them.
  final List<HealthDataType> extraAccess;

  /// The Health Connect client record id the step writes with, if any; `deleteByClientRecordId`
  /// deletes such a record.
  final String? clientRecordId;

  /// The types the device must support for the step to run: [type] unless given.
  List<HealthDataType> get requires => requiredTypes ?? [type];

  /// Why the device [capabilities] describes skips this step, such as "Insulin delivery: Not available
  /// in Health Connect", or null when the step runs.
  String? skipReason(PlatformCapabilities capabilities) {
    for (final type in requires) {
      if (capabilities.unsupportedReason(type) case final reason?) return '${type.label}: $reason';
    }
    return null;
  }

  /// The one platform whose plugin has all of [requires], for a `PlatformBadge`; null when both have
  /// them.
  HealthPlatformType? get onlyOn {
    bool hasAll(HealthPlatformType platform) => requires.every(TypeRules.platformTypes(platform).contains);
    final android = hasAll(HealthPlatformType.googleHealthConnect);
    final ios = hasAll(HealthPlatformType.appleHealth);
    if (android == ios) return null;
    return android ? HealthPlatformType.googleHealthConnect : HealthPlatformType.appleHealth;
  }

  /// The types whose write access the step needs on the device [capabilities] describes.
  List<HealthDataType> accessTypes(PlatformCapabilities capabilities) => [
    ...requires,
    ...extraAccess.where(capabilities.supports),
  ];

  @override
  String toString() => 'SampleStep($method, ${type.name}, $description)';
}
