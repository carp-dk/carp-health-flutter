/// The options a record write takes besides its value: how the data was recorded and, on Android, the
/// Health Connect client record id and version.
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'write_form_controller.dart';

/// Adds the `recordingMethod` argument to a write form's controller.
///
/// The recording method says how the data was recorded. HealthKit only knows whether the user entered a
/// sample by hand, so on iOS the plugin takes only `manual` or `automatic` (and throws an `ArgumentError`
/// for the others); Health Connect also has `active` and `unknown` ([recordingMethods]).
mixin RecordingMethodOption on WriteFormController {
  /// The platform, which decides the recording methods.
  PlatformCapabilities get capabilities;

  RecordingMethod _recordingMethod = RecordingMethod.manual;

  /// How the data was recorded: manual by default, as the user enters it in a form.
  RecordingMethod get recordingMethod => _recordingMethod;

  set recordingMethod(RecordingMethod method) => update(() => _recordingMethod = method);

  /// The recording methods the plugin takes on this platform.
  List<RecordingMethod> get recordingMethods => capabilities.isIOS
      ? const [RecordingMethod.manual, RecordingMethod.automatic]
      : const [RecordingMethod.manual, RecordingMethod.automatic, RecordingMethod.active, RecordingMethod.unknown];
}

/// Adds the `clientRecordId` and `clientRecordVersion` arguments to a write form's controller.
///
/// A client record id is the app's own id for a Health Connect record: writing a record again with the
/// same id and a higher version replaces it instead of adding a copy, and `deleteByClientRecordId`
/// deletes it. HealthKit has no such id and iOS ignores both arguments, so [clientRecordIdValue] is null
/// there.
mixin ClientRecordIdOption on WriteFormController {
  /// The platform, which decides whether client record ids apply.
  PlatformCapabilities get capabilities;

  /// The client record id the user typed; empty for none.
  final TextEditingController clientRecordId = TextEditingController();

  /// The version that goes with [clientRecordId].
  final TextEditingController clientRecordVersion = TextEditingController(text: '1');

  /// Whether the platform stores client record ids: only Health Connect does.
  bool get supportsClientRecordId => capabilities.isAndroid;

  /// The client record id to send, or null when there is none or the platform ignores it.
  String? get clientRecordIdValue {
    final id = clientRecordId.text.trim();
    return supportsClientRecordId && id.isNotEmpty ? id : null;
  }

  /// The version to send with [clientRecordIdValue] (1 when the field holds no number), or null without
  /// an id.
  double? get clientRecordVersionValue =>
      clientRecordIdValue == null ? null : (NumberField.parse(clientRecordVersion.text)?.toDouble() ?? 1);

  @override
  void dispose() {
    clientRecordId.dispose();
    clientRecordVersion.dispose();
    super.dispose();
  }
}
