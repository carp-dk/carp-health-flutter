/// The sections of the Read page, which its connected button group switches between.
library;

import 'package:flutter/material.dart';

/// A section of the Read page, with its label, icon and the sentence the page shows under its title.
enum ReadSection {
  /// The data points of chosen types in a time range: `getHealthDataFromTypes` and `getHealthDataPages`.
  query(
    'Query',
    Icons.manage_search,
    'Read the data of chosen types in a time range, all at once or page by page.',
  ),

  /// One record by its UUID: `getHealthDataByUUID`.
  lookup('Lookup', Icons.fingerprint, 'Read one record by its UUID, such as a record this app just wrote.'),

  /// What changed in Health Connect since a token was made: `getChangesToken` and `getChanges` (Android).
  changes(
    'Changes',
    Icons.sync,
    'Follow what was added, changed or deleted in Health Connect since a changes token was made.',
  );

  const ReadSection(this.label, this.icon, this.description);

  /// The section's name in the button group.
  final String label;

  /// The icon before the name.
  final IconData icon;

  /// What the section does, in a sentence.
  final String description;
}
