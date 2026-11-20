/// The Setup page's Health Connect features section: the two extra read permissions
/// (`isHealthDataHistoryAvailable` / `isHealthDataHistoryAuthorized` / `requestHealthDataHistoryAuthorization`
/// and their background counterparts) and the data types that only newer Health Connect versions have
/// (`isSkinTemperatureAvailable`, `isMindfulnessSessionAvailable`, `isActivityIntensityAvailable`).
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';

import '../controllers/connect_features_controller.dart';
import '../widgets/platform_note.dart';
import '../widgets/responsive_columns.dart';
import 'features/extra_read_card.dart';
import 'features/feature_types_card.dart';

/// The features of the device's Health Connect, each available or not: on Android a card per extra read
/// permission (side by side on wide windows) and the feature data types; on iOS a note on what the plugin
/// answers there. Rebuilds when the controller or the capabilities change, also when another page
/// refreshed them.
class FeaturesSection extends StatelessWidget {
  /// Creates the section for [controller].
  const FeaturesSection({super.key, required this.controller});

  /// The requests of the extra read permissions, and the capabilities that answer the checks.
  final ConnectFeaturesController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.capabilities]),
    builder: (context, _) {
      final capabilities = controller.capabilities;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Health Connect features', trailing: PlatformBadge.android()),
          if (!capabilities.isAndroid)
            const PlatformNote.android(title: 'Android only', icon: Icons.android, showBadge: false, message: '')
          else
            _AndroidFeatures(controller: controller, capabilities: capabilities),
        ],
      );
    },
  );
}

/// The Android content: a loading indicator until the first refresh, a short note without Health
/// Connect, and otherwise the feature cards.
class _AndroidFeatures extends StatelessWidget {
  const _AndroidFeatures({required this.controller, required this.capabilities});

  final ConnectFeaturesController controller;
  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!capabilities.isLoaded) {
      child = const _Note(icon: null, text: 'Checking features…');
    } else if (!capabilities.healthConnectAvailable) {
      // The refresh skips the feature checks without Health Connect: every flag would read false.
      child = const _Note(icon: Icons.extension_off, text: 'Not checked: Health Connect unavailable');
    } else {
      child = Column(
        key: const ValueKey('features'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          ResponsiveColumns(
            spacing: 12,
            children: [
              for (final permission in ExtraReadPermission.values)
                ExtraReadCard(permission: permission, controller: controller),
            ],
          ),
          FeatureTypesCard(capabilities: capabilities),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: ExpressiveMotion.effectsSlow.duration,
      switchInCurve: ExpressiveMotion.effectsSlow,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      child: child,
    );
  }
}

/// A quiet outlined card with an icon (or a loading indicator when [icon] is null) and a short line.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExpressiveCard(
      key: ValueKey(text),
      variant: ExpressiveCardVariant.outlined,
      child: Row(
        spacing: 16,
        children: [
          if (icon case final icon?)
            ShapedIcon(
              icon: icon,
              shape: ExpressiveShape.pentagon,
              size: 44,
              background: scheme.surfaceContainerHighest,
              foreground: scheme.onSurfaceVariant,
            )
          else
            ExpressiveLoadingIndicator(size: 44, semanticsLabel: text),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
