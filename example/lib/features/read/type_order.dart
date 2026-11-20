/// The order in which the Read page lists data types: the order of the type pickers and chips.
library;

import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';

/// [types] sorted by category, then by name, as `TypeChips` and the type picker show them, so that a read
/// returns its types (and the results list them) in the order the user sees them chosen.
List<HealthDataType> inDisplayOrder(Iterable<HealthDataType> types) => types.toList()
  ..sort((a, b) {
    final byCategory = a.category.index.compareTo(b.category.index);
    return byCategory != 0 ? byCategory : a.label.compareTo(b.label);
  });

/// The types of [preferred] that are in [available], or, when none is, the first type of [available]; empty
/// only when nothing is available. Gives the sections a useful selection to start from.
Set<HealthDataType> initialTypes(Set<HealthDataType> preferred, List<HealthDataType> available) {
  final usable = preferred.where(available.contains).toSet();
  if (usable.isNotEmpty || available.isEmpty) return usable;
  return {available.first};
}
