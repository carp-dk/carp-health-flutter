import 'package:flutter_test/flutter_test.dart';

import '../support/stub_device_info.dart';

/// The stub builds its device infos from maps, as device_info_plus does from the platform's reply.
/// The tests run on a desktop host, where the plugin reads only the iOS info, so a field that a new
/// device_info_plus version requires fails here first.
void main() {
  test('the stub builds the Android and iOS device infos', () async {
    final stub = StubDeviceInfoPlugin(androidId: 'android-id', iosId: 'ios-id');

    expect((await stub.androidInfo).id, 'android-id');
    expect((await stub.iosInfo).identifierForVendor, 'ios-id');
    expect((await stub.deviceInfo).data['id'], 'android-id');
  });
}
