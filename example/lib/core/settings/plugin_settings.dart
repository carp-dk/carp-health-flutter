/// The plugin's read settings, `Health.pageSize` and `Health.isolateMode`, as a listenable the
/// Setup page edits and the Read page shows.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Reads and changes the read settings of [health]. Both apply to reads started afterwards: the
/// plugin reads them once when a read starts. Change them through this class, so listeners hear
/// about it.
class PluginSettings extends ChangeNotifier {
  /// Creates the settings of [health], starting from the values it has.
  PluginSettings(this.health);

  /// The plugin instance the settings apply to.
  final Health health;

  /// Page sizes the Setup page offers as presets: small pages for little memory per call, the
  /// default ([Health.defaultPageSize]) and the largest allowed ([Health.maxPageSize]).
  static const List<int> pageSizePresets = [1000, 5000, 20000, 50000];

  /// The smallest page size the plugin accepts.
  static const int minPageSize = 1;

  /// The largest page size the plugin accepts ([Health.maxPageSize]): bigger pages risk running
  /// Android out of memory while a page is built.
  static const int maxPageSize = Health.maxPageSize;

  /// The plugin's default page size ([Health.defaultPageSize]).
  static const int defaultPageSize = Health.defaultPageSize;

  /// The target number of data points per platform call (`Health.pageSize`). Bigger pages mean
  /// fewer Health Connect calls, which count against its API quota, and more memory per call.
  int get pageSize => health.pageSize;

  /// Sets `Health.pageSize`, clamped to [minPageSize]..[maxPageSize] (the plugin throws a
  /// `RangeError` outside that range).
  set pageSize(int value) {
    final clamped = value.clamp(minPageSize, maxPageSize);
    if (clamped == health.pageSize) return;
    health.pageSize = clamped;
    notifyListeners();
  }

  /// Where replies are decoded and parsed (`Health.isolateMode`): `auto` uses a worker isolate
  /// for replies of 64 KiB or more, `worker` always, `inline` never.
  HealthIsolateMode get isolateMode => health.isolateMode;

  /// Sets `Health.isolateMode`.
  set isolateMode(HealthIsolateMode value) {
    if (value == health.isolateMode) return;
    health.isolateMode = value;
    notifyListeners();
  }

  /// Restores the plugin's defaults: [defaultPageSize] and `HealthIsolateMode.auto`.
  void reset() {
    if (health.pageSize == defaultPageSize && health.isolateMode == HealthIsolateMode.auto) return;
    health
      ..pageSize = defaultPageSize
      ..isolateMode = HealthIsolateMode.auto;
    notifyListeners();
  }
}
