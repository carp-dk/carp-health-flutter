import 'package:device_info_plus/device_info_plus.dart';
import 'package:health/health.dart';

import 'method_channel_harness.dart';
import 'stub_device_info.dart';

class HealthTestContext {
  factory HealthTestContext({DeviceInfoPlugin? deviceInfo, HealthIsolateMode? isolateMode}) {
    final resolved = deviceInfo ?? StubDeviceInfoPlugin();
    return HealthTestContext._(resolved, isolateMode ?? HealthIsolateMode.auto);
  }

  HealthTestContext._(this.deviceInfo, HealthIsolateMode isolateMode)
    : channel = MethodChannelHarness(),
      health = Health(deviceInfo: deviceInfo, isolateMode: isolateMode);

  final DeviceInfoPlugin deviceInfo;
  final MethodChannelHarness channel;
  final Health health;

  /// Installs the channel mock and, unless [configure] is false, calls
  /// [Health.configure] like an app would.
  Future<void> setUp({MethodCallResponder? responder, bool configure = true}) async {
    await channel.setUp(responder: responder);
    if (configure) await health.configure();
  }

  Future<void> tearDown() async {
    await channel.tearDown();
  }
}
