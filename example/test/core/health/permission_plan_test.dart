import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/permission_plan.dart';
import 'package:health_example/core/health/type_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_health');

  setUp(() {
    // Answers the native requestAuthorization call, so only the plugin's Dart checks can fail.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => true,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('accessFor', () {
    test('asks for read and write access by default', () {
      expect(PermissionPlan.accessFor(HealthDataType.STEPS), HealthDataAccess.READ_WRITE);
      expect(PermissionPlan.accessFor(HealthDataType.WORKOUT_ROUTE), HealthDataAccess.READ_WRITE);
    });

    test('asks only for read access to read-only types', () {
      for (final type in [...TypeRules.iosReadOnly, ...TypeRules.characteristics, ...TypeRules.neverWritten]) {
        expect(PermissionPlan.accessFor(type), HealthDataAccess.READ, reason: type.name);
        expect(PermissionPlan.accessFor(type, preferred: HealthDataAccess.WRITE), HealthDataAccess.READ);
      }
    });

    test('keeps a preferred READ or WRITE where it is allowed', () {
      expect(PermissionPlan.accessFor(HealthDataType.STEPS, preferred: HealthDataAccess.READ), HealthDataAccess.READ);
      expect(PermissionPlan.accessFor(HealthDataType.STEPS, preferred: HealthDataAccess.WRITE), HealthDataAccess.WRITE);
    });

    test('accessesFor keeps the order and length of the types', () {
      final types = [HealthDataType.STEPS, HealthDataType.ELECTROCARDIOGRAM, HealthDataType.WEIGHT];
      expect(PermissionPlan.accessesFor(types), [
        HealthDataAccess.READ_WRITE,
        HealthDataAccess.READ,
        HealthDataAccess.READ_WRITE,
      ]);
    });
  });

  group('against the plugin', () {
    test('a request for every type with the planned access passes the plugin checks', () async {
      const types = HealthDataType.values;
      final granted = await Health().requestAuthorization(types, permissions: PermissionPlan.accessesFor(types));
      expect(granted, isTrue);
    });

    test('the iOS read-only set matches the plugin: write access to each is refused', () async {
      for (final type in TypeRules.iosReadOnly) {
        await expectLater(
          Health().requestAuthorization([type], permissions: [HealthDataAccess.READ_WRITE]),
          throwsArgumentError,
          reason: type.name,
        );
      }
    });

    test('characteristics and never-written types are read-only for other reasons', () async {
      // The plugin's Dart check lets these through; the plan still asks only to read them.
      final types = [...TypeRules.characteristics, ...TypeRules.neverWritten];
      final granted = await Health().requestAuthorization(
        types,
        permissions: List.filled(types.length, HealthDataAccess.READ_WRITE),
      );
      expect(granted, isTrue);
    });
  });
}
