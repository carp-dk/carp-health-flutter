/// A warning on the Read page while Health Connect cannot be used.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';

/// Warns that every read will fail while Health Connect is not available (`getHealthConnectSdkStatus` is
/// not `sdkAvailable`): the plugin then throws an `UnsupportedError` before it reads anything. Links to
/// Setup, which shows the status and offers `installHealthConnect`. Shows nothing on iOS, and nothing once
/// Health Connect is available; it follows [capabilities] as they refresh.
class HealthConnectNotice extends StatelessWidget {
  /// Creates the notice for the device [capabilities] describes.
  const HealthConnectNotice({super.key, required this.capabilities});

  /// The platform and its Health Connect status.
  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: capabilities,
      builder: (context, _) {
        // Until the first refresh the status is unknown: say nothing rather than warn too early.
        if (!capabilities.isAndroid || !capabilities.isLoaded || capabilities.healthConnectAvailable) {
          return const SizedBox.shrink();
        }
        final status = capabilities.sdkStatus;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ExpressiveCard(
            variant: ExpressiveCardVariant.tonal,
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 12,
              children: [
                const Icon(Icons.warning_amber_rounded),
                Expanded(
                  child: Text(
                    'Health Connect ${_describe(status)}, so reads fail until it is available.',
                  ),
                ),
                TextButton(
                  onPressed: () => AppNavigation.goTo(context, AppDestination.setup),
                  child: const Text('Setup'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// What [status] means, as the end of "Health Connect ...".
  static String _describe(HealthConnectSdkStatus? status) => switch (status) {
    HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired => 'needs an update',
    HealthConnectSdkStatus.sdkUnavailable => 'is not installed or not supported here',
    HealthConnectSdkStatus.sdkAvailable => 'is available',
    // getHealthConnectSdkStatus failed: PlatformCapabilities keeps the error as lastError.
    null => 'did not report its status',
  };
}
