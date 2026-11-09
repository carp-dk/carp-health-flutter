import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef MethodCallResponder = Future<Object?> Function(MethodCall call);

class MethodChannelHarness {
  MethodChannelHarness({this.channelName = 'flutter_health'}) : channel = MethodChannel(channelName);

  final String channelName;
  final MethodChannel channel;
  final List<MethodCall> calls = <MethodCall>[];
  final Map<String, Object?> cannedResponses = <String, Object?>{};
  final Map<String, List<Object?>> sequences = <String, List<Object?>>{};
  MethodCallResponder? _responder;

  Future<void> setUp({MethodCallResponder? responder}) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _responder = responder;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      MethodCall call,
    ) async {
      calls.add(call);
      if (_responder != null) {
        return _responder!(call);
      }
      final sequence = sequences[call.method];
      if (sequence != null) {
        if (sequence.isEmpty) {
          throw StateError('No more replies for ${call.method} (call ${callsFor(call.method).length}).');
        }
        final reply = sequence.removeAt(0);
        // A PlatformException becomes an error reply; a MissingPluginException
        // means no reply at all, as from a native side without the method.
        if (reply is Exception) throw reply;
        return reply;
      }
      if (cannedResponses.containsKey(call.method)) {
        return cannedResponses[call.method];
      }
      return null;
    });
  }

  Future<void> tearDown() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    calls.clear();
    cannedResponses.clear();
    sequences.clear();
    _responder = null;
  }

  void when(String method, Object? response) {
    cannedResponses[method] = response;
  }

  /// Replies to the calls of [method] with [replies], one per call and in
  /// order. An [Exception] in [replies] is thrown instead, so a
  /// [PlatformException] becomes an error reply.
  void whenSequence(String method, List<Object?> replies) {
    sequences[method] = List<Object?>.of(replies);
  }

  /// The calls of [method], oldest first.
  List<MethodCall> callsFor(String method) => calls.where((call) => call.method == method).toList();

  MethodCall? lastCallFor(String method) {
    for (final MethodCall call in calls.reversed) {
      if (call.method == method) {
        return call;
      }
    }
    return null;
  }

  MethodCall get lastCall {
    if (calls.isEmpty) {
      throw StateError('No method calls captured.');
    }
    return calls.last;
  }
}
