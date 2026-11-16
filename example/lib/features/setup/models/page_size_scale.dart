/// The scale of the page size slider: `Health.pageSize` runs from 1 to 50,000, so the slider steps
/// through a 1-2-5 series (1, 2, 5, 10, ... 20,000, 50,000) that moves evenly through the orders of
/// magnitude instead of spending almost all of its track on large values.
library;

import 'dart:math' as math;

import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/settings/plugin_settings.dart';

/// The stops of the page size slider and the conversions between page sizes and slider positions.
abstract final class PageSizeScale {
  /// The page sizes the slider stops at, from [PluginSettings.minPageSize] to
  /// [PluginSettings.maxPageSize], ascending. Every preset of [PluginSettings.pageSizePresets] is one.
  static final List<int> stops = List.unmodifiable(_buildStops());

  /// The index of the stop nearest to [pageSize] on the logarithmic scale; values outside the range snap
  /// to its ends.
  static int indexOf(int pageSize) {
    final target = math.log(pageSize.clamp(stops.first, stops.last));
    var best = 0;
    for (var i = 1; i < stops.length; i++) {
      if ((math.log(stops[i]) - target).abs() < (math.log(stops[best]) - target).abs()) best = i;
    }
    return best;
  }

  /// The page size at slider position [index], clamped to the stops.
  static int valueAt(int index) => stops[index.clamp(0, stops.length - 1)];

  /// [pageSize] in a few characters for the slider's value indicator and the preset chips: "500",
  /// "5k", "20k".
  static String compact(int pageSize) =>
      pageSize >= 1000 && pageSize % 1000 == 0 ? '${pageSize ~/ 1000}k' : formatNumber(pageSize);

  /// What [pageSize] is, for the presets: the plugin's default and its maximum get a word.
  static String presetLabel(int pageSize) => switch (pageSize) {
    PluginSettings.defaultPageSize => '${compact(pageSize)} · default',
    PluginSettings.maxPageSize => '${compact(pageSize)} · max',
    _ => compact(pageSize),
  };

  /// 1, 2, 5 times each power of ten up to the largest page size, which ends the series.
  static List<int> _buildStops() {
    final values = <int>[];
    for (var power = 1; power <= PluginSettings.maxPageSize; power *= 10) {
      for (final step in const [1, 2, 5]) {
        final value = step * power;
        if (value >= PluginSettings.minPageSize && value < PluginSettings.maxPageSize) values.add(value);
      }
    }
    return values..add(PluginSettings.maxPageSize);
  }
}
