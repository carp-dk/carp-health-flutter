import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/features/setup/models/runtime_permission.dart';
import 'package:health_example/features/setup/setup_page.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/support/fake_health.dart';
import '../../shared/support/shared_test_app.dart';

/// A [FakeHealth] with every feature that grants every permission and has nothing left to ask.
class _GrantedHealth extends FakeHealth {
  _GrantedHealth() : super(features: allFeatures());

  @override
  Future<bool> isHealthConnectAvailable() async => true;

  @override
  Future<bool?> hasPermissions(List<HealthDataType> types, {List<HealthDataAccess>? permissions}) async => true;

  @override
  Future<HealthAuthorizationRequestStatus?> getRequestStatusForAuthorization(
    List<HealthDataType> types, {
    List<HealthDataAccess>? permissions,
  }) async => HealthAuthorizationRequestStatus.unnecessary;
}

/// Answers every runtime permission as not granted yet.
class _DeniedGateway implements RuntimePermissionGateway {
  @override
  Future<PermissionStatus> status(Permission permission) async => PermissionStatus.denied;

  @override
  Future<PermissionStatus> request(Permission permission) async => PermissionStatus.denied;

  @override
  Future<bool> openSettings() async => true;
}

/// Shows the Setup page on [platform] and lets its first checks complete; the loading and wavy
/// indicators never settle, so time is pumped instead.
Future<void> _showSetup(WidgetTester tester, HealthPlatformType platform) async {
  usePhoneSize(tester);
  final services = testServices(_GrantedHealth(), platform: platform);
  await tester.pumpWidget(sharedTestApp(SetupPage(runtimeGateway: _DeniedGateway()), services: services));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Scrolls the page until [finder] is built and visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('Android: shows platform status, permissions, features and settings cleanly', (tester) async {
    await _showSetup(tester, HealthPlatformType.googleHealthConnect);

    expect(find.text('Available'), findsWidgets);
    expect(find.text('getHealthConnectSdkStatus'), findsNothing);

    await _scrollTo(tester, find.text('Revoke all permissions'));
    expect(find.text('revokePermissions'), findsNothing);
    await _scrollTo(tester, find.text('Health data history'));
    expect(find.text('Granted'), findsWidgets);
    await _scrollTo(tester, find.text('Activity recognition'));
    expect(find.text('android.permission.ACTIVITY_RECOGNITION'), findsNothing);
    await _scrollTo(tester, find.text('Device id'));
    expect(find.text('Health.deviceId'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS: the Android-only parts are one-line notes', (tester) async {
    await _showSetup(tester, HealthPlatformType.appleHealth);

    expect(find.text('Built into iOS 18'), findsOneWidget);
    await _scrollTo(tester, find.text('Already answered'));
    await _scrollTo(tester, find.text('Revoke permissions'));
    await _scrollTo(tester, find.text('Android only'));
    await _scrollTo(tester, find.text('Not needed on iOS'));
    expect(tester.takeException(), isNull);
  });
}
