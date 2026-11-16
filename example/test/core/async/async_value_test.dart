import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/core/async/async_value.dart';

void main() {
  group('AsyncValue.guard', () {
    test('wraps the result in AsyncData', () async {
      final value = await AsyncValue.guard(() async => 42);
      expect(value, const AsyncData(42));
      expect(value.valueOrNull, 42);
      expect(value.hasValue, isTrue);
      expect(value.errorOrNull, isNull);
    });

    test('wraps exceptions in AsyncError with their stack trace', () async {
      final value = await AsyncValue.guard<int>(() async => throw const FormatException('bad'));
      expect(value, isA<AsyncError<int>>());
      expect(value.errorOrNull, isA<FormatException>());
      expect((value as AsyncError<int>).stackTrace, isNotNull);
      expect(value.hasError, isTrue);
      expect(value.valueOrNull, isNull);
    });

    test('also catches errors, such as the ArgumentError the plugin throws', () async {
      final value = await AsyncValue.guard<void>(() async => throw ArgumentError('no'));
      expect(value.errorOrNull, isA<ArgumentError>());
    });

    test('catches synchronous throws in the body', () async {
      final value = await AsyncValue.guard<int>(() => throw StateError('sync'));
      expect(value.errorOrNull, isA<StateError>());
    });
  });

  group('getters', () {
    test('idle has nothing', () {
      const value = AsyncIdle<int>();
      expect(value.isLoading, isFalse);
      expect(value.valueOrNull, isNull);
      expect(value.errorOrNull, isNull);
      expect(value.hasValue, isFalse);
    });

    test('loading keeps the previous value', () {
      const value = AsyncLoading<int>(previous: 7);
      expect(value.isLoading, isTrue);
      expect(value.valueOrNull, 7);
      expect(value.hasValue, isTrue);
      expect(const AsyncLoading<int>().hasValue, isFalse);
    });

    test('toLoading keeps the current value', () {
      expect(const AsyncData(3).toLoading(), const AsyncLoading(previous: 3));
      expect(const AsyncIdle<int>().toLoading(), const AsyncLoading<int>());
      expect(AsyncError<int>(Exception(), StackTrace.empty).toLoading().previous, isNull);
    });
  });

  test('a switch over the states is exhaustive', () {
    String describe(AsyncValue<int> value) => switch (value) {
      AsyncIdle() => 'idle',
      AsyncLoading() => 'loading',
      AsyncData(:final value) => 'data $value',
      AsyncError(:final error) => 'error $error',
    };
    expect(describe(const AsyncData(1)), 'data 1');
    expect(describe(const AsyncIdle()), 'idle');
  });
}
