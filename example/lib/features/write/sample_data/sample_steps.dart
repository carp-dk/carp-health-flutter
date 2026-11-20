/// The writes the sample data is made of, ported from the old example's `addData` (and its pool swim,
/// skin temperature and single-record writes): each builds one [SampleStep] around one plugin call.
library;

import 'package:health/health.dart';
import 'package:health_example/core/format/value_formatter.dart';
import 'package:health_example/core/health/health_type_info.dart';

import '../forms/common/write_outcome.dart';
import '../forms/meal/meal_nutrients.dart';
import 'sample_step.dart';

/// Builds the sample steps for [platform], timed around [now]: most of them cover the 20 minutes up
/// to [now] ([earlier] to [now]), as the old example's did.
class SampleSteps {
  /// Creates the steps' builder.
  SampleSteps({required this.platform, required this.now}) : earlier = now.subtract(span);

  /// How long the interval writes last.
  static const Duration span = Duration(minutes: 20);

  /// The Health Connect client record id of the steps that write with one. Writing the same record
  /// again with the same id and version adds no copy; `deleteByClientRecordId` deletes it.
  static const String clientRecordId = 'health-example-sample';

  /// The platform the values are written for: HealthKit's percentages are fractions.
  final HealthPlatformType platform;

  /// The end of the writes.
  final DateTime now;

  /// The start of the interval writes: [span] before [now].
  final DateTime earlier;

  /// Whether the steps are for iOS.
  bool get isIOS => platform == HealthPlatformType.appleHealth;

  /// [value] of [type] with `writeHealthData` (or `writeHealthDataUUID` when [uuid]), over the last
  /// 20 minutes or, when [instant], at [now].
  SampleStep measurement(
    HealthDataType type,
    double value, {
    String? title,
    bool instant = false,
    bool uuid = false,
    RecordingMethod recordingMethod = RecordingMethod.automatic,
    String? clientRecordId,
  }) {
    final description = formatNumericValue(value, type.defaultUnit, type: type, platform: platform);
    final method = uuid ? 'writeHealthDataUUID' : 'writeHealthData';
    final start = instant ? now : earlier;
    // A client record id needs its version, which a rewrite raises to replace the record.
    final version = clientRecordId == null ? null : 1.0;
    return SampleStep(
      title: title ?? type.label,
      method: method,
      type: type,
      description: description,
      clientRecordId: clientRecordId,
      write: (health) async {
        if (uuid) {
          final id = await health.writeHealthDataUUID(
            value: value,
            type: type,
            startTime: start,
            endTime: now,
            recordingMethod: recordingMethod,
            clientRecordId: clientRecordId,
            clientRecordVersion: version,
          );
          return WriteOutcome.fromUuid(method, type, description, id, clientRecordId: clientRecordId);
        }
        final saved = await health.writeHealthData(
          value: value,
          type: type,
          startTime: start,
          endTime: now,
          recordingMethod: recordingMethod,
          clientRecordId: clientRecordId,
          clientRecordVersion: version,
        );
        return WriteOutcome.fromBool(method, type, description, saved, clientRecordId: clientRecordId);
      },
    );
  }

  /// A short night with four 5-minute stages, in one `writeSleepSession` call. (Each sleep value written
  /// with `writeHealthData` would be a session of its own on Android.)
  SampleStep sleepSession() {
    SleepSessionStage stage(HealthDataType type, int minute) => SleepSessionStage(
      type: type,
      startTime: earlier.add(Duration(minutes: minute)),
      endTime: earlier.add(Duration(minutes: minute + 5)),
    );
    return boolStep(
      'Sleep session',
      'writeSleepSession',
      HealthDataType.SLEEP_ASLEEP,
      'Light, deep, REM and awake',
      (health) => health.writeSleepSession(
        startTime: earlier,
        endTime: now,
        stages: [
          stage(HealthDataType.SLEEP_LIGHT, 0),
          stage(HealthDataType.SLEEP_DEEP, 5),
          stage(HealthDataType.SLEEP_REM, 10),
          stage(HealthDataType.SLEEP_AWAKE, 15),
        ],
        title: 'Sample night',
      ),
    );
  }

  /// Moderate activity over the last 20 minutes (Health Connect, with its activity intensity feature).
  SampleStep activityIntensity() => boolStep(
    'Activity intensity',
    'writeActivityIntensity',
    HealthDataType.ACTIVITY_INTENSITY,
    'Moderate',
    (health) => health.writeActivityIntensity(
      intensityLevel: ActivityIntensityLevel.moderate,
      startTime: earlier,
      endTime: now,
      recordingMethod: RecordingMethod.manual,
    ),
  );

