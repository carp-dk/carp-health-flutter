import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/setup/models/authorization_outcome.dart';
import 'package:health_example/features/setup/models/request_status_info.dart';
import 'package:health_example/features/setup/models/runtime_permission.dart';
import 'package:health_example/features/setup/models/sdk_status_info.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('SdkStatusInfo', () {
    test('offers installHealthConnect only where Health Connect must be installed or updated', () {
      for (final status in HealthConnectSdkStatus.values) {
        expect(
          SdkStatusInfo.of(status).offersInstall,
          status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired,
          reason: status.name,
        );
      }
      expect(SdkStatusInfo.of(null).offersInstall, isFalse);
      expect(SdkStatusInfo.checking.offersInstall, isFalse);
    });

    test('explains each status, including what Android 14 and later change', () {
      expect(SdkStatusInfo.of(HealthConnectSdkStatus.sdkAvailable).tone, StatusTone.success);
      expect(SdkStatusInfo.of(HealthConnectSdkStatus.sdkAvailable).explanation, contains('Android 14'));
      final update = SdkStatusInfo.of(HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired);
      expect(update.tone, StatusTone.warning);
      expect(
        update.explanation,
        allOf(contains('Android 13'), contains('Android 14'), contains('installHealthConnect')),
      );
      expect(SdkStatusInfo.of(HealthConnectSdkStatus.sdkUnavailable).tone, StatusTone.error);
      expect(SdkStatusInfo.of(null).label, 'Unknown');
    });

    test('has nothing to install for HealthKit, on a known or an unknown iOS version', () {
      final ios18 = SdkStatusInfo.healthKit(18);

      expect(ios18.offersInstall, isFalse);
      expect(ios18.tone, StatusTone.success);
      expect(ios18.label, 'Built into iOS 18');
      expect(SdkStatusInfo.healthKit(null).label, 'Built into iOS');
    });
  });

  test('words the result of requestAuthorization as each platform means it', () {
    final healthConnectTrue = AuthorizationOutcome.of(true, isIOS: false);
    final healthConnectFalse = AuthorizationOutcome.of(false, isIOS: false);
    final healthKitTrue = AuthorizationOutcome.of(true, isIOS: true);
    final healthKitFalse = AuthorizationOutcome.of(false, isIOS: true);

    expect(healthConnectTrue.label, 'At least one granted');
    expect(healthConnectTrue.tone, StatusTone.success);
    expect(healthConnectFalse.tone, StatusTone.warning);
    expect(healthConnectFalse.explanation, contains('FlutterFragmentActivity'));
    // True on iOS only means that HealthKit handled the request.
    expect(healthKitTrue.tone, StatusTone.info);
    expect(healthKitTrue.explanation, contains('never tells'));
    expect(healthKitFalse.tone, StatusTone.error);
  });

  test('words each request status of getRequestStatusForAuthorization', () {
    expect(RequestStatusInfo.of(HealthAuthorizationRequestStatus.shouldRequest).label, 'Sheet will show');
    expect(RequestStatusInfo.of(HealthAuthorizationRequestStatus.unnecessary).label, 'Already answered');
    expect(RequestStatusInfo.of(HealthAuthorizationRequestStatus.unknown).tone, StatusTone.neutral);
    expect(RequestStatusInfo.of(null).label, 'No status');
  });

  group('runtime permissions', () {
    test('are the permission_handler permissions the README names', () {
      expect(RuntimePermission.activityRecognition.permission, Permission.activityRecognition);
      expect(RuntimePermission.activityRecognition.manifestName, 'android.permission.ACTIVITY_RECOGNITION');
      expect(RuntimePermission.location.permission, Permission.location);
      expect(RuntimePermission.location.purpose, contains('workout routes'));
    });

    test('offer what each status allows', () {
      expect(RuntimeStatusView.of(PermissionStatus.granted).action, RuntimePermissionAction.none);
      expect(RuntimeStatusView.of(PermissionStatus.denied).action, RuntimePermissionAction.request);
      // Android shows no dialog for a permission the user denied twice: only the settings can grant it.
      expect(RuntimeStatusView.of(PermissionStatus.permanentlyDenied).action, RuntimePermissionAction.openSettings);
      expect(RuntimeStatusView.of(PermissionStatus.restricted).action, RuntimePermissionAction.none);
      expect(RuntimeStatusView.of(PermissionStatus.limited).action, RuntimePermissionAction.request);
      for (final status in PermissionStatus.values) {
        expect(RuntimeStatusView.of(status).label, isNotEmpty, reason: status.name);
      }
    });
  });
}
