/// How Read > Changes shows what a change did to a record of the local copy.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import '../synced_records.dart';

/// The icon, shape and status tone of a [ChangeOutcome], shared by the sync counters and the list of
/// recent changes so that an outcome looks the same in both.
extension ChangeOutcomeVisuals on ChangeOutcome {
  /// The icon of the outcome.
  IconData get icon => switch (this) {
    ChangeOutcome.inserted => Icons.add_circle_outline,
    ChangeOutcome.updated => Icons.edit_outlined,
    ChangeOutcome.unchanged => Icons.drag_handle,
    ChangeOutcome.removed => Icons.delete_outline,
    ChangeOutcome.unknownDelete => Icons.delete_sweep_outlined,
  };

  /// The shape behind the icon in the counters.
  ExpressiveShape get shape => switch (this) {
    ChangeOutcome.inserted => ExpressiveShape.cookie9,
    ChangeOutcome.updated => ExpressiveShape.sunny,
    ChangeOutcome.unchanged => ExpressiveShape.pill,
    ChangeOutcome.removed => ExpressiveShape.cookie4,
    ChangeOutcome.unknownDelete => ExpressiveShape.puffy,
  };

  /// The tone of the outcome's pill and counter.
  StatusTone get tone => switch (this) {
    ChangeOutcome.inserted => StatusTone.success,
    ChangeOutcome.updated => StatusTone.info,
    ChangeOutcome.unchanged => StatusTone.neutral,
    ChangeOutcome.removed => StatusTone.error,
    ChangeOutcome.unknownDelete => StatusTone.warning,
  };
}