  /// A 98 % oxygen saturation: HealthKit's percent unit is a fraction, so iOS gets 0.98.
  SampleStep bloodOxygen() => boolStep(
    'Blood oxygen',
    'writeBloodOxygen',
    HealthDataType.BLOOD_OXYGEN,
    '98%',
    (health) => health.writeBloodOxygen(saturation: isIOS ? 0.98 : 98, startTime: earlier, endTime: now),
  );

  /// A blood pressure reading at [now], with the sample's client record id (Android).
  SampleStep bloodPressure() => boolStep(
    'Blood pressure',
    'writeBloodPressure',
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    '120/80 mmHg',
    (health) => health.writeBloodPressure(
      systolic: 120,
      diastolic: 80,
      startTime: now,
      clientRecordId: clientRecordId,
      clientRecordVersion: 1,
    ),
    requires: const [HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
    clientRecordId: clientRecordId,
  );

  /// A banana snack with its micronutrients, with the sample's client record id (Android).
  SampleStep meal() => boolStep(
    'Meal',
    'writeMeal',
    HealthDataType.NUTRITION,
    'Banana · 105 kcal · ${MealMicronutrients.banana.entries.length} micronutrients',
    (health) => writeMealWithNutrients(
      health,
      mealType: MealType.SNACK,
      startTime: earlier,
      endTime: now,
      name: 'Banana',
      calories: 105,
      carbohydrates: 27,
      protein: 1.3,
      fat: 0.4,
      micronutrients: MealMicronutrients.banana,
      clientRecordId: clientRecordId,
      clientRecordVersion: 1,
      recordingMethod: RecordingMethod.manual,
    ),
    clientRecordId: clientRecordId,
  );

  /// A medium flow that starts a cycle.
  SampleStep menstruationFlow() => boolStep(
    'Menstruation flow',
    'writeMenstruationFlow',
    HealthDataType.MENSTRUATION_FLOW,
    'Medium · cycle start',
    (health) => health.writeMenstruationFlow(
      flow: MenstrualFlow.medium,
      isStartOfCycle: true,
      startTime: earlier,
      endTime: now,
    ),
  );

  /// A sexual activity entry with protection used.
  SampleStep sexualActivity() => boolStep(
    'Sexual activity',
    'writeSexualActivity',
    HealthDataType.SEXUAL_ACTIVITY,
    'Protected',
    (health) => health.writeSexualActivity(
      protectionUsed: SexualActivityProtection.protected,
      startTime: now,
      recordingMethod: RecordingMethod.manual,
    ),
  );

  /// A 5 IU bolus (iOS: Health Connect has no insulin type).
  SampleStep insulinDelivery() => boolStep(
    'Insulin delivery',
    'writeInsulinDelivery',
    HealthDataType.INSULIN_DELIVERY,
    '5 IU · bolus',
    (health) => health.writeInsulinDelivery(5, InsulinDeliveryReason.BOLUS, earlier, now),
  );

  /// A breathing session; Health Connect keeps its type and title, HealthKit does not.
  SampleStep mindfulness() => boolStep(
    'Mindfulness session',
    'writeMindfulnessSession',
    HealthDataType.MINDFULNESS,
    'Breathing · 20 min',
    (health) => health.writeMindfulnessSession(
      startTime: earlier,
      endTime: now,
      sessionType: MindfulnessSessionType.BREATHING,
      title: 'Morning practice',
      recordingMethod: RecordingMethod.automatic,
    ),
  );

  /// A step whose [call] returns whether it saved the data, for the step builders here and in
  /// `SampleWorkoutSteps`.
  SampleStep boolStep(
    String title,
    String method,
    HealthDataType type,
    String description,
    Future<bool> Function(Health health) call, {
    List<HealthDataType>? requires,
    List<HealthDataType> extraAccess = const [],
    String? clientRecordId,
  }) => SampleStep(
    title: title,
    method: method,
    type: type,
    description: description,
    requiredTypes: requires,
    extraAccess: extraAccess,
    clientRecordId: clientRecordId,
    write: (health) async =>
        WriteOutcome.fromBool(method, type, description, await call(health), clientRecordId: clientRecordId),
  );
}
