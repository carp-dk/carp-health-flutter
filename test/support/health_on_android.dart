import 'package:health/health.dart';

import 'stub_device_info.dart';

/// [Health] on Android, for the checks that depend on [Health.platformType] or
/// [Health.isDataTypeAvailable], such as the types only Health Connect has. The
/// tests run on a desktop host, where [Health.platformType] is Health Connect
/// but [Health.isDataTypeAvailable] has the iOS data types.
class HealthOnAndroid extends Health {
  HealthOnAndroid() : super(deviceInfo: StubDeviceInfoPlugin());

  @override
  HealthPlatformType get platformType => HealthPlatformType.googleHealthConnect;

  @override
  bool isDataTypeAvailable(HealthDataType dataType) => dataTypeKeysAndroid.contains(dataType);
}
