import 'package:device_info_plus/device_info_plus.dart';
import 'package:health/health.dart';

import 'method_channel_harness.dart';
import 'stub_device_info.dart';

class HealthTestContext {
  factory HealthTestContext({DeviceInfoPlugin? deviceInfo}) {
    final resolved = deviceInfo ?? StubDeviceInfoPlugin();
    return HealthTestContext._(resolved);
  }

  HealthTestContext._(this.deviceInfo)
      : channel = MethodChannelHarness(),
        health = Health(deviceInfo: deviceInfo);

  final DeviceInfoPlugin deviceInfo;
  final MethodChannelHarness channel;
  final Health health;

  Future<void> setUp({MethodCallResponder? responder}) async {
    await channel.setUp(responder: responder);
    await health.configure();
  }

  Future<void> tearDown() async {
    await channel.tearDown();
  }
}
