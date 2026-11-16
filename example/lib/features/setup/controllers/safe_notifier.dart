/// Keeps the Setup controllers from notifying after they were disposed.
library;

import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that ignores [notifyListeners] once disposed.
///
/// A controller's plugin call can complete after its page closed (a permission dialog the user answers
/// late, for example); notifying a disposed notifier would throw, so the late result is dropped.
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  /// Whether [dispose] was called.
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
