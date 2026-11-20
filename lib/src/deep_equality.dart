part of '../health.dart';

/// Whether [a] and [b] are equal, comparing maps and lists by their contents,
/// to any depth, and anything else with `==`: the metadata of a
/// [HealthDataPoint] can nest maps and lists.
bool _deepEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length && a.keys.every((key) => b.containsKey(key) && _deepEquals(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// A hash code of [value] that agrees with [_deepEquals].
int _deepHash(Object? value) => switch (value) {
  Map() => Object.hashAllUnordered(value.entries.map((entry) => Object.hash(entry.key, _deepHash(entry.value)))),
  List() => Object.hashAll(value.map(_deepHash)),
  _ => value.hashCode,
};
