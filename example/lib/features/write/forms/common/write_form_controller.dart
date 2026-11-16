/// The base of the write forms' controllers: one write at a time, its state as an `AsyncValue`, and
/// nothing thrown at the UI.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';

import 'write_outcome.dart';

/// Holds a write form's state and runs its plugin call.
///
/// A subclass keeps the form's values, says what it writes ([type], [description]) and makes the plugin
/// call in [performWrite]. [write] runs that call through [AsyncValue.guard], so whatever the plugin
/// throws becomes an [AsyncError] in [result] instead of an exception that crashes the app.
abstract class WriteFormController extends ChangeNotifier {
  /// Creates a controller that writes through [health], the app's plugin instance.
  WriteFormController(this.health);

  /// The plugin instance the write goes through.
  final Health health;

  AsyncValue<WriteOutcome> _result = const AsyncIdle();
  bool _disposed = false;

  /// The state of the last write: idle before the first, loading while one runs, then its outcome or
  /// what it threw.
  AsyncValue<WriteOutcome> get result => _result;

  /// Whether a write is running.
  bool get isWriting => _result.isLoading;

  /// The data type the form writes now, for the result report.
  HealthDataType get type;

  /// What the form writes now, such as "120/80 mmHg", for the result report and the recent writes.
  String get description;

  /// Makes the plugin call with the form's values and describes what it returned. May throw: [write]
  /// catches it.
  @protected
  Future<WriteOutcome> performWrite();

  /// Runs [performWrite] unless a write is running, and returns its state (an [AsyncData] or an
  /// [AsyncError]; the current state when a write was already running). Never throws.
  Future<AsyncValue<WriteOutcome>> write() async {
    if (isWriting) return _result;
    _update(() => _result = _result.toLoading());
    final result = await AsyncValue.guard(performWrite);
    _update(() => _result = result);
    return result;
  }

  /// Applies [change] and notifies the form, unless it closed while the plugin worked.
  @protected
  void update(VoidCallback change) => _update(change);

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
