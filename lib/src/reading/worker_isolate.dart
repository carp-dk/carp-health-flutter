part of '../../health.dart';

/// Replies at least this large are parsed off the UI isolate in [HealthIsolateMode.auto].
const int _workerThresholdBytes = 64 * 1024;

/// Whether the plugin runs under `flutter test`, where [HealthIsolateMode.auto]
/// parses inline so that `testWidgets` never waits on an isolate.
final bool _underFlutterTest = () {
  try {
    final value = Platform.environment['FLUTTER_TEST'];
    return value != null && value != 'false';
  } catch (_) {
    return false;
  }
}();

bool _useWorker(HealthIsolateMode mode, int replyBytes) => switch (mode) {
  HealthIsolateMode.worker => true,
  HealthIsolateMode.inline => false,
  // Off the root isolate there is no UI to protect, so another hop gains nothing;
  // under flutter test, testWidgets (fake async) would wait forever on a worker.
  HealthIsolateMode.auto =>
    replyBytes >= _workerThresholdBytes && ServicesBinding.rootIsolateToken != null && !_underFlutterTest,
};

/// Decodes and parses [reply] in a short-lived worker isolate. Only the bytes are
/// copied into it, and the result comes back without a copy (Isolate.run returns
/// it with Isolate.exit). Kept top-level so the closure captures plain data only.
Future<T> _parseInWorker<T>(ByteData reply, T Function(Object?, _ParseRequest) parse, _ParseRequest request) {
  final bytes = TransferableTypedData.fromList([reply.buffer.asUint8List(reply.offsetInBytes, reply.lengthInBytes)]);
  return Isolate.run(
    () => parse(const StandardMethodCodec().decodeEnvelope(bytes.materialize().asByteData()), request),
    debugName: 'health: parse ${request.dataType?.name ?? 'changes'}',
  );
}
