/// The overview's hero card: the health platform, its status and this device's id, next to the core
/// access panel.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';

import '../overview_controller.dart';
import 'core_access_panel.dart';

/// A vibrant card with the platform ("Health Connect" or "Apple Health"), its status, the device id
/// (`Health.deviceId`) and the [CoreAccessPanel]. Side by side on wide windows, stacked on phones.
class PlatformHeroCard extends StatelessWidget {
  /// Creates the hero card of [controller]'s platform.
  const PlatformHeroCard({super.key, required this.controller});

  /// The overview's state; the card reads its capabilities, device id and access.
  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    return ExpressiveCard(
      variant: ExpressiveCardVariant.vibrant,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final summary = _PlatformSummary(controller: controller);
          final access = CoreAccessPanel(controller: controller);
          if (constraints.maxWidth < 600) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [summary, access],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 24,
            children: [
              Expanded(child: summary),
              Expanded(child: access),
            ],
          );
        },
      ),
    );
  }
}

/// The platform, its status and a compact copyable device id.
class _PlatformSummary extends StatelessWidget {
  const _PlatformSummary({required this.controller});

  final OverviewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final capabilities = controller.capabilities;
    final status = _statusOf(capabilities);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Row(
          spacing: 16,
          children: [
            ShapedIcon(
              icon: capabilities.isIOS ? Icons.favorite : Icons.health_and_safety,
              // The icon's shape morphs when the status changes, for example after an update.
              shape: status.tone == StatusTone.success ? ExpressiveShape.cookie9 : ExpressiveShape.pentagon,
              size: 60,
              background: scheme.primary,
              foreground: scheme.onPrimary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(capabilities.platformName, style: theme.textTheme.headlineSmallEmphasized),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(label: status.label, tone: status.tone, icon: status.icon),
                      if (_versionLine(capabilities) case final line?)
                        Text(line, style: theme.textTheme.labelMedium),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        _DeviceId(deviceId: controller.deviceId),
      ],
    );
  }

  static String? _versionLine(PlatformCapabilities capabilities) {
    if (capabilities.isAndroid) return 'Android';
    if (!capabilities.isIOS) return null;
    final version = capabilities.iosMajorVersion;
    return version == null ? 'iOS' : 'iOS $version';
  }
}

/// How the platform's status reads in the pill.
typedef _StatusInfo = ({String label, StatusTone tone, IconData icon});

/// The status of the health platform that [capabilities] describes.
_StatusInfo _statusOf(PlatformCapabilities capabilities) {
  if (capabilities.isIOS) return (label: 'Ready', tone: StatusTone.success, icon: Icons.check_circle);
  if (!capabilities.isAndroid) return (label: 'Unsupported', tone: StatusTone.error, icon: Icons.block);
  if (!capabilities.isLoaded) return (label: 'Checking', tone: StatusTone.neutral, icon: Icons.hourglass_top);
  return switch (capabilities.sdkStatus) {
    HealthConnectSdkStatus.sdkAvailable => (label: 'Ready', tone: StatusTone.success, icon: Icons.check_circle),
    HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => (
      label: 'Update required',
      tone: StatusTone.warning,
      icon: Icons.system_update,
    ),
    HealthConnectSdkStatus.sdkUnavailable => (label: 'Unavailable', tone: StatusTone.error, icon: Icons.block),
    null => (label: 'Unknown', tone: StatusTone.neutral, icon: Icons.help_outline),
  };
}

/// The device id in a compact copyable row.
class _DeviceId extends StatelessWidget {
  const _DeviceId({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 8,
      children: [
        const Icon(Icons.fingerprint, size: 18),
        Expanded(
          child: Text(
            deviceId,
            style: theme.textTheme.bodySmall!.monospace,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Copy device id',
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: deviceId));
            if (!context.mounted) return;
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Device id copied')));
          },
        ),
      ],
    );
  }
}
