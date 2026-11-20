/// The Write page's sample data: the old example's set of sample writes as a plan of single steps,
/// each one plugin call, so that the app can run them one by one and show what each returned.
library;

import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';

import 'sample_step.dart';
import 'sample_steps.dart';
import 'sample_workout_steps.dart';

/// The steps of the sample data, in the order they run: measurements with `writeHealthData` first,
/// then every typed write method (sleep session, activity intensity, blood oxygen, workouts with a
/// pool swim, blood pressure, meal, menstruation flow, insulin, mindfulness) and last the single
/// records written with the `...UUID` methods.
///
/// The plan holds the steps of both platforms: a step whose types this device does not have
/// ([SampleStep.skipReason]) is shown as skipped instead of failing, so the list explains the
/// platform differences.
abstract final class SampleDataPlan {
  /// The steps for [platform], timed up to [now].
  static List<SampleStep> build({required HealthPlatformType platform, required DateTime now}) {
    final steps = SampleSteps(platform: platform, now: now);
    final m = steps.measurement;
    return List.unmodifiable(<SampleStep>[
      m(HealthDataType.HEIGHT, 1.925, recordingMethod: RecordingMethod.manual),
      m(HealthDataType.WEIGHT, 90, instant: true, recordingMethod: RecordingMethod.manual),
      m(HealthDataType.VO2_MAX, 42.5, instant: true, recordingMethod: RecordingMethod.manual),
      // Two heart rates, one entered by hand: Read's recording method filter can leave that one out.
      m(HealthDataType.HEART_RATE, 90, title: 'Heart rate (manual)', recordingMethod: RecordingMethod.manual),
      m(HealthDataType.HEART_RATE, 70, title: 'Heart rate (automatic)'),
      m(HealthDataType.STEPS, 90, recordingMethod: RecordingMethod.manual),
      m(HealthDataType.ACTIVE_ENERGY_BURNED, 200, clientRecordId: SampleSteps.clientRecordId),
      m(HealthDataType.BODY_TEMPERATURE, 37),
      m(HealthDataType.BLOOD_GLUCOSE, 105),
      m(HealthDataType.WATER, 1.8),
      m(HealthDataType.LEAN_BODY_MASS, 22),
      // The platforms differ: HealthKit has heart rate variability as SDNN and walking speed, Health
      // Connect as RMSSD and a general speed.
      m(HealthDataType.HEART_RATE_VARIABILITY_SDNN, 30),
      m(HealthDataType.WALKING_SPEED, 1.5, recordingMethod: RecordingMethod.manual),
      m(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, 30),
      m(HealthDataType.SPEED, 2, recordingMethod: RecordingMethod.manual),
      // HealthKit added these in iOS 16; PlatformCapabilities skips them on older versions.
      m(HealthDataType.WATER_TEMPERATURE, 22, recordingMethod: RecordingMethod.manual),
      m(HealthDataType.UNDERWATER_DEPTH, 5, recordingMethod: RecordingMethod.manual),
      m(HealthDataType.UV_INDEX, 4.3, recordingMethod: RecordingMethod.manual),
      // A Health Connect feature: only where isSkinTemperatureAvailable is true. The value is the baseline.
      m(HealthDataType.SKIN_TEMPERATURE, 33.6, recordingMethod: RecordingMethod.manual),
      steps.sleepSession(),
      steps.activityIntensity(),
      steps.bloodOxygen(),
      steps.workout(),
      steps.poolSwim(),
      steps.bloodPressure(),
      steps.meal(),
      steps.menstruationFlow(),
      steps.sexualActivity(),
      steps.insulinDelivery(),
      steps.mindfulness(),
      // Single records whose UUIDs come back: View and Delete in the recent writes use them.
      m(
        HealthDataType.STEPS,
        2130,
        title: 'Steps (single record)',
        uuid: true,
        recordingMethod: RecordingMethod.manual,
      ),
      steps.runWithUuid(),
    ]);
  }

  /// The steps of [steps] that the device [capabilities] describes runs.
  static List<SampleStep> runnable(List<SampleStep> steps, PlatformCapabilities capabilities) =>
      steps.where((step) => step.skipReason(capabilities) == null).toList();

  /// The types whose write access the runnable [steps] need, each once, in plan order: the types to
  /// request with `requestAuthorization` before writing the sample data.
  static List<HealthDataType> accessTypes(List<SampleStep> steps, PlatformCapabilities capabilities) =>
      {for (final step in runnable(steps, capabilities)) ...step.accessTypes(capabilities)}.toList();
}
