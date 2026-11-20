/// The sections of the workout form that only one platform stores: the Health Connect title and the
/// HealthKit metadata.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/form_kit/field_pair.dart';
import 'package:health_example/features/write/forms/form_kit/platform_section.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'workout_form_controller.dart';

/// The `title` of the workout, which only Health Connect stores.
class WorkoutTitleSection extends StatelessWidget {
  /// Creates the section for [controller].
  const WorkoutTitleSection({super.key, required this.controller});

  /// The workout form's state.
  final WorkoutFormController controller;

  @override
  Widget build(BuildContext context) {
    return PlatformSection(
      title: 'Title',
      parameter: 'title',
      onlyOn: HealthPlatformType.googleHealthConnect,
      caption: "Optional. Defaults to the activity's name, such as RUNNING.",
      note: 'HealthKit workouts have no title.',
      child: TextFormField(
        controller: controller.title,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Title', hintText: 'Morning run'),
      ),
    );
  }
}

/// The HealthKit metadata of the workout (`WorkoutMetadata`), which only iOS stores: brand name, indoor
/// or outdoor, group fitness, coached, and the sync identifier and version.
class WorkoutMetadataSection extends StatelessWidget {
  /// Creates the section for [controller].
  const WorkoutMetadataSection({super.key, required this.controller});

  /// The workout form's state.
  final WorkoutFormController controller;

  @override
  Widget build(BuildContext context) {
    return PlatformSection(
      title: 'HealthKit metadata',
      parameter: 'metadata: WorkoutMetadata',
      onlyOn: HealthPlatformType.appleHealth,
      caption: 'Empty fields are not saved. The same sync identifier with a higher version replaces the workout.',
      note: 'Health Connect has no workout metadata; a client record id replaces a workout there.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextFormField(
            controller: controller.brandName,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Brand name', prefixIcon: Icon(Icons.storefront)),
          ),
          ConnectedButtonGroup<bool?>(
            segments: const [
              ButtonGroupSegment(value: null, label: 'Not set'),
              ButtonGroupSegment(value: true, label: 'Indoor', icon: Icons.home_outlined),
              ButtonGroupSegment(value: false, label: 'Outdoor', icon: Icons.park_outlined),
            ],
            selected: controller.indoor,
            onSelected: (indoor) => controller.indoor = indoor,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Group fitness class'),
            value: controller.groupFitness,
            onChanged: (value) => controller.groupFitness = value,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Coached'),
            value: controller.coached,
            onChanged: (value) => controller.coached = value,
          ),
          FieldPair(
            first: TextFormField(
              controller: controller.syncIdentifier,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Sync identifier', hintText: 'run-42'),
            ),
            second: NumberField(
              label: 'Sync version',
              controller: controller.syncVersion,
              decimal: false,
              isRequired: false,
            ),
          ),
        ],
      ),
    );
  }
}
