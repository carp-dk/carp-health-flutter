import 'package:health/health.dart';

import 'stub_device_info.dart';

/// [Health] on iOS, for the checks that depend on [Health.platformType]. The
/// tests run on a desktop host, where [Health.platformType] is Health Connect
/// and [Health.isDataTypeAvailable] has the iOS data types.
class HealthOnIOS extends Health {
  HealthOnIOS() : super(deviceInfo: StubDeviceInfoPlugin());

  @override
  HealthPlatformType get platformType => HealthPlatformType.appleHealth;
}
