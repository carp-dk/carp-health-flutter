import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/core/time/time_range.dart';

void main() {
  final now = DateTime(2026, 11, 16, 14, 30);

  group('presets end now', () {
    test('last hour and last 24 hours are rolling windows', () {
      expect(TimeRange.preset(TimeRangePreset.lastHour, now: now).start, DateTime(2026, 11, 16, 13, 30));
      expect(TimeRange.preset(TimeRangePreset.last24Hours, now: now).start, DateTime(2026, 11, 15, 14, 30));
    });

    test('today starts at midnight', () {
      final range = TimeRange.preset(TimeRangePreset.today, now: now);
      expect(range.start, DateTime(2026, 11, 16));
      expect(range.end, now);
      expect(range.duration, const Duration(hours: 14, minutes: 30));
    });

    test('multi-day presets start at midnight and include today', () {
      expect(TimeRange.preset(TimeRangePreset.last7Days, now: now).start, DateTime(2026, 11, 10));
      expect(TimeRange.preset(TimeRangePreset.last30Days, now: now).start, DateTime(2026, 10, 18));
    });

    test('custom has no range of its own: the last 24 hours', () {
      final range = TimeRange.preset(TimeRangePreset.custom, now: now);
      expect(range.preset, TimeRangePreset.custom);
      expect(range.duration, const Duration(hours: 24));
    });
  });

  group('custom ranges', () {
    test('swap a start after the end', () {
      final range = TimeRange.custom(now, DateTime(2026, 11, 1));
      expect(range.start, DateTime(2026, 11, 1));
      expect(range.end, now);
      expect(range.preset, TimeRangePreset.custom);
    });

    // A year in the past, as labels leave out the current year.
    test('label whole days as dates', () {
      final range = TimeRange.custom(DateTime(2020, 11, 10), DateTime(2020, 11, 16));
      expect(range.label, '10 Nov 2020 – 16 Nov 2020');
    });

    test('label other ranges with times', () {
      final range = TimeRange.custom(DateTime(2020, 3, 2, 8), DateTime(2020, 3, 2, 9, 15));
      expect(range.label, '2 Mar 2020, 08:00 – 09:15');
    });
  });

  test('presets are labelled with their name', () {
    expect(TimeRange.preset(TimeRangePreset.last7Days, now: now).label, 'Last 7 days');
  });

  test('contains includes both ends', () {
    final range = TimeRange.custom(DateTime(2026, 1, 1), DateTime(2026, 1, 2));
    expect(range.contains(DateTime(2026, 1, 1)), isTrue);
    expect(range.contains(DateTime(2026, 1, 2)), isTrue);
    expect(range.contains(DateTime(2026, 1, 3)), isFalse);
  });

  test('refreshed moves a preset to the new now and keeps a custom range', () {
    final range = TimeRange.preset(TimeRangePreset.lastHour, now: now);
    final later = now.add(const Duration(minutes: 10));
    expect(range.refreshed(now: later).end, later);
    final custom = TimeRange.custom(DateTime(2026, 1, 1), DateTime(2026, 1, 2));
    expect(custom.refreshed(now: later), custom);
  });

  test('ranges are equal by value', () {
    expect(TimeRange.preset(TimeRangePreset.today, now: now), TimeRange.preset(TimeRangePreset.today, now: now));
    expect(
      TimeRange.preset(TimeRangePreset.today, now: now).hashCode,
      TimeRange.preset(TimeRangePreset.today, now: now).hashCode,
    );
  });
}
