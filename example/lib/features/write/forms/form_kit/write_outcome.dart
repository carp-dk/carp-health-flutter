/// What the last write of a form returned, as the form's result card shows it and `reportWriteResult`
/// reports it.
library;

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// The result of one write: the plugin method that ran, what it wrote and what it returned.
@immutable
class WriteOutcome {
  /// The outcome of a call of [method] (such as `writeWorkoutData`) that wrote [description] of [type]
  /// and returned [success]. [uuid] is the id the call returned, if it returns one, and [clientRecordId]
  /// the Health Connect client record id it wrote, if any.
  WriteOutcome({
    required this.type,
    required this.method,
    required this.description,
    required this.success,
    this.uuid,
    this.clientRecordId,
    this.discarded = false,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  /// The outcome of a write method that returns the new record's UUID instead of a bool, such as
  /// `writeWorkoutDataUUID` or `finishWorkoutRoute`: [success] when [returned] is a real id.
  factory WriteOutcome.fromUuid({
    required HealthDataType type,
    required String method,
    required String description,
    required String? returned,
    String? clientRecordId,
  }) {
    final saved = isSavedUuid(returned);
    return WriteOutcome(
      type: type,
      method: method,
      description: description,
      success: saved,
      uuid: saved ? returned : null,
      clientRecordId: clientRecordId,
    );
  }

  /// Whether [uuid], as a `...UUID` write method returned it, names a saved record. The methods return an
  /// empty string when nothing was saved, and `writeWorkoutDataUUID` turns a missing answer into "null".
  static bool isSavedUuid(String? uuid) => uuid != null && uuid.isNotEmpty && uuid != 'null';

  /// The data type written.
  final HealthDataType type;

  /// The plugin method that ran, such as `writeSleepSession`.
  final String method;

  /// What was written, in a few words, such as "Running · 30 min · 5 km".
  final String description;

  /// Whether the platform saved the data: the bool the method returned, or a UUID that names a record.
  final bool success;

  /// The id of the new record, when the method returns one.
  final String? uuid;

  /// The Health Connect client record id written with the data, if any (Android).
  final String? clientRecordId;

  /// Whether the write was deliberately thrown away, as `discardWorkoutRoute` does: nothing was saved,
  /// and that is not a failure.
  final bool discarded;

  /// When the write finished.
  final DateTime at;

  @override
  String toString() => 'WriteOutcome($method, $description, success: $success, uuid: $uuid)';
}
