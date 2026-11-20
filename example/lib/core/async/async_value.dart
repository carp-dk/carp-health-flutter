/// The state of an asynchronous plugin call, as the feature controllers expose it to the UI.
///
/// Every plugin call in the example is wrapped in [AsyncValue.guard], so a failure (a
/// `HealthPlatformException`, an `ArgumentError`, ...) becomes an [AsyncError] the UI shows instead
/// of an exception that escapes to the zone and crashes the app.
library;

/// The state of an asynchronous value of type [T]: [AsyncIdle] before anything was asked for,
/// [AsyncLoading] while it loads, then [AsyncData] or [AsyncError].
///
/// The class is sealed, so a `switch` over the four states is checked for exhaustiveness:
///
/// ```dart
/// final text = switch (steps) {
///   AsyncIdle() => 'Not read yet',
///   AsyncLoading() => 'Reading...',
///   AsyncData(:final value) => '$value steps',
///   AsyncError(:final error) => 'Failed: $error',
/// };
/// ```
sealed class AsyncValue<T> {
  /// Base constructor of the four states.
  const AsyncValue();

  /// Runs [body] and returns its result as [AsyncData], or whatever it throws (errors such as
  /// `ArgumentError` included) as [AsyncError] with its stack trace. Never throws.
  static Future<AsyncValue<T>> guard<T>(Future<T> Function() body) async {
    try {
      return AsyncData<T>(await body());
    } catch (error, stackTrace) {
      return AsyncError<T>(error, stackTrace);
    }
  }

  /// The value: the data of [AsyncData], the previous value of [AsyncLoading], else null.
  T? get valueOrNull => switch (this) {
    AsyncData<T>(:final value) => value,
    AsyncLoading<T>(:final previous) => previous,
    _ => null,
  };

  /// Whether this is [AsyncLoading].
  bool get isLoading => this is AsyncLoading<T>;

  /// The error of [AsyncError], else null.
  Object? get errorOrNull => switch (this) {
    AsyncError<T>(:final error) => error,
    _ => null,
  };

  /// Whether this is [AsyncData], or [AsyncLoading] that keeps a previous value.
  bool get hasValue => switch (this) {
    AsyncData<T>() => true,
    AsyncLoading<T>(:final previous) => previous != null,
    _ => false,
  };

  /// Whether this is [AsyncError].
  bool get hasError => this is AsyncError<T>;

  /// This state's loading successor: [AsyncLoading] that keeps [valueOrNull], so a refresh can
  /// show the old data under a progress indicator.
  AsyncLoading<T> toLoading() => AsyncLoading<T>(previous: valueOrNull);
}

/// Nothing has been asked for yet, for example before the user starts a read.
final class AsyncIdle<T> extends AsyncValue<T> {
  /// Creates the idle state.
  const AsyncIdle();

  @override
  bool operator ==(Object other) => other is AsyncIdle<T>;

  @override
  int get hashCode => (AsyncIdle<T>).hashCode;

  @override
  String toString() => 'AsyncIdle<$T>()';
}

/// The value is loading. [previous] keeps the last value, if any, while a refresh runs.
final class AsyncLoading<T> extends AsyncValue<T> {
  /// Creates the loading state, optionally keeping the [previous] value.
  const AsyncLoading({this.previous});

  /// The value before this load started, or null.
  final T? previous;

  @override
  bool operator ==(Object other) => other is AsyncLoading<T> && other.previous == previous;

  @override
  int get hashCode => Object.hash(AsyncLoading<T>, previous);

  @override
  String toString() => 'AsyncLoading<$T>(previous: $previous)';
}

/// The value loaded.
final class AsyncData<T> extends AsyncValue<T> {
  /// Creates the data state holding [value].
  const AsyncData(this.value);

  /// The loaded value.
  final T value;

  @override
  bool operator ==(Object other) => other is AsyncData<T> && other.value == value;

  @override
  int get hashCode => Object.hash(AsyncData<T>, value);

  @override
  String toString() => 'AsyncData<$T>($value)';
}

/// Loading failed with [error], thrown at [stackTrace]. `ErrorInfo.from(error)` describes it.
final class AsyncError<T> extends AsyncValue<T> {
  /// Creates the error state for [error], thrown at [stackTrace].
  const AsyncError(this.error, this.stackTrace);

  /// What was thrown: an `Exception` or an `Error`.
  final Object error;

  /// Where [error] was thrown.
  final StackTrace stackTrace;

  @override
  bool operator ==(Object other) => other is AsyncError<T> && other.error == error && other.stackTrace == stackTrace;

  @override
  int get hashCode => Object.hash(AsyncError<T>, error, stackTrace);

  @override
  String toString() => 'AsyncError<$T>($error)';
}
