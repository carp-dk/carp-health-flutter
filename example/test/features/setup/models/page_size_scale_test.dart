import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/features/setup/models/page_size_scale.dart';

void main() {
  final stops = PageSizeScale.stops;

  test('steps 1-2-5 through the page sizes the plugin accepts, presets and default included', () {
    expect(stops.first, PluginSettings.minPageSize);
    expect(stops.last, PluginSettings.maxPageSize);
    expect(stops.take(7), [1, 2, 5, 10, 20, 50, 100]);
    for (var i = 1; i < stops.length; i++) {
      expect(stops[i], greaterThan(stops[i - 1]));
    }
    for (final preset in PluginSettings.pageSizePresets) {
      expect(stops, contains(preset));
    }
    expect(stops, contains(PluginSettings.defaultPageSize));
  });

  test('turns slider positions into page sizes and back', () {
    for (var i = 0; i < stops.length; i++) {
      expect(PageSizeScale.indexOf(PageSizeScale.valueAt(i)), i);
    }
    expect(PageSizeScale.valueAt(-3), stops.first);
    expect(PageSizeScale.valueAt(stops.length + 3), stops.last);
  });

  test('puts other page sizes at the nearest stop on the logarithmic scale', () {
    expect(PageSizeScale.valueAt(PageSizeScale.indexOf(1200)), 1000);
    expect(PageSizeScale.valueAt(PageSizeScale.indexOf(4000)), 5000);
    expect(PageSizeScale.indexOf(0), 0);
    expect(PageSizeScale.indexOf(1 << 30), stops.length - 1);
  });

  test('labels page sizes in a few characters, and names the default and the maximum', () {
    expect(PageSizeScale.compact(500), '500');
    expect(PageSizeScale.compact(5000), '5k');
    expect(PageSizeScale.compact(1500), '1,500');
    expect(PageSizeScale.presetLabel(1000), '1k');
    expect(PageSizeScale.presetLabel(PluginSettings.defaultPageSize), '20k · default');
    expect(PageSizeScale.presetLabel(PluginSettings.maxPageSize), '50k · max');
  });
}
