/// Display information for the plugin's `HealthDataType`s: a name, a category, an icon and the
/// unit the plugin reads and writes the type in (its `dataTypeToUnit` map).
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';

import 'type_category.dart';
import 'type_info/type_categories.dart';
import 'type_info/type_icons.dart';
import 'type_info/type_labels.dart';

/// Names, categories, icons and default units of [HealthDataType]s, for example
/// `HealthDataType.HEART_RATE.label` ("Heart rate").
extension HealthDataTypeInfo on HealthDataType {
  /// The type's display name, such as "Resting heart rate".
  String get label => typeLabel(this);

  /// The group the type belongs to, such as [TypeCategory.vitals].
  TypeCategory get category => typeCategory(this);

  /// A Material icon for the type.
  IconData get icon => typeIcon(this);

  /// The unit the plugin uses for the type: `dataTypeToUnit`, which `writeHealthData` takes when
  /// no unit is given and reads return unless `preferredUnits` asks for another.
  HealthDataUnit get defaultUnit => dataTypeToUnit[this] ?? HealthDataUnit.NO_UNIT;
}
