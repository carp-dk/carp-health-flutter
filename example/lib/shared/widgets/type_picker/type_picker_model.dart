/// The state of the type picker: the types offered, the search text, the grouping by category and the
/// selection. Kept apart from the widgets so that it can be tested on its own.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_category.dart';

/// The types the picker offers ([available]), those matching the [query] grouped by category
/// ([groups]), and the [selected] ones. Listeners hear about every change.
class TypePickerModel extends ChangeNotifier {
  /// Creates the model offering [available], with the [initial] types that are available selected.
  /// With [multiple] false, at most one type is selected.
  TypePickerModel({
    required List<HealthDataType> available,
    Set<HealthDataType> initial = const {},
    this.multiple = true,
  }) : available = List.unmodifiable(available),
       _selected = initial.where(available.contains).take(multiple ? initial.length : 1).toSet();

  /// The types offered.
  final List<HealthDataType> available;

  /// Whether several types can be selected.
  final bool multiple;

  final Set<HealthDataType> _selected;
  String _query = '';
  Map<TypeCategory, List<HealthDataType>>? _groups;

  /// The search text.
  String get query => _query;

  set query(String value) {
    if (value == _query) return;
    _query = value;
    _groups = null;
    notifyListeners();
  }

  /// The selected types, unmodifiable.
  Set<HealthDataType> get selected => Set.unmodifiable(_selected);

  /// The available types that match [query], grouped by category in [TypeCategory] order and sorted by
  /// name in each category. Categories without a match are left out.
  Map<TypeCategory, List<HealthDataType>> get groups => _groups ??= _group();

  /// Whether [type] is selected.
  bool isSelected(HealthDataType type) => _selected.contains(type);

  /// Selects [type], or deselects it when it is selected. Without [multiple] it replaces the selection.
  void toggle(HealthDataType type) {
    if (!_selected.remove(type)) {
      if (!multiple) _selected.clear();
      _selected.add(type);
    }
    notifyListeners();
  }

  /// Whether the shown types of [category] are all selected (true), none of them (false) or some (null),
  /// as a tristate checkbox shows it.
  bool? categoryState(TypeCategory category) {
    final shown = groups[category] ?? const [];
    final count = shown.where(_selected.contains).length;
    if (count == 0) return false;
    return count == shown.length ? true : null;
  }

  /// Selects the shown types of [category], or deselects them when they are all selected.
  void toggleCategory(TypeCategory category) {
    final shown = groups[category] ?? const <HealthDataType>[];
    if (categoryState(category) == true) {
      _selected.removeAll(shown);
    } else if (multiple) {
      _selected.addAll(shown);
    }
    notifyListeners();
  }

  /// Deselects every type.
  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  /// Whether [type] matches [query]: every word of the query appears in the type's name or its code
  /// name (such as "heart rate" for `HEART_RATE`), ignoring case. Category names are left out on
  /// purpose: "heart" would otherwise find every type of "Heart & vitals", blood oxygen included.
  static bool matches(HealthDataType type, String query) {
    final words = query.toLowerCase().replaceAll('_', ' ').split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    final haystack = '${type.label} ${type.name.replaceAll('_', ' ')}'.toLowerCase();
    return words.every(haystack.contains);
  }

  Map<TypeCategory, List<HealthDataType>> _group() {
    final groups = <TypeCategory, List<HealthDataType>>{};
    for (final type in available.where((type) => matches(type, _query))) {
      groups.putIfAbsent(type.category, () => []).add(type);
    }
    final categories = groups.keys.toList()..sort((a, b) => a.index.compareTo(b.index));
    return {
      for (final category in categories)
        category: List.unmodifiable(groups[category]!..sort((a, b) => a.label.compareTo(b.label))),
    };
  }
}
