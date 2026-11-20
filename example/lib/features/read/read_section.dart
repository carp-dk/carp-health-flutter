/// The sections of the Read page, which its connected button group switches between.
library;

import 'package:flutter/material.dart';

/// A section of the Read page, with its label and icon in the button group.
enum ReadSection {
  /// The data points of chosen types in a time range: `getHealthDataFromTypes` and `getHealthDataPages`.
  query('Query', Icons.manage_search),

  /// One record by its UUID: `getHealthDataByUUID`.
  lookup('Lookup', Icons.fingerprint),

  /// What changed in Health Connect since a token was made: `getChangesToken` and `getChanges` (Android).
  changes('Changes', Icons.sync);

  const ReadSection(this.label, this.icon);

  /// The section's name in the button group.
  final String label;

  /// The icon before the name.
  final IconData icon;
}
