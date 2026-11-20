/// The hero card at the top of the Setup page: the health platform and whether it can be used.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import '../../controllers/platform_controller.dart';
import '../../models/sdk_status_info.dart';
import '../../widgets/busy_button.dart';

/// The platform's name in a shape that morphs with its state, the state as a pill (what it means and
/// what `getHealthConnectSdkStatus` and `isHealthConnectAvailable` answered sit behind the info button),
/// and the actions: refresh (`getHealthConnectSdkStatus` and the feature checks) and, only when the status
/// asks for it, `installHealthConnect`.
///
/// The card is vibrant while the platform can be used; when Health Connect needs attention it turns to
/// the quieter surface colour, so the status and the install button stand out.
class PlatformHeroCard extends StatelessWidget {
  /// Creates the card for [controller]'s platform.
  const PlatformHeroCard({super.key, required this.controller});

  /// The platform's state and actions.
  final PlatformController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final capabilities = controller.capabilities;
    final refreshing = controller.status.isLoading;
    final info = _info(refreshing);
    final attention = info.tone == StatusTone.warning || info.tone == StatusTone.error;
    return ExpressiveCard(
      variant: attention ? ExpressiveCardVariant.filled : ExpressiveCardVariant.vibrant,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Row(
            spacing: 20,
            children: [
              ShapedIcon(
                icon: capabilities.isIOS ? Icons.apple : Icons.android,
                shape: info.shape,
                size: 72,
                background: scheme.primary,
                foreground: scheme.onPrimary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Text(capabilities.platformName, style: theme.textTheme.headlineSmallEmphasized),
                    StatusPill(label: info.label, tone: info.tone, icon: info.icon),
                  ],
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BusyButton(
                kind: BusyButtonKind.tonal,
                label: 'Refresh',
                busyLabel: 'Checking…',
                icon: Icons.refresh,
                busy: refreshing,
                onPressed: controller.refresh,
              ),
              // Only where Health Connect must be installed or updated: from Android 14 on it is part of
              // the system and installHealthConnect does nothing.
              if (info.offersInstall)
                BusyButton(
                  label: 'Install Health Connect',
                  busyLabel: 'Opening the store…',
                  icon: Icons.download,
                  busy: controller.install.isLoading,
                  onPressed: controller.installHealthConnect,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// What to show: HealthKit on iOS, otherwise Health Connect's status (checking until first read).
  SdkStatusInfo _info(bool refreshing) {
    final capabilities = controller.capabilities;
    if (capabilities.isIOS) return SdkStatusInfo.healthKit(capabilities.iosMajorVersion);
    final status = capabilities.sdkStatus;
    if (status == null && (refreshing || !capabilities.isLoaded)) return SdkStatusInfo.checking;
    return SdkStatusInfo.of(status);
  }
}
