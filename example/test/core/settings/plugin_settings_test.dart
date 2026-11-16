import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/settings/plugin_settings.dart';

void main() {
  late Health health;
  late PluginSettings settings;
  late int notifications;

  setUp(() {
    health = Health();
    settings = PluginSettings(health);
    notifications = 0;
    settings.addListener(() => notifications++);
  });

  test('starts from the plugin defaults', () {
    expect(settings.pageSize, Health.defaultPageSize);
    expect(settings.isolateMode, HealthIsolateMode.auto);
    expect(PluginSettings.pageSizePresets, contains(Health.defaultPageSize));
    expect(PluginSettings.pageSizePresets.last, Health.maxPageSize);
  });

  test('applies the page size to the plugin and notifies', () {
    settings.pageSize = 5000;
    expect(health.pageSize, 5000);
    expect(notifications, 1);
  });

  test('clamps the page size to what the plugin accepts', () {
    settings.pageSize = 0;
    expect(health.pageSize, 1);
    settings.pageSize = 1000000;
    expect(health.pageSize, Health.maxPageSize);
  });

  test('does not notify when nothing changes', () {
    settings
      ..pageSize = Health.defaultPageSize
      ..isolateMode = HealthIsolateMode.auto
      ..reset();
    expect(notifications, 0);
  });

  test('applies the isolate mode to the plugin', () {
    settings.isolateMode = HealthIsolateMode.inline;
    expect(health.isolateMode, HealthIsolateMode.inline);
    expect(notifications, 1);
  });

  test('reset restores the defaults', () {
    settings
      ..pageSize = 1000
      ..isolateMode = HealthIsolateMode.worker
      ..reset();
    expect(health.pageSize, Health.defaultPageSize);
    expect(health.isolateMode, HealthIsolateMode.auto);
    expect(notifications, 3);
  });
}
