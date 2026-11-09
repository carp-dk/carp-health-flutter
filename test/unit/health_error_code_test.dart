import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthErrorCode', () {
    test('every code maps back from its platform code', () {
      for (final code in HealthErrorCode.values) {
        expect(HealthErrorCode.fromPlatformCode(code.platformCode), code);
      }
      expect(HealthErrorCode.unknown.platformCode, 'HEALTH_ERROR');
    });

    test('rate limits, unavailability and a locked device are retryable', () {
      expect(HealthErrorCode.values.where((code) => code.isRetryable), [
        HealthErrorCode.rateLimitExceeded,
        HealthErrorCode.unavailable,
        HealthErrorCode.deviceLocked,
      ]);
    });

    test('exceptions raised by the plugin have no platform code', () {
      final error = HealthException(HealthDataType.STEPS, 'Not available');

      expect(error.errorCode, HealthErrorCode.unknown);
      expect(error.platformCode, isNull);
      expect(error.details, isNull);
      expect(error.isRetryable, isFalse);
      expect(error.toString(), "Error requesting health data type 'HealthDataType.STEPS' - cause: Not available");
    });

    test('platform exceptions show their code', () {
      final error = HealthPlatformException(
        HealthDataType.STEPS,
        PlatformException(code: 'UNAVAILABLE', message: 'busy', details: {'nativeCode': 4}),
      );

      expect(error.cause, 'busy');
      expect(error.platformCode, 'UNAVAILABLE');
      expect(error.isRetryable, isTrue);
      expect(error.toString(), "Error requesting health data type 'HealthDataType.STEPS' - cause: busy (UNAVAILABLE)");
    });
  });
}
