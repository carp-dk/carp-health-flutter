import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/features/read/lookup/lookup_controller.dart';

import '../../../shared/support/sample_points.dart';
import '../../../shared/support/shared_test_app.dart';

void main() {
  late LookupHealth health;
  late LookupController controller;

  setUp(() {
    health = LookupHealth();
    controller = LookupController(health: health, types: const [HealthDataType.STEPS, HealthDataType.HEART_RATE]);
  });
  tearDown(() => controller.dispose());

  LookupResult resultOf(LookupController controller) => (controller.result as AsyncData<LookupResult>).value;

  test('offers the types with records: no characteristics, and no computed BMI on Android', () {
    TypeCatalog catalogOn(HealthPlatformType platform) {
      final capabilities = PlatformCapabilities(health, platform: platform, iosMajorVersion: 18);
      addTearDown(capabilities.dispose);
      return TypeCatalog(capabilities);
    }

    final android = LookupController.typesFor(catalogOn(HealthPlatformType.googleHealthConnect));
    final ios = LookupController.typesFor(catalogOn(HealthPlatformType.appleHealth));

    expect(android, contains(HealthDataType.STEPS));
    expect(android, isNot(contains(HealthDataType.BODY_MASS_INDEX)));
    expect(ios, contains(HealthDataType.BODY_MASS_INDEX));
    expect(ios, isNot(contains(HealthDataType.BLOOD_TYPE)));
    expect(ios, isNot(contains(HealthDataType.BIRTH_DATE)));
  });

  test('starts with steps and needs a UUID', () async {
    expect(controller.type, HealthDataType.STEPS);
    expect(controller.canLookUp, isFalse);

    await controller.lookUp();

    expect(health.lookups, isEmpty);
  });

  test('looks the trimmed UUID up as the chosen type', () async {
    health.records['uuid-hr'] = heartRatePoint();
    controller
      ..type = HealthDataType.HEART_RATE
      ..uuidField.text = '  uuid-hr ';

    await controller.lookUp();

    expect(health.lookups, [('uuid-hr', HealthDataType.HEART_RATE)]);
    expect(resultOf(controller).found, isTrue);
    expect(resultOf(controller).point!.uuid, 'uuid-hr');
  });

  test('reports a null from the plugin as a result without a point', () async {
    controller.uuidField.text = 'missing';

    await controller.lookUp();

    expect(resultOf(controller).found, isFalse);
    expect(resultOf(controller).uuid, 'missing');
  });

  test('turns an error into an AsyncError', () async {
    health.lookupError = HealthPlatformException(
      HealthDataType.STEPS,
      PlatformException(code: 'PERMISSION_DENIED', message: 'No access'),
    );
    controller.uuidField.text = 'uuid-1';

    await controller.lookUp();

    expect(controller.result.errorOrNull, isA<HealthPlatformException>());
  });

  test('looks up a recent write by its type and UUID, and ignores writes without one', () async {
    health.records['uuid-hr'] = heartRatePoint();

    await controller.lookUpWrite(RecentWrite(type: HealthDataType.HEART_RATE, description: '72 bpm'));
    expect(health.lookups, isEmpty);

    await controller.lookUpWrite(RecentWrite(type: HealthDataType.HEART_RATE, description: '72 bpm', uuid: 'uuid-hr'));
    expect(controller.type, HealthDataType.HEART_RATE);
    expect(controller.uuid, 'uuid-hr');
    expect(resultOf(controller).found, isTrue);

    controller.clearResult();
    expect(controller.result, isA<AsyncIdle<LookupResult>>());
  });
}
