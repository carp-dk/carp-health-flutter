/// What a permission call covers: the data types of the scope the user chose (all types or one category)
/// and the access asked for each, in the shape `requestAuthorization`, `hasPermissions` and
/// `getRequestStatusForAuthorization` take them (two lists of the same length).
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/permission_plan.dart';
import 'package:health_example/core/health/type_category.dart';

/// The data types the Setup page asks about: every supported type, or the types of one category.
@immutable
class PermissionScope {
  /// Every data type this device supports.
  const PermissionScope.all() : category = null;

  /// The supported data types of [category].
  const PermissionScope.category(TypeCategory this.category);

  /// The category of the scope; null for all types.
  final TypeCategory? category;

  /// Whether the scope covers every supported type.
  bool get isAll => category == null;

  /// The categories of [byCategory] (the type catalog's groups) this scope covers, in catalog order. A
  /// category the device does not have (any more) covers nothing.
  List<TypeCategory> categoriesIn(Map<TypeCategory, List<HealthDataType>> byCategory) => switch (category) {
    null => byCategory.keys.toList(),
    final category => [if (byCategory.containsKey(category)) category],
  };

  /// The data types of [byCategory] this scope covers.
  List<HealthDataType> typesIn(Map<TypeCategory, List<HealthDataType>> byCategory) => [
    for (final category in categoriesIn(byCategory)) ...byCategory[category]!,
  ];

  /// A short name: "All types" or the category's label.
  String get label => category?.label ?? 'All types';

  @override
  bool operator ==(Object other) => other is PermissionScope && other.category == category;

  @override
  int get hashCode => category.hashCode;

  @override
  String toString() => 'PermissionScope($label)';
}

/// The [types] of one permission call and the access asked for each ([accesses], same order and
/// length), ready for the plugin's `types` and `permissions` arguments.
///
/// The accesses come from `PermissionPlan`: [preferred] for every type, lowered to `READ` where write
/// access cannot be requested. HealthKit only lets apps read some types and crashes an app that asks to
/// write them, so the plugin throws an `ArgumentError` for that request instead.
@immutable
class PermissionRequest {
  /// Plans [preferred] access to [types] (`HealthDataAccess.READ` or `READ_WRITE`).
  factory PermissionRequest(List<HealthDataType> types, {required HealthDataAccess preferred}) => PermissionRequest._(
    List.unmodifiable(types),
    List.unmodifiable(PermissionPlan.accessesFor(types, preferred: preferred)),
    preferred,
  );

  const PermissionRequest._(this.types, this.accesses, this.preferred);

  /// The data types, for the plugin's `types` argument.
  final List<HealthDataType> types;

  /// The access for each of [types], for the plugin's `permissions` argument.
  final List<HealthDataAccess> accesses;

  /// The access the user chose; [accesses] holds less where the type cannot be written.
  final HealthDataAccess preferred;

  /// Whether the request covers no type, so there is nothing to ask for.
  bool get isEmpty => types.isEmpty;

  /// The number of types.
  int get length => types.length;

  /// The types asked for with less than [preferred] access: only read, as nothing can write them here.
  List<HealthDataType> get readOnlyTypes => [
    for (var i = 0; i < types.length; i++)
      if (accesses[i] != preferred) types[i],
  ];

  /// The access of [type] in this request, or null if it is not part of it.
  HealthDataAccess? accessOf(HealthDataType type) {
    final index = types.indexOf(type);
    return index < 0 ? null : accesses[index];
  }

  /// The part of this request whose types pass [test], each with the access it has here.
  PermissionRequest where(bool Function(HealthDataType type) test) {
    final kept = [
      for (var i = 0; i < types.length; i++)
        if (test(types[i])) i,
    ];
    return PermissionRequest._(
      List.unmodifiable([for (final i in kept) types[i]]),
      List.unmodifiable([for (final i in kept) accesses[i]]),
      preferred,
    );
  }

  /// The request for [type] alone, with the access it has here (none if it is not part of it).
  PermissionRequest only(HealthDataType type) => where((candidate) => candidate == type);

  /// The same types with `HealthDataAccess.WRITE` access, leaving out those that cannot be written.
  ///
  /// HealthKit keeps read access secret, so on iOS `hasPermissions` answers null for `READ` and
  /// `READ_WRITE`; whether the user allowed writing is the one thing it can tell.
  PermissionRequest writeOnly() {
    final writable = [
      for (final type in types)
        if (PermissionPlan.canRequestWrite(type)) type,
    ];
    return PermissionRequest._(
      List.unmodifiable(writable),
      List.unmodifiable(List.filled(writable.length, HealthDataAccess.WRITE)),
      HealthDataAccess.WRITE,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PermissionRequest &&
      other.preferred == preferred &&
      listEquals(other.types, types) &&
      listEquals(other.accesses, accesses);

  @override
  int get hashCode => Object.hash(preferred, Object.hashAll(types), Object.hashAll(accesses));

  @override
  String toString() => 'PermissionRequest(${types.length} types, ${preferred.name})';
}

/// Display names of the accesses the Setup page offers.
extension HealthDataAccessLabel on HealthDataAccess {
  /// "Read", "Write" or "Read & write".
  String get label => switch (this) {
    HealthDataAccess.READ => 'Read',
    HealthDataAccess.WRITE => 'Write',
    HealthDataAccess.READ_WRITE => 'Read & write',
  };
}
