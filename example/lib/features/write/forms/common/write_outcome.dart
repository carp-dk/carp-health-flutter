/// What one write returned, as the Write page's own forms (measurement, blood pressure, blood oxygen,
/// meal) and its sample data show it.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// The result of a plugin write: which [method] wrote what ([type], [description]), whether the plugin
/// saved it ([success]) and what the call returned ([returned]), with the ids to find the record again.
///
/// The plugin's write methods report failure in their return value rather than by throwing: `false`,
/// or for the `...UUID` methods an empty string. Arguments the plugin rejects throw instead (an
/// `ArgumentError`, a `HealthException` or a `PlatformException`), which the forms show as errors.
@immutable
class WriteOutcome {
  /// Creates an outcome; [WriteOutcome.fromBool] and [WriteOutcome.fromUuid] derive one from what a
  /// write method returned.
  const WriteOutcome({
    required this.method,
    required this.type,
    required this.description,
    required this.success,
    required this.returned,
    this.uuid,
    this.clientRecordId,
  });

  /// The outcome of a write method that returns whether it saved the data, such as `writeHealthData`.
  factory WriteOutcome.fromBool(
    String method,
    HealthDataType type,
    String description,
    bool saved, {
    String? clientRecordId,
  }) => WriteOutcome(
    method: method,
    type: type,
    description: description,
    success: saved,
    returned: '$saved',
    clientRecordId: saved ? clientRecordId : null,
  );

  /// The outcome of a write method that returns the new record's UUID, such as `writeHealthDataUUID`.
  ///
  /// These methods turn the platform's reply into a string: an empty one when nothing was saved, and
  /// "null" when the platform sent no reply at all. Neither names a record.
  factory WriteOutcome.fromUuid(
    String method,
    HealthDataType type,
    String description,
    String? uuid, {
    String? clientRecordId,
  }) {
    final saved = uuid != null && uuid.isNotEmpty && uuid != 'null';
    return WriteOutcome(
      method: method,
      type: type,
      description: description,
      success: saved,
      returned: uuid == null ? 'null' : '"$uuid"',
      uuid: saved ? uuid : null,
      clientRecordId: saved ? clientRecordId : null,
    );
  }

  /// The plugin method called, such as `writeHealthDataUUID`.
  final String method;

  /// The data type written.
  final HealthDataType type;

  /// What was written, such as "72 bpm".
  final String description;

  /// Whether the plugin saved the data.
  final bool success;

  /// What the call returned, as Dart would print it: `true`, `false`, `"<uuid>"` or `""`.
  final String returned;

  /// The new record's UUID, when the method returns one and the record was saved.
  final String? uuid;

  /// The Health Connect client record id the write used, when it was saved with one.
  final String? clientRecordId;

  @override
  String toString() => 'WriteOutcome($method → $returned)';
}
