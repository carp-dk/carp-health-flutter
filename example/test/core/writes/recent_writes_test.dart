import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:health_example/core/writes/recent_writes.dart';

RecentWrite _write(int index, {String? uuid, HealthDataType type = HealthDataType.STEPS}) =>
    RecentWrite(type: type, description: 'write $index', uuid: uuid, at: DateTime(2026, 11, 16, 9, index % 60));

void main() {
  test('an empty UUID, which failed UUID writes return, counts as none', () {
    expect(_write(0, uuid: '').uuid, isNull);
    expect(_write(0, uuid: '').hasUuid, isFalse);
    expect(_write(0, uuid: 'A1').hasUuid, isTrue);
  });

  test('defaults the time to now', () {
    final before = DateTime.now();
    final write = RecentWrite(type: HealthDataType.WEIGHT, description: '72 kg');
    expect(write.at.isBefore(before), isFalse);
  });

  test('keeps writes newest first and notifies', () {
    final writes = RecentWrites();
    var notifications = 0;
    writes.addListener(() => notifications++);
    final first = _write(1);
    final second = _write(2);
    writes
      ..add(first)
      ..add(second);
    expect(writes.items, [second, first]);
    expect(notifications, 2);
  });

  test('keeps at most the capacity, dropping the oldest', () {
    final writes = RecentWrites();
    for (var index = 0; index < RecentWrites.capacity + 5; index++) {
      writes.add(_write(index));
    }
    expect(writes.items, hasLength(RecentWrites.capacity));
    expect(writes.items.first.description, 'write ${RecentWrites.capacity + 4}');
    expect(writes.items.last.description, 'write 5');
  });

  test('filters by UUID and type', () {
    final writes = RecentWrites()
      ..add(_write(1, uuid: 'A'))
      ..add(_write(2))
      ..add(_write(3, uuid: 'B', type: HealthDataType.WORKOUT));
    expect(writes.withUuid.map((write) => write.uuid), ['B', 'A']);
    expect(writes.ofType(HealthDataType.WORKOUT).single.uuid, 'B');
  });

  test('remove and clear notify only when something changed', () {
    final write = _write(1);
    final writes = RecentWrites()..add(write);
    var notifications = 0;
    writes.addListener(() => notifications++);
    writes
      ..remove(_write(9))
      ..remove(write)
      ..clear();
    expect(writes.items, isEmpty);
    expect(notifications, 1);
  });

  test('items cannot be changed from outside', () {
    final writes = RecentWrites()..add(_write(1));
    expect(() => writes.items.clear(), throwsUnsupportedError);
  });
}
