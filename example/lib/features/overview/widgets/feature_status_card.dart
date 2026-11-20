/// The overview's list of Health Connect's optional features and how each stands on this device.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_dialog.dart';

import '../model/connect_feature.dart';

/// On Android, a segmented list of the [ConnectFeature]s with a status pill each.
class FeatureStatusCard extends StatelessWidget {
  /// Creates the card for the device [capabilities] describes.
  const FeatureStatusCard({super.key, required this.capabilities});

  /// The platform and its features.
  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    if (!capabilities.isAndroid) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final error = capabilities.lastError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedList(
          children: [
            for (final feature in ConnectFeature.values)
              _FeatureRow(feature: feature, state: feature.stateIn(capabilities)),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              spacing: 8,
              children: [
                Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                Expanded(
                  child: Text(
                    ErrorInfo.from(error).title,
                    style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.error),
                  ),
                ),
                TextButton(onPressed: () => showErrorDialog(context, error), child: const Text('Details')),
              ],
            ),
          ),
      ],
    );
  }
}

/// One feature: its icon, name and status; its tooltip names the plugin methods that check it.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature, required this.state});

  final ConnectFeature feature;
  final FeatureState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: feature.methods,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          spacing: 16,
          children: [
            ShapedIcon(
              icon: feature.icon,
              shape: ExpressiveShape.cookie6,
              size: 40,
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
            ),
            Expanded(child: Text(feature.label, style: theme.textTheme.titleMediumEmphasized)),
            StatusPill(label: state.label, tone: state.tone),
          ],
        ),
      ),
    );
  }
}
