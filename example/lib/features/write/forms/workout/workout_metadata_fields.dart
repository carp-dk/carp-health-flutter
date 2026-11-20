/// The HealthKit metadata part of the workout form's state (iOS).
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

/// The fields of a [WorkoutMetadata]: HealthKit metadata of the workout, which only iOS stores.
///
/// A field left empty (or a switch left off) is not set, so HealthKit saves no such key. The sync
/// identifier and version write a workout again without adding a copy (the iOS counterpart of Health
/// Connect's client record id); the plugin throws an `ArgumentError` for one without the other.
mixin WorkoutMetadataFields on WriteFormController {
  bool? _indoor;
  bool _groupFitness = false;
  bool _coached = false;

  /// The brand name (`WorkoutMetadata.workoutBrandName`, HealthKit's `HKMetadataKeyWorkoutBrandName`).
  final TextEditingController brandName = TextEditingController(text: 'Health example');

  /// The sync identifier (`WorkoutMetadata.syncIdentifier`); empty for none.
  final TextEditingController syncIdentifier = TextEditingController();

  /// The sync version (`WorkoutMetadata.syncVersion`), a whole number; empty for none.
  final TextEditingController syncVersion = TextEditingController();

  /// Whether the workout was indoors (`WorkoutMetadata.indoorWorkout`); null leaves it unset. HealthKit
  /// reads an indoor run back as `RUNNING_TREADMILL`.
  bool? get indoor => _indoor;
  set indoor(bool? value) => update(() => _indoor = value);

  /// Whether it was a group fitness class (`WorkoutMetadata.groupFitness`); false leaves it unset.
  bool get groupFitness => _groupFitness;
  set groupFitness(bool value) => update(() => _groupFitness = value);

  /// Whether it was coached (`WorkoutMetadata.coachedWorkout`); false leaves it unset.
  bool get coached => _coached;
  set coached(bool value) => update(() => _coached = value);

  /// The `metadata` argument, or null when no field is set.
  WorkoutMetadata? get metadata {
    final brand = brandName.text.trim();
    final sync = syncIdentifier.text.trim();
    final metadata = WorkoutMetadata(
      workoutBrandName: brand.isEmpty ? null : brand,
      indoorWorkout: _indoor,
      groupFitness: _groupFitness ? true : null,
      coachedWorkout: _coached ? true : null,
      syncIdentifier: sync.isEmpty ? null : sync,
      syncVersion: NumberField.parse(syncVersion.text)?.toInt(),
    );
    return metadata.toJson().isEmpty ? null : metadata;
  }

  @override
  void dispose() {
    brandName.dispose();
    syncIdentifier.dispose();
    syncVersion.dispose();
    super.dispose();
  }
}
