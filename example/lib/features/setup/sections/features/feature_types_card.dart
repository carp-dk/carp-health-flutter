/// The data types that only newer Health Connect versions have, and whether this device has them.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import '../../widgets/setup_tile.dart';

/// A data type that depends on a Health Connect feature, and the Android versions that bring it (README,
/// "Health Connect features").
typedef _FeatureType = ({HealthDataType type, bool available, String needs});

/// A heading and one row per feature type: `SKIN_TEMPERATURE` (`isSkinTemperatureAvailable`),
/// `MINDFULNESS` (`isMindfulnessSessionAvailable`) and `ACTIVITY_INTENSITY` (`isActivityIntensityAvailable`),
/// each available or not on this device, with what it needs where it is not.
///
/// Without its feature the plugin throws `HealthErrorCode.notSupported` for the type, before calling
/// Health Connect, so the app leaves the type out of every list until a refresh finds it.
class FeatureTypesCard extends StatelessWidget {
  /// Creates the card from [capabilities].
  const FeatureTypesCard({super.key, required this.capabilities});

  /// The results of the feature checks.
  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<_FeatureType> rows = [
      (
        type: HealthDataType.SKIN_TEMPERATURE,
        available: capabilities.skinTemperatureAvailable,
        needs: 'Android 15+ / ext 13',
      ),
      (type: HealthDataType.MINDFULNESS, available: capabilities.mindfulnessAvailable, needs: 'Android 16+ / ext 15'),
      (
        type: HealthDataType.ACTIVITY_INTENSITY,
        available: capabilities.activityIntensityAvailable,
        needs: 'Android 16+ / ext 16',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Feature types', style: theme.textTheme.titleSmallEmphasized),
        ),
        SegmentedList(
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SetupTile(
                  leading: TypeIcon(type: row.type, size: 40),
                  title: row.type.label,
                  subtitle: row.available ? null : row.needs,
                  status: [
                    row.available
                        ? const StatusPill(label: 'Available', tone: StatusTone.success, icon: Icons.check)
                        : const StatusPill(label: 'Not available', tone: StatusTone.neutral, icon: Icons.block),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
