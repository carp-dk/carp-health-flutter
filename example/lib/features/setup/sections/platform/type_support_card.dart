/// How many of the platform's data types this device supports, and why the others are left out.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import '../../controllers/platform_controller.dart';
import '../../widgets/card_heading.dart';

/// The share of the platform's types (`isDataTypeAvailable`, from `dataTypeKeysAndroid` or
/// `dataTypeKeysIOS`) that work on this device as a wavy progress bar, and the types that do not, each
/// with its reason: a Health Connect feature the device lacks, or an iOS version that is too old. Reads
/// and writes of such a type throw `HealthErrorCode.notSupported`, so the app leaves them out of every
/// list.
class TypeSupportCard extends StatelessWidget {
  /// Creates the card for [controller]'s platform.
  const TypeSupportCard({super.key, required this.controller});

  /// The platform and its types.
  final PlatformController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = controller.platformTypeCount;
    // Until the first refresh, the Health Connect feature types count as unsupported: no count yet.
    final loaded = controller.capabilities.isLoaded;
    final unsupported = loaded ? controller.unsupportedTypes : const <UnsupportedType>[];
    final supported = total - unsupported.length;
    return ExpressiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeading(
            icon: ShapedIcon(
              icon: Icons.dataset,
              shape: ExpressiveShape.cookie6,
              size: 44,
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
            ),
            title: 'Data types',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 8,
            children: [
              Text(loaded ? '$supported' : '…', style: theme.textTheme.displaySmallEmphasized.tabular),
              Flexible(child: Text('of $total supported', style: theme.textTheme.bodyLarge)),
            ],
          ),
          const SizedBox(height: 12),
          WavyProgressIndicator(
            value: !loaded ? null : (total == 0 ? 0 : supported / total),
            semanticsLabel: 'Supported data types',
          ),
          if (unsupported.isNotEmpty)
            Theme(
              // The expansion tile sits on the card's colour: no extra dividers.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                title: Text('${unsupported.length} unsupported', style: theme.textTheme.titleSmallEmphasized),
                children: [
                  for (final (:type, :reason) in unsupported)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: TypeIcon(type: type, size: 36),
                      title: Text(type.label),
                      subtitle: Text(reason),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
