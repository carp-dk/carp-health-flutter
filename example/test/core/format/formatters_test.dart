import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';

void main() {
  final now = DateTime(2026, 11, 16, 14, 30);

  group('formatNumber', () {
    test('groups thousands and trims trailing zeros', () {
      expect(formatNumber(12345), '12,345');
      expect(formatNumber(1234567.891), '1,234,567.89');
      expect(formatNumber(3.10), '3.1');
      expect(formatNumber(3.0), '3');
      expect(formatNumber(0), '0');
    });

    test('respects maxDecimals', () {
      expect(formatNumber(2.345678, maxDecimals: 3), '2.346');
      expect(formatNumber(2.5, maxDecimals: 0), '3');
    });

    test('handles negatives, negative zero and non-finite values', () {
      expect(formatNumber(-1234.5), '-1,234.5');
      expect(formatNumber(-0.001), '0');
      expect(formatNumber(double.nan), '–');
      expect(formatNumber(double.infinity), '∞');
      expect(formatNumber(double.negativeInfinity), '-∞');
    });
  });

  group('formatDuration', () {
    test('uses the two largest units', () {
      expect(formatDuration(const Duration(hours: 7, minutes: 32, seconds: 10)), '7 h 32 min');
      expect(formatDuration(const Duration(minutes: 45)), '45 min');
      expect(formatDuration(const Duration(minutes: 1, seconds: 30)), '1 min 30 s');
      expect(formatDuration(const Duration(days: 2, hours: 3)), '2 d 3 h');
      expect(formatDuration(const Duration(hours: 2)), '2 h');
      expect(formatDuration(const Duration(seconds: 42)), '42 s');
    });

    test('handles zero, milliseconds and negative durations', () {
      expect(formatDuration(Duration.zero), '0 s');
      expect(formatDuration(const Duration(milliseconds: 250)), '250 ms');
      expect(formatDuration(const Duration(minutes: -5)), '-5 min');
    });
  });

  group('dates and times', () {
    test('formatTime is 24-hour with optional seconds', () {
      expect(formatTime(DateTime(2026, 1, 1, 7, 5, 9)), '07:05');
      expect(formatTime(DateTime(2026, 1, 1, 7, 5, 9), withSeconds: true), '07:05:09');
    });

    test('formatDate shows the year only when it differs', () {
      expect(formatDate(DateTime(2026, 11, 2), now: now), '2 Nov');
      expect(formatDate(DateTime(2025, 11, 2), now: now), '2 Nov 2025');
      expect(formatDate(DateTime(2026, 11, 2), now: now, withYear: true), '2 Nov 2026');
    });

    test('formatDateTime names today and yesterday', () {
      expect(formatDateTime(DateTime(2026, 11, 16, 9, 15), now: now), 'Today, 09:15');
      expect(formatDateTime(DateTime(2026, 11, 15, 23, 0), now: now), 'Yesterday, 23:00');
      expect(formatDateTime(DateTime(2026, 11, 17, 8, 0), now: now), 'Tomorrow, 08:00');
      expect(formatDateTime(DateTime(2026, 11, 12, 14, 0), now: now), '12 Nov, 14:00');
    });

    test('formatDateTime shows UTC times in local time', () {
      final utc = DateTime.utc(2026, 11, 16, 12);
      expect(formatDateTime(utc, now: now), formatDateTime(utc.toLocal(), now: now));
    });

    test('formatTimeRange names the day once within a day', () {
      expect(
        formatTimeRange(DateTime(2026, 11, 16, 7), DateTime(2026, 11, 16, 7, 30), now: now),
        'Today, 07:00 – 07:30',
      );
      expect(
        formatTimeRange(DateTime(2026, 11, 14, 23), DateTime(2026, 11, 15, 7), now: now),
        '14 Nov, 23:00 – Yesterday, 07:00',
      );
      expect(formatTimeRange(DateTime(2026, 11, 16, 7), DateTime(2026, 11, 16, 7), now: now), 'Today, 07:00');
    });

    test('formatWeekday', () => expect(formatWeekday(DateTime(2026, 11, 16)), 'Mon'));
  });

  group('formatRelative', () {
    test('past', () {
      expect(formatRelative(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(formatRelative(now.subtract(const Duration(hours: 3)), now: now), '3 h ago');
      expect(formatRelative(DateTime(2026, 11, 15, 8), now: now), 'yesterday');
      expect(formatRelative(DateTime(2026, 11, 12, 8), now: now), '4 days ago');
      expect(formatRelative(DateTime(2026, 10, 1, 8), now: now), '1 Oct');
    });

    test('future', () {
      expect(formatRelative(now.add(const Duration(minutes: 5)), now: now), 'in 5 min');
      expect(formatRelative(DateTime(2026, 11, 17, 20), now: now), 'tomorrow');
    });
  });

  group('humanize', () {
    test('turns code names into words', () {
      expect(humanize('HIGH_INTENSITY_INTERVAL_TRAINING'), 'High intensity interval training');
      expect(humanize('motionPaused'), 'Motion paused');
      expect(humanize('sdkUnavailableProviderUpdateRequired'), 'Sdk unavailable provider update required');
      expect(humanize(''), '');
    });

    test('formatEnumName', () {
      expect(formatEnumName(HealthWorkoutActivityType.BIKING_STATIONARY), 'Biking stationary');
      expect(formatEnumName(RecordingMethod.automatic), 'Automatic');
    });
  });
}
