part of '../../health.dart';

/// One page of data returned by [Health.getHealthDataPages].
final class HealthDataPage {
  /// Create a page of [points] of [type].
  HealthDataPage({
    required this.type,
    required this.points,
    required this.isLastPageForType,
    this.readPermissionDenied = false,
  });

  /// The data type of every point in this page.
  final HealthDataType type;

  /// The data points, without duplicates and oldest first: by start time on
  /// Android, by end time on iOS.
  final List<HealthDataPoint> points;

  /// Whether this is the last page for [type]. Every requested type ends with
  /// exactly one such page; it is empty if the type had no more data. All
  /// other pages hold at least one point.
  final bool isLastPageForType;

  /// Android only. The app has no read permission for [type], so the type was
  /// skipped: [points] is empty and this is the last page for [type]. Always
  /// false on iOS, where HealthKit does not tell whether read access was granted.
  final bool readPermissionDenied;
}
