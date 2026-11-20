part of '../../health.dart';

/// Tells a read made by [_cancellableRead] that its listener has cancelled it.
class _ReadCancellation {
  bool _isCancelled = false;

  /// Ends the read with a [_ReadCancelled] once its listener has cancelled it.
  /// The read calls this before each platform call, so that it starts none
  /// after the cancel.
  void throwIfCancelled() {
    if (_isCancelled) throw const _ReadCancelled();
  }
}

/// Ends a cancelled read. Like any error after the cancel, it is dropped.
class _ReadCancelled implements Exception {
  const _ReadCancelled();
}

/// The stream of [read], which stops cleanly when its listener cancels it.
///
/// An async* read notices a cancel only at its next yield. Before that it
/// would go on with its next platform call, and an error of the call in flight
/// would complete the future returned by [StreamSubscription.cancel], an
/// uncaught error if the listener does not await it, as StreamBuilder does.
/// Here, [read] gets a [_ReadCancellation] that is set on cancel, and an error
/// after the cancel is dropped.
Stream<T> _cancellableRead<T>(Stream<T> Function(_ReadCancellation cancellation) read) {
  final cancellation = _ReadCancellation();
  late final StreamController<T> controller;
  late final StreamSubscription<T> subscription;
  controller = StreamController<T>(
    // Synchronous, so that a pause of the listener (as by `await for`) reaches
    // the read before it can go on: the read stays back-pressured.
    sync: true,
    onListen: () {
      subscription = read(cancellation).listen(controller.add, onError: controller.addError, onDone: controller.close);
    },
    onPause: () => subscription.pause(),
    onResume: () => subscription.resume(),
    onCancel: () {
      cancellation._isCancelled = true;
      // Completes once the call in flight has returned and the read has ended.
      return subscription.cancel().catchError((Object _) {});
    },
  );
  return controller.stream;
}
