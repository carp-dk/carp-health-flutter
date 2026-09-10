import 'package:device_info_plus/device_info_plus.dart';

class StubDeviceInfoPlugin implements DeviceInfoPlugin {
  StubDeviceInfoPlugin({
    this.androidId = 'stub-android-id',
    this.iosId = 'stub-ios-id',
  });

  final String androidId;
  final String iosId;

  @override
  Future<BaseDeviceInfo> get deviceInfo => androidInfo;

  @override
  Future<AndroidDeviceInfo> get androidInfo => Future<AndroidDeviceInfo>.value(
        AndroidDeviceInfo.fromMap({
          'id': androidId,
          'version': {
            'baseOS': 'stub-baseOS',
            'codename': 'stub-codename',
            'incremental': 'stub-incremental',
            'previewSdkInt': 0,
            'release': 'stub-release',
            'sdkInt': 34,
            'securityPatch': 'stub-securityPatch',
          },
          'board': 'stub-board',
          'bootloader': 'stub-bootloader',
          'brand': 'stub-brand',
          'device': 'stub-device',
          'display': 'stub-display',
          'fingerprint': 'stub-fingerprint',
          'hardware': 'stub-hardware',
          'host': 'stub-host',
          'manufacturer': 'stub-manufacturer',
          'model': 'stub-model',
          'product': 'stub-product',
          'supported32BitAbis': <String>[],
          'supported64BitAbis': <String>[],
          'supportedAbis': <String>[],
          'tags': 'stub-tags',
          'type': 'stub-type',
          'isPhysicalDevice': true,
          'systemFeatures': <String>[],
          'serialNumber': 'stub-serial',
          'isLowRamDevice': false,
        }),
      );

  @override
  Future<IosDeviceInfo> get iosInfo => Future<IosDeviceInfo>.value(
        IosDeviceInfo.fromMap({
          'name': 'stub-ios-name',
          'systemName': 'stub-ios-systemName',
          'systemVersion': '17.0',
          'model': 'stub-ios-model',
          'modelName': 'stub-ios-modelName',
          'localizedModel': 'stub-ios-localizedModel',
          'identifierForVendor': iosId,
          'isPhysicalDevice': true,
          'freeDiskSize': 128000000000,
          'totalDiskSize': 256000000000,
          'physicalRamSize': 8192,
          'availableRamSize': 4096,
          'isiOSAppOnMac': false,
          'utsname': {
            'sysname': 'stub-ios-sysname',
            'nodename': 'stub-ios-nodename',
            'release': 'stub-ios-release',
            'version': 'stub-ios-version',
            'machine': 'stub-ios-machine',
          },
        }),
      );

  @override
  Future<LinuxDeviceInfo> get linuxInfo => Future<LinuxDeviceInfo>.error(
        UnsupportedError('linuxInfo is not supported in StubDeviceInfoPlugin.'),
      );

  @override
  Future<MacOsDeviceInfo> get macOsInfo => Future<MacOsDeviceInfo>.error(
        UnsupportedError('macOsInfo is not supported in StubDeviceInfoPlugin.'),
      );

  @override
  Future<WebBrowserInfo> get webBrowserInfo => Future<WebBrowserInfo>.error(
        UnsupportedError('webBrowserInfo is not supported in StubDeviceInfoPlugin.'),
      );

  @override
  Future<WindowsDeviceInfo> get windowsInfo => Future<WindowsDeviceInfo>.error(
        UnsupportedError('windowsInfo is not supported in StubDeviceInfoPlugin.'),
      );
}
