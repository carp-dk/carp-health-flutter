part of '../../health.dart';

enum RecordingMethod {
  unknown,
  active,
  automatic,
  manual;

  /// Create a [RecordingMethod] from an integer.
  /// 0: unknown, 1: active, 2: automatic, 3: manual
  /// If the integer is not in the range of 0-3, [RecordingMethod.unknown] is returned.
  /// This is used to align the recording method with the platform.
  static RecordingMethod fromInt(int? recordingMethod) {
    switch (recordingMethod) {
      case 0:
        return RecordingMethod.unknown;
      case 1:
        return RecordingMethod.active;
      case 2:
        return RecordingMethod.automatic;
      case 3:
        return RecordingMethod.manual;
      default:
        return RecordingMethod.unknown;
    }
  }

  /// Convert this [RecordingMethod] to an integer.
  int toInt() {
    switch (this) {
      case RecordingMethod.unknown:
        return 0;
      case RecordingMethod.active:
        return 1;
      case RecordingMethod.automatic:
        return 2;
      case RecordingMethod.manual:
        return 3;
    }
  }
}
