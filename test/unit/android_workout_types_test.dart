import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The Dart guard and the native Health Connect map are maintained by hand in two languages.
// A type the guard accepts but the map lacks is not written (the native side returns false)
// and a Health Connect workout of that type is read back as OTHER.
void main() {
  test('the Android workout type guard matches the native Health Connect map', () {
    final guard = _names(
      File('lib/src/writing/workout_activity_types.dart').readAsStringSync(),
      start: 'bool _isOnAndroid(',
      end: '.contains(type)',
      name: RegExp(r'HealthWorkoutActivityType\.(\w+),'),
    );
    final nativeMap = _names(
      File('android/src/main/kotlin/cachet/plugins/health/HealthConstants.kt').readAsStringSync(),
      start: 'val workoutTypeMap',
      // The closing parenthesis of its mapOf.
      end: '\n    )',
      name: RegExp(r'"(\w+)" to ExerciseSessionRecord\.'),
    );

    expect(guard, isNotEmpty);
    expect(guard.difference(nativeMap), isEmpty, reason: 'accepted in Dart, missing natively');
    expect(nativeMap.difference(guard), isEmpty, reason: 'mapped natively, rejected in Dart');
  });
}

Set<String> _names(String source, {required String start, required String end, required RegExp name}) {
  final from = source.indexOf(start);
  expect(from, isNonNegative, reason: '"$start" not found');
  final to = source.indexOf(end, from);
  expect(to, greaterThan(from), reason: '"$end" not found after "$start"');
  return name.allMatches(source.substring(from, to)).map((m) => m.group(1)!).toSet();
}
