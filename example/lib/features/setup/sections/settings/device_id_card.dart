/// The id of this device that the plugin gives the data points it reads, `Health.deviceId`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';

import '../../widgets/card_heading.dart';

/// [deviceId] in monospace, selectable and with a copy button; where it comes from on this platform
/// ([isIOS]) sits behind the info button. Read data points carry it as `HealthDataPoint.sourceDeviceId`.
class DeviceIdCard extends StatelessWidget {
  /// Creates the card for [deviceId].
  const DeviceIdCard({super.key, required this.deviceId, required this.isIOS});

  /// The device id, "unknown" until `Health.configure` has looked it up.
  final String deviceId;

  /// Whether the id is iOS's `identifierForVendor` rather than Android's `Build.ID`.
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final known = deviceId != 'unknown';
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          CardHeading(
            icon: ShapedIcon(
              icon: Icons.fingerprint,
              shape: ExpressiveShape.cookie7,
              size: 44,
              background: scheme.primaryContainer,
              foreground: scheme.onPrimaryContainer,
            ),
            title: 'Device id',
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(child: SelectableText(deviceId, style: theme.textTheme.titleMedium!.monospace)),
              if (known)
                IconButton.filledTonal(
                  tooltip: 'Copy the device id',
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.content_copy),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Copies the id and confirms it in a snack bar.
  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: deviceId));
    messenger?.showSnackBar(const SnackBar(content: Text('Device id copied')));
  }
}
