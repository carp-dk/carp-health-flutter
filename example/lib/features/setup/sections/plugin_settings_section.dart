/// The Setup page's plugin settings section: how the plugin reads, `Health.pageSize` and
/// `Health.isolateMode` (edited through the app's `PluginSettings`, so the Read page follows), and the
/// device id the plugin gives read data points, `Health.deviceId`.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/design/design.dart';

import '../controllers/platform_controller.dart';
import '../widgets/responsive_columns.dart';
import 'settings/device_id_card.dart';
import 'settings/isolate_mode_card.dart';
import 'settings/page_size_card.dart';

/// The page size card, then the isolate mode and the device id side by side on wide windows. The header
/// restores the plugin's defaults. Rebuilds when [settings] change, also when another page changed them,
/// and when [platform] refreshes, which reads the device id again (a first read may have looked it up).
class PluginSettingsSection extends StatelessWidget {
  /// Creates the section that edits [settings]; [platform] tells the platform and the device id.
  const PluginSettingsSection({super.key, required this.settings, required this.platform});

  /// The plugin's read settings, the controller of this section: setting them sets the plugin's.
  final PluginSettings settings;

  /// The platform, whose words the cards use, and the device id.
  final PlatformController platform;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([settings, platform]),
    builder: (context, _) {
      final isIOS = platform.capabilities.isIOS;
      final isDefault =
          settings.pageSize == PluginSettings.defaultPageSize && settings.isolateMode == HealthIsolateMode.auto;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Plugin settings',
            trailing: TextButton.icon(
              onPressed: isDefault ? null : settings.reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Defaults'),
            ),
          ),
          PageSizeCard(settings: settings, isIOS: isIOS),
          const SizedBox(height: 12),
          ResponsiveColumns(
            children: [
              IsolateModeCard(settings: settings),
              DeviceIdCard(deviceId: platform.deviceId, isIOS: isIOS),
            ],
          ),
        ],
      );
    },
  );
}
