import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';

import '../support/fake_health.dart';

PlatformCapabilities _android(FakeHealth health) =>
    PlatformCapabilities(health, platform: HealthPlatformType.googleHealthConnect);

PlatformCapabilities _ios(int? version, [FakeHealth? health]) => PlatformCapabilities(
  health ?? FakeHealth(sdkStatus: null, features: {FakeCheck.mindfulness: true}),
  platform: HealthPlatformType.appleHealth,
  iosMajorVersion: version,
);

void main() {
  group('Android', () {
    test('reads the status and every feature', () async {
      final health = FakeHealth(features: allFeatures());
      final capabilities = _android(health);
      expect(capabilities.isLoaded, isFalse);

      await capabilities.refresh();

      expect(capabilities.isLoaded, isTrue);
      expect(capabilities.isAndroid, isTrue);
      expect(capabilities.isIOS, isFalse);
      expect(capabilities.platformName, 'Health Connect');
      expect(capabilities.sdkStatus, HealthConnectSdkStatus.sdkAvailable);
      expect(capabilities.healthConnectAvailable, isTrue);
      expect(capabilities.historyAvailable, isTrue);
      expect(capabilities.backgroundAuthorized, isTrue);
      expect(capabilities.skinTemperatureAvailable, isTrue);
      expect(capabilities.lastError, isNull);
      expect(capabilities.supports(HealthDataType.MINDFULNESS), isTrue);
      expect(capabilities.supports(HealthDataType.ACTIVITY_INTENSITY), isTrue);
    });

    test('leaves out the types whose Health Connect feature is missing', () async {
      // A base Android 15 device: skin temperature, but no mindfulness or activity intensity.
      final capabilities = _android(FakeHealth(features: {FakeCheck.skinTemperature: true}));
      await capabilities.refresh();
      expect(capabilities.supports(HealthDataType.SKIN_TEMPERATURE), isTrue);
      expect(capabilities.supports(HealthDataType.MINDFULNESS), isFalse);
      expect(capabilities.supports(HealthDataType.ACTIVITY_INTENSITY), isFalse);
      expect(capabilities.unsupportedReason(HealthDataType.MINDFULNESS), 'Not in this Health Connect');
      expect(capabilities.supports(HealthDataType.STEPS), isTrue);
    });

    test('feature types wait for the first refresh', () {
      final capabilities = _android(FakeHealth(features: allFeatures()));
      expect(capabilities.supports(HealthDataType.SKIN_TEMPERATURE), isFalse);
      expect(capabilities.unsupportedReason(HealthDataType.SKIN_TEMPERATURE), 'Checking Health Connect');
    });

    test('iOS-only types are not supported', () async {
      final capabilities = _android(FakeHealth());
      expect(capabilities.supports(HealthDataType.AUDIOGRAM), isFalse);
      expect(capabilities.unsupportedReason(HealthDataType.AUDIOGRAM), 'Not in Health Connect');
    });

    test('without Health Connect no feature is checked', () async {
      final health = FakeHealth(
        sdkStatus: HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired,
        features: allFeatures(),
      );
      final capabilities = _android(health);
      await capabilities.refresh();
      expect(capabilities.healthConnectAvailable, isFalse);
      expect(capabilities.needsHealthConnectInstall, isTrue);
      expect(capabilities.historyAvailable, isFalse);
      expect(health.calls[FakeCheck.historyAvailable], isNull);
      expect(capabilities.lastError, isNull);
    });

    test('a status the plugin could not read is an error', () async {
      final capabilities = _android(FakeHealth(sdkStatus: null));
      await capabilities.refresh();
      expect(capabilities.lastError, isA<StateError>());
      expect(capabilities.healthConnectAvailable, isFalse);
    });

    test('refresh never throws: a failing check leaves its flag false and is kept', () async {
      final health = FakeHealth(features: allFeatures(), failing: {FakeCheck.mindfulness});
      final capabilities = _android(health);
      await capabilities.refresh();
      expect(capabilities.mindfulnessAvailable, isFalse);
      expect(capabilities.skinTemperatureAvailable, isTrue, reason: 'other checks are unaffected');
      expect(capabilities.lastError, isA<FormatException>());
    });

    test('a failing status call is caught too', () async {
      final capabilities = _android(FakeHealth(failing: {FakeCheck.sdkStatus}));
      await capabilities.refresh();
      expect(capabilities.isLoaded, isTrue);
      expect(capabilities.lastError, isA<FormatException>());
    });

    test('a later refresh clears the error and updates the flags', () async {
      final health = FakeHealth(failing: {FakeCheck.sdkStatus});
      final capabilities = _android(health);
      await capabilities.refresh();
      health
        ..failing.clear()
        ..features.addAll(allFeatures());
      await capabilities.refresh();
      expect(capabilities.lastError, isNull);
      expect(capabilities.activityIntensityAvailable, isTrue);
    });

    test('notifies listeners once per refresh and shares concurrent refreshes', () async {
      final health = FakeHealth(features: allFeatures());
      final capabilities = _android(health);
      var notifications = 0;
      capabilities.addListener(() => notifications++);

      final first = capabilities.refresh();
      expect(capabilities.isRefreshing, isTrue);
      final second = capabilities.refresh();
      await Future.wait([first, second]);

      expect(notifications, 1);
      expect(health.calls[FakeCheck.sdkStatus], 1);
      expect(capabilities.isRefreshing, isFalse);
    });

    test('a refresh that ends after dispose does not notify', () async {
      final capabilities = _android(FakeHealth());
      final refresh = capabilities.refresh();
      capabilities.dispose();
      await expectLater(refresh, completes);
    });
  });

  group('iOS', () {
    test('mirrors the plugin answers and has no Health Connect status', () async {
      final capabilities = _ios(18);
      await capabilities.refresh();
      expect(capabilities.isIOS, isTrue);
      expect(capabilities.platformName, 'Apple Health');
      expect(capabilities.sdkStatus, isNull);
      expect(capabilities.healthConnectAvailable, isTrue);
      expect(capabilities.mindfulnessAvailable, isTrue);
      expect(capabilities.lastError, isNull);
    });

    test('leaves out types newer than the iOS version', () {
      final ios15 = _ios(15);
      expect(ios15.supports(HealthDataType.STEPS), isTrue);
      expect(ios15.supports(HealthDataType.UV_INDEX), isFalse);
      expect(ios15.unsupportedReason(HealthDataType.UV_INDEX), 'Needs iOS 16');

      final ios17 = _ios(17);
      expect(ios17.supports(HealthDataType.POWER), isTrue);
      expect(ios17.supports(HealthDataType.ROWING_SPEED), isFalse);

      expect(_ios(18).supports(HealthDataType.ROWING_SPEED), isTrue);
    });

    test('an unknown iOS version does not hide types', () {
      expect(_ios(null).supports(HealthDataType.ROWING_SPEED), isTrue);
    });

    test('Android-only types are not supported, feature or not', () {
      final ios = _ios(18);
      expect(ios.supports(HealthDataType.SLEEP_SESSION), isFalse);
      expect(ios.supports(HealthDataType.SKIN_TEMPERATURE), isFalse);
      expect(ios.supports(HealthDataType.MINDFULNESS), isTrue, reason: 'HealthKit has mindful sessions');
    });
  });

  test('on a test host, detection follows Flutter target platform: Android under flutter test', () {
    final capabilities = PlatformCapabilities(FakeHealth());
    expect(capabilities.isAndroid, isTrue);
    expect(capabilities.iosMajorVersion, isNull);
  });

  group('parseIosMajorVersion', () {
    test('reads the Darwin operatingSystemVersion format', () {
      expect(PlatformCapabilities.parseIosMajorVersion('Version 17.2 (Build 21C62)'), 17);
      expect(PlatformCapabilities.parseIosMajorVersion('Version 27.2 (Build 24C5)'), 27);
    });

    test('falls back to the first number', () => expect(PlatformCapabilities.parseIosMajorVersion('16.4.1'), 16));

    test('null without a number', () => expect(PlatformCapabilities.parseIosMajorVersion('unknown'), isNull));
  });
}
