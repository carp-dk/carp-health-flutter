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

  /// The data points, without duplicates and oldest first: on Android by the
  /// start time of their record (the samples of a series record and the stages
  /// of a sleep session come together), on iOS by end time.
  final List<HealthDataPoint> points;

  /// Whether this is the last page for [type]. Every requested type ends with
  /// exactly one such page; it is empty if the type had no more data. All
  /// other pages hold at least one point.
  final bool isLastPageForType;

  /// Android only. The app has no read permission for [type], so [points] are
  /// only the records this app wrote itself, which Health Connect lets it read
  /// with the type's write permission. Every page of such a read has this
  /// flag, not only the last. Without the write permission either, the type
  /// has one page, empty and last, with this flag.
  ///
  /// Always false on iOS, where HealthKit does not tell whether read access
  /// was granted: a denied read returns only the samples this app saved.
  final bool readPermissionDenied;
}
