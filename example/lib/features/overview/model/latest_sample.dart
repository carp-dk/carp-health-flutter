/// The newest data point of a type, as `getHealthDataFromTypes` with `limit: 1` reads it, or why
/// there is none.
library;

import 'package:health/health.dart';

/// The newest [point] of a type, or null when the read found none.
///
/// A missing read permission is not an error for `getHealthDataFromTypes`: the read then returns only
/// the data this app wrote itself, often nothing. On Android `hasPermissions` tells whether that is
/// why the read was empty ([readDenied]); HealthKit keeps read access private, so on iOS an empty
/// read cannot be told apart from no data.
class LatestSample {
  /// Creates the result of a read that found [point] (or nothing), with [readDenied] when the read
  /// came back empty because the read permission is missing.
  const LatestSample(this.point, {this.readDenied = false});

  /// The newest data point, or null.
  final HealthDataPoint? point;

  /// Whether the read was empty and the read permission is known to be missing (Android).
  final bool readDenied;

  /// The numeric value of [point], or null without a point or for a value that is not a number.
  num? get value => switch (point?.value) {
    NumericHealthValue(:final numericValue) => numericValue,
    _ => null,
  };

  @override
  String toString() => 'LatestSample(${point?.type.name}, value: $value, readDenied: $readDenied)';
}
