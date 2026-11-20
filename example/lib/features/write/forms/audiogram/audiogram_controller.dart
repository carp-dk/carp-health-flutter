/// The state of the Audiogram form and its plugin call, `Health.writeAudiogram` (iOS).
library;

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/features/write/forms/common/write_outcome.dart';
import 'package:health_example/features/write/forms/form_kit/time_span_option.dart';
import 'package:health_example/features/write/forms/form_kit/write_availability.dart';

import 'audiogram_points.dart';

/// A hearing test to write: the threshold of each ear at each tested frequency, when the test took place,
/// and the HealthKit metadata of the device that ran it.
///
/// `writeAudiogram` saves a HealthKit audiogram sample. HealthKit takes at most 30 frequencies, unique and
/// in ascending order, from 0 to 30,000 Hz, with thresholds from -20 to 160 dB HL; the plugin checks this
/// first and throws a `PlatformException` with code `INVALID_ARGUMENT` otherwise. The edits of
/// [AudiogramPlan] keep the audiogram within these limits. Health Connect has no hearing tests: on
/// Android the plugin throws an `UnsupportedError`, so the form offers the write on iOS only.
class AudiogramController extends WriteFormController with TimeSpanOption, WriteAvailability {
  /// Creates the form's state: the age-related sample audiogram, tested now (or at [now]), written through
  /// [health] on the platform [capabilities] describe.
  AudiogramController(super.health, {required this.capabilities, DateTime? now})
    : _points = AudiogramPreset.sloping.points {
    initSpan(Duration.zero, end: now);
  }

  @override
  final PlatformCapabilities capabilities;

  List<AudiogramPoint> _points;
  AudiogramPreset? _preset = AudiogramPreset.sloping;

  /// The device the test ran on (`metadata['HKDeviceName']`); empty for none.
  final TextEditingController deviceName = TextEditingController(text: 'Health example');

  /// The test's id in the app that ran it (`metadata['HKExternalUUID']`); empty for none.
  final TextEditingController externalUuid = TextEditingController();

  /// The tested frequencies and their thresholds, in ascending frequency.
  List<AudiogramPoint> get points => _points;

  /// The sample audiogram the points are, or null once they were edited.
  AudiogramPreset? get preset => _preset;

  /// Whether [frequency] is tested.
  bool tests(double frequency) => _points.any((point) => point.frequency == frequency);

  /// Replaces the points with those of [preset].
  void applyPreset(AudiogramPreset preset) => update(() {
    _points = preset.points;
    _preset = preset;
  });

  /// Tests [frequency] when it is not tested, and stops testing it when it is ([AudiogramPlan.toggle]).
  void toggleFrequency(double frequency) => _edit(AudiogramPlan.toggle(_points, frequency));

  /// Sets the threshold of [ear] at [frequency] to [value] ([AudiogramPlan.setThreshold]).
  void setThreshold(double frequency, Ear ear, double value) =>
      _edit(AudiogramPlan.setThreshold(_points, frequency, ear, value));

  @override
  HealthDataType get type => HealthDataType.AUDIOGRAM;

  @override
  String? get unavailableReason => capabilities.isIOS ? null : 'iOS only: Health Connect has no hearing tests.';

  @override
  String get description => _points.isEmpty
      ? 'No frequencies'
      : '${_points.length} frequencies, ${frequencyLabel(_points.first.frequency)} to '
            '${frequencyLabel(_points.last.frequency)}';

  /// The `metadata` argument: the device name and external UUID that are set, or null for neither.
  Map<String, dynamic>? get metadata {
    final values = {'HKDeviceName': deviceName.text.trim(), 'HKExternalUUID': externalUuid.text.trim()}
      ..removeWhere((_, value) => value.isEmpty);
    return values.isEmpty ? null : values;
  }

  @override
  Future<WriteOutcome> performWrite() async {
    checkAvailable();
    final saved = await health.writeAudiogram(
      frequencies: [for (final point in _points) point.frequency],
      leftEarSensitivities: [for (final point in _points) point.left],
      rightEarSensitivities: [for (final point in _points) point.right],
      startTime: start,
      endTime: end,
      metadata: metadata,
    );
    return WriteOutcome.fromBool('writeAudiogram', type, description, saved);
  }

  @override
  void dispose() {
    deviceName.dispose();
    externalUuid.dispose();
    super.dispose();
  }

  void _edit(List<AudiogramPoint> points) => update(() {
    _points = List.unmodifiable(points);
    _preset = null;
  });
}
