/// The data types this device supports, and what can be done with each: grouped for pickers, and
/// filtered for writes (`writeHealthData`), deletes (`delete`) and intervals
/// (`getHealthIntervalDataFromTypes`).
library;

import 'package:health/health.dart';

import 'health_type_info.dart';
import 'platform_capabilities.dart';
import 'type_category.dart';
import 'type_rules.dart';

/// The supported data types of the device that [capabilities] describes, sorted by category and
/// then by name. It follows the capabilities: once a refresh finds a Health Connect feature, its
/// type appears, so listen to [capabilities] to rebuild.
class TypeCatalog {
  /// Creates the catalog of the device [capabilities] describes.
  TypeCatalog(this.capabilities);

  /// The platform and features the catalog is built from.
  final PlatformCapabilities capabilities;

  _CatalogSnapshot? _snapshot;

  /// Every data type this device supports ([PlatformCapabilities.supports]).
  List<HealthDataType> get available => _current.available;

  /// [available] grouped by category, in [TypeCategory] order; categories without a type are
  /// left out.
  Map<TypeCategory, List<HealthDataType>> get byCategory => _current.byCategory;

  /// The types `writeHealthData` and `writeHealthDataUUID` write: not read-only and without a
  /// write method of their own ([TypeRules.dedicatedWriteMethods]).
  List<HealthDataType> get writableTypes => _current.writable;

  /// The types `getHealthIntervalDataFromTypes` aggregates on this platform.
  List<HealthDataType> get intervalTypes => _current.interval;

  /// The types whose own data `delete` can remove: those the app can write with some method.
  List<HealthDataType> get deletableTypes => _current.deletable;

  /// Whether no plugin method writes [type] on this platform ([TypeRules.isReadOnly]); true for
  /// every type where the plugin has no platform.
  bool isReadOnly(HealthDataType type) {
    final platform = capabilities.platform;
    return platform == null || TypeRules.isReadOnly(type, platform);
  }

  /// Whether [type] is supported here; see [PlatformCapabilities.supports].
  bool isAvailable(HealthDataType type) => capabilities.supports(type);

  /// Whether [type] is supported and `writeHealthData` writes it.
  bool isWritable(HealthDataType type) => _current.writable.contains(type);

  /// Whether [type] is supported and `getHealthIntervalDataFromTypes` aggregates it.
  bool hasIntervals(HealthDataType type) => _current.interval.contains(type);

  /// Whether [type] is supported and `delete` can remove the app's data of it.
  bool isDeletable(HealthDataType type) => _current.deletable.contains(type);

  /// The plugin method that writes [type] instead of `writeHealthData`, such as `writeMeal` for
  /// `NUTRITION`, or null.
  String? dedicatedWriteMethod(HealthDataType type) => TypeRules.dedicatedWriteMethods[type];

  /// The snapshot for the capabilities as they are now, rebuilt only when what
  /// [PlatformCapabilities.supports] depends on changed.
  _CatalogSnapshot get _current {
    final key = (
      capabilities.platform,
      capabilities.iosMajorVersion,
      capabilities.skinTemperatureAvailable,
      capabilities.mindfulnessAvailable,
      capabilities.activityIntensityAvailable,
    );
    final snapshot = _snapshot;
    if (snapshot != null && snapshot.key == key) return snapshot;
    return _snapshot = _CatalogSnapshot.build(key, capabilities);
  }
}

/// The capability values a catalog snapshot depends on.
typedef _CatalogKey = (HealthPlatformType?, int?, bool, bool, bool);

/// The catalog's lists for one state of the capabilities. All lists are unmodifiable.
class _CatalogSnapshot {
  _CatalogSnapshot(this.key, this.available, this.byCategory, this.writable, this.interval, this.deletable);

  factory _CatalogSnapshot.build(_CatalogKey key, PlatformCapabilities capabilities) {
    final platform = capabilities.platform;
    if (platform == null) return _CatalogSnapshot(key, const [], const {}, const [], const [], const []);

    // Sorted by category, then name, so pickers show related types together alphabetically.
    final available = TypeRules.platformTypes(platform).where(capabilities.supports).toList()
      ..sort((a, b) {
        final byCategory = a.category.index.compareTo(b.category.index);
        return byCategory != 0 ? byCategory : a.label.compareTo(b.label);
      });
    final groups = <TypeCategory, List<HealthDataType>>{};
    for (final type in available) {
      groups.putIfAbsent(type.category, () => []).add(type);
    }
    List<HealthDataType> where(bool Function(HealthDataType type, HealthPlatformType platform) test) =>
        List.unmodifiable(available.where((type) => test(type, platform)));

    return _CatalogSnapshot(
      key,
      List.unmodifiable(available),
      Map.unmodifiable({for (final entry in groups.entries) entry.key: List<HealthDataType>.unmodifiable(entry.value)}),
      where(TypeRules.writesWithWriteHealthData),
      where(TypeRules.hasIntervals),
      where(TypeRules.isDeletable),
    );
  }

  final _CatalogKey key;
  final List<HealthDataType> available;
  final Map<TypeCategory, List<HealthDataType>> byCategory;
  final List<HealthDataType> writable;
  final List<HealthDataType> interval;
  final List<HealthDataType> deletable;
}
