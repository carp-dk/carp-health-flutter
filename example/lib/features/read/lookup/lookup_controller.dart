/// The state and plugin call of Read > Lookup: reading one record by its UUID with
/// `Health.getHealthDataByUUID`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_catalog.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/core/writes/recent_writes.dart';

import '../type_order.dart';

/// What one lookup by UUID found.
@immutable
class LookupResult {
  /// Creates the result of looking up [uuid] as a [type] record.
  const LookupResult({required this.uuid, required this.type, required this.point, required this.elapsed});

  /// The UUID looked up.
  final String uuid;

  /// The data type asked for.
  final HealthDataType type;

  /// The record found, or null when `getHealthDataByUUID` returned null.
  final HealthDataPoint? point;

  /// How long the call took.
  final Duration elapsed;

  /// Whether a record was found.
  bool get found => point != null;
}

/// Holds the type and the UUID to look up (the UUID field's text), runs the lookup and exposes its
/// [result]; the Lookup section listens to it and to [uuidField].
class LookupController extends ChangeNotifier {
  /// Creates the controller, reading through [health], offering [types] (see [typesFor]).
  LookupController({required this.health, required List<HealthDataType> types})
    : types = List.unmodifiable(types),
      _type = initialTypes(const {HealthDataType.STEPS}, types).firstOrNull ?? HealthDataType.STEPS;

  /// The plugin instance the lookup goes through.
  final Health health;

  /// The types offered: those whose records have UUIDs.
  final List<HealthDataType> types;

  /// The UUID to look up, as typed or pasted. Owned and disposed by the controller.
  final TextEditingController uuidField = TextEditingController();

  HealthDataType _type;
  AsyncValue<LookupResult> _result = const AsyncIdle();
  bool _disposed = false;

  /// The types of [catalog] that `getHealthDataByUUID` can look up: those stored as records with a UUID.
  ///
  /// Left out are the HealthKit characteristics (biological sex, date of birth, blood type), which are
  /// values of the user rather than samples, and on Android the body mass index, which the plugin computes
  /// from weight and height records instead of reading records of its own.
  static List<HealthDataType> typesFor(TypeCatalog catalog) => inDisplayOrder(
    catalog.available.where(
      (type) =>
          type.category != TypeCategory.characteristics &&
          !(catalog.capabilities.isAndroid && type == HealthDataType.BODY_MASS_INDEX),
    ),
  );

  /// The data type to look the UUID up as (`type`); iOS needs it to find the sample, and on Android a
  /// record has data of some types only.
  HealthDataType get type => _type;

  set type(HealthDataType type) {
    if (type == _type) return;
    _type = type;
    _notify();
  }

  /// The UUID in the field, without surrounding spaces.
  String get uuid => uuidField.text.trim();

  /// The state of the last lookup.
  AsyncValue<LookupResult> get result => _result;

  /// Whether a lookup can start: none runs and a UUID was entered.
  bool get canLookUp => !_result.isLoading && uuid.isNotEmpty;

  /// Looks the UUID up as a [type] record with `getHealthDataByUUID`. Never throws: a failure becomes an
  /// [AsyncError], and a null from the plugin a [LookupResult] without a point.
  Future<void> lookUp() async {
    if (!canLookUp) return;
    final uuid = this.uuid;
    final type = _type;
    _result = _result.toLoading();
    _notify();
    final stopwatch = Stopwatch()..start();
    final result = await AsyncValue.guard(() async {
      final point = await health.getHealthDataByUUID(uuid: uuid, type: type);
      return LookupResult(uuid: uuid, type: type, point: point, elapsed: stopwatch.elapsed);
    });
    if (_disposed) return;
    _result = result;
    _notify();
  }

  /// Fills in the type and UUID of [write], a record this app wrote, and looks it up.
  Future<void> lookUpWrite(RecentWrite write) async {
    final uuid = write.uuid;
    if (uuid == null || _result.isLoading) return;
    _type = write.type;
    uuidField.text = uuid;
    await lookUp();
  }

  /// Forgets the result, for example after the record was deleted.
  void clearResult() {
    if (_result.isLoading) return;
    _result = const AsyncIdle();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    uuidField.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
