/// A compact tonal banner shown on Android when Health Connect cannot be used yet.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';

/// Shows a one-line tonal banner with a link to Setup while Health Connect is missing or needs an
/// update on Android. Renders nothing on iOS, before the first status check, or once available.
class HealthConnectBanner extends StatelessWidget {
  /// Creates the banner for [capabilities].
  const HealthConnectBanner({super.key, required this.capabilities, this.padding = EdgeInsets.zero});

  /// The device's platform capabilities.
  final PlatformCapabilities capabilities;

  /// Outer padding when the banner is visible.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: capabilities,
      builder: (context, _) {
        if (!capabilities.isAndroid || !capabilities.isLoaded || capabilities.healthConnectAvailable) {
          return const SizedBox.shrink();
        }
        final label = capabilities.sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired
            ? 'Health Connect update required'
            : 'Health Connect unavailable';
        return Padding(
          padding: padding,
          child: ExpressiveCard(
            variant: ExpressiveCardVariant.tonal,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
            child: Row(
              spacing: 12,
              children: [
                const Icon(Icons.warning_amber_rounded),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmallEmphasized)),
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
}
