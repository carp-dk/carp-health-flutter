import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef MethodCallResponder = Future<Object?> Function(MethodCall call);

class MethodChannelHarness {
  MethodChannelHarness({this.channelName = 'flutter_health'}) : channel = MethodChannel(channelName);

  final String channelName;
  final MethodChannel channel;
  final List<MethodCall> calls = <MethodCall>[];
  final Map<String, Object?> cannedResponses = <String, Object?>{};
  MethodCallResponder? _responder;

  Future<void> setUp({MethodCallResponder? responder}) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _responder = responder;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async {
        calls.add(call);
        if (_responder != null) {
          return _responder!(call);
        }
        if (cannedResponses.containsKey(call.method)) {
          return cannedResponses[call.method];
        }
        return null;
      },
    );
  }

  Future<void> tearDown() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    calls.clear();
    cannedResponses.clear();
    _responder = null;
  }

  void when(String method, Object? response) {
    cannedResponses[method] = response;
  }

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
