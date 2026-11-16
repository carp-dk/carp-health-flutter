/// The base of the write forms' controllers: each form keeps its input in a [WriteFormController], which
/// calls the plugin and exposes the state of the last write as an `AsyncValue`.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';

import 'write_outcome.dart';

/// A write form's state and its plugin call.
///
/// Subclasses hold the form's input, describe it ([describe]) and write it ([performWrite]) by calling the
/// plugin through [health]. [write] runs that call inside `AsyncValue.guard`, so whatever the plugin
/// throws (an `ArgumentError` for invalid input, a `HealthPlatformException`, ...) becomes an
/// [AsyncError] that the form shows in an `ErrorCard`, and never reaches the zone.
abstract class WriteFormController extends ChangeNotifier {
  /// Creates the controller of a form that writes through the plugin instance of [services].
  WriteFormController(this.services);

  /// The app's services: the plugin instance, the platform's capabilities and the recent writes.
  final AppServices services;

  AsyncValue<WriteOutcome> _result = const AsyncIdle();
  bool _disposed = false;

  /// The plugin.
  Health get health => services.health;

  /// The platform and its optional Health Connect features.
  PlatformCapabilities get capabilities => services.capabilities;

  /// Whether the app runs on iOS (Apple Health), where some arguments are ignored or rejected.
  bool get isIOS => capabilities.isIOS;

  /// The data type the form writes, as the write is reported and logged in the recent writes.
  HealthDataType get type;

  /// What the form would write now, in a few words, such as "Breathing · 10 min".
  String describe();

  /// Why the form cannot write on this device (the other platform, a missing Health Connect feature), or
  /// null when it can.
  String? get unavailableReason => null;

  /// The state of the last write: idle before the first, loading while one runs (keeping the previous
  /// outcome), then the outcome or the error.
  AsyncValue<WriteOutcome> get result => _result;

  /// Whether a write is running.
  bool get isWriting => _result.isLoading;

  /// Calls the plugin with the form's input and returns what it returned. May throw: [write] catches it.
  @protected
  Future<WriteOutcome> performWrite();

  /// Writes the form's input with [performWrite], unless a write is already running, and returns the new
  /// [result]. Never throws.
  Future<AsyncValue<WriteOutcome>> write() async {
    if (_result.isLoading) return _result;
    _update(_result.toLoading());
    final result = await AsyncValue.guard(() async {
      final reason = unavailableReason;
      // The form shows why instead of its write button; this guards calls made anyway.
      if (reason != null) throw UnsupportedError(reason);
      return performWrite();
    });
    _update(result);
    return result;
  }

  /// Hides the last outcome, for example after the user read it.
  void dismissResult() => _update(const AsyncIdle());

  /// Notifies the form that its input changed; does nothing after [dispose].
  @protected
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void _update(AsyncValue<WriteOutcome> result) {
    _result = result;
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
