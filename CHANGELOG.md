## 14.0.0

* **BREAKING** changes, and what to do about each:
  * Android build: the plugin uses `androidx.health.connect:connect-client` 1.2.0-alpha06 (was 1.2.0-alpha02), which requires apps to compile against API 37 with Android Gradle Plugin (AGP) 9.1.0 or later. Set `compileSdk = 37` in `android/app/build.gradle(.kts)` (Flutter 3.47's default `flutter.compileSdkVersion` is 36), AGP (`com.android.application` in `android/settings.gradle(.kts)`) to 9.1.0 or later, and Gradle (`android/gradle/wrapper/gradle-wrapper.properties`) to 9.3.1 or later, which AGP 9.1 requires. The example app shows a working setup. The plugin needs Flutter 3.44 or later and Dart 3.12 or later, and no longer applies the Kotlin Gradle plugin: it uses AGP's built-in Kotlin, and in apps that set `android.builtInKotlin=false` Flutter applies the Kotlin Gradle plugin to it - PR [#491](https://github.com/carp-dk/carp-health-flutter/pull/491) by @giaquo.
  * On Android, reads throw when Health Connect reports an error, as they already did on iOS, instead of returning no data: `getHealthDataFromTypes` and `getHealthIntervalDataFromTypes` returned an empty list, and `getHealthDataByUUID` returned `null`, which now means that no record has that UUID or that the record has no data of the requested type (for example a sleep session without the requested stage). Catch the `HealthPlatformException` (see "New features"), for example with `HealthErrorCode.rateLimitExceeded` when the app has used up its Health Connect API quota. In `getHealthDataFromTypes` and `getHealthDataPages`, a missing read permission is still not an error: that type returns no data. On Android, `getHealthIntervalDataFromTypes` throws a `HealthPlatformException` with `HealthErrorCode.permissionDenied` without the read permission (it returned an empty list). `getHealthDataByUUID` without the read permission returns the app's own records, which Health Connect lets an app read, and `null` for those of other apps.
  * iOS read errors that HealthKit classifies have the codes `PERMISSION_DENIED`, `DEVICE_LOCKED`, `NOT_SUPPORTED`, `INVALID_ARGUMENT` or `DATA_TOO_LARGE` instead of a generic code such as `HEALTH_ERROR`. `getHealthDataFromTypes`, `getHealthIntervalDataFromTypes` and `getHealthDataByUUID` fail with `NOT_SUPPORTED` instead of `INVALID_TYPE` for a type that is not available on this iOS version (for example `UNDERWATER_DEPTH` or `WATER_TEMPERATURE` on iOS 15), and an error that HealthKit does not classify while reading workout route locations has the code `HEALTH_ERROR` instead of `ROUTE_ERROR`. Other errors keep their code. Check `HealthException.errorCode` rather than `PlatformException.code`.
  * `getTotalStepsInInterval` returns `Future<int>` instead of `Future<int?>`: 0 when there are no steps. When Health Connect or HealthKit reports an error it throws a `HealthPlatformException` (Android returned `null`), on Android also without the steps read permission (`HealthErrorCode.permissionDenied`; HealthKit returns 0), and it throws an `UnsupportedError` if Health Connect is not available. Replace `null` checks with error handling - Fix [#237](https://github.com/carp-dk/carp-health-flutter/issues/237) and Fix [#282](https://github.com/carp-dk/carp-health-flutter/issues/282).
  * `getChangesToken` and `getChanges` throw a `HealthPlatformException` when Health Connect reports an error, instead of returning `null`; they return `null` only on iOS. Catch the exception where you checked for `null`. For a retryable error (`isRetryable`, for example `HealthErrorCode.rateLimitExceeded`), call `getChanges` again later with the same token. `getChanges` reads a page of changes that holds more than 100,000 data points again with fewer changes, and returns `changesTokenExpired: true` when it cannot get the page that small (for example one change of that size) or Health Connect cannot return the pending changes ("Too many records in the cursor"). As for any expired token, read the data since your last sync and create a new token.
  * `AudiogramHealthValue.leftEarSensitivities` and `rightEarSensitivities` are `List<num?>` (were `List<num>`): `null` where that ear was not tested at the frequency. Handle `null` entries. On iOS, reading such an audiogram crashed the app.
  * `getHealthIntervalDataFromTypes` (read each value as `(point.value as NumericHealthValue).numericValue`, and do not expect a point for every interval):
    * Intervals without data are left out on both platforms.
    * Every point's value is a `NumericHealthValue`, also for `SKIN_TEMPERATURE` and `ACTIVITY_INTENSITY`, holding what the platform computed: the sum for cumulative types, Health Connect's intensity minutes for `ACTIVITY_INTENSITY`, and the average for other types. For `HEART_RATE` that is the average beats per minute on both platforms (Android counted the samples).
    * For sleep types, the value is the minutes of the interval that the type's data covers, overlapping data counted once; sleep that began before `startDate` counts with its part after it. iOS failed with `INVALID_TYPE` for sleep types.
  * The `HealthDataPoint` constructor, and so `HealthDataPoint.fromJson`, keeps the value it is given for the sleep, headache and mindfulness types instead of replacing it with the minutes from `dateFrom` to `dateTo`; `HealthDataPoint.fromHealthDataPoint` still sets those minutes for data from the platform. If you create such points yourself, pass the minutes as their value.
  * Workout types are read under one name on each platform. Update code that compares workout type names:
    * iOS read a HealthKit workout type that several `HealthWorkoutActivityType`s write under one of their names, picked at random on each app launch. Such workouts now read as `RUNNING`, `CLIMBING` or `SWIMMING`, as `SWIMMING_POOL` or `SWIMMING_OPEN_WATER` when their swimming location says so, and as `RUNNING_TREADMILL` when they are indoor runs. Workouts written as `RUNNING_TREADMILL` are saved as indoor runs (unless `WorkoutMetadata.indoorWorkout` says otherwise), and those written as `SWIMMING_OPEN_WATER` with an open water location, so both read back under the name they were written with; `ROCK_CLIMBING` reads back as `CLIMBING`, and `SWIMMING_POOL` as `SWIMMING` unless it is written with a pool length (`SwimmingDetails.poolLength`, see "New features"), as HealthKit needs a lap length for a pool swim. `writeWorkoutData` and `writeWorkoutDataUUID` accept `RUNNING_TREADMILL` and `ROCK_CLIMBING` on iOS (they threw a `HealthException`) - Fix [#473](https://github.com/carp-dk/carp-health-flutter/issues/473).
    * On iOS, `WorkoutSummary.workoutType` of every workout is now the name of its `HealthWorkoutActivityType` (as in `WorkoutHealthValue.workoutActivityType`) instead of HealthKit's name for the type: for example `BIKING` instead of `cycling`, and `OTHER` for a HealthKit type the plugin has no name for.
    * Android read the Health Connect exercise types that several workout types write under different names in different reads. Workouts, workout routes, changes and reads by UUID now all report `DANCING` (also written as `CARDIO_DANCE` or `SOCIAL_DANCE`), `SKIING` (`CROSS_COUNTRY_SKIING`, `DOWNHILL_SKIING`) and `WHEELCHAIR` (`WHEELCHAIR_RUN_PACE`, `WHEELCHAIR_WALK_PACE`).
  * On Android, `writeWorkoutData` and `writeWorkoutDataUUID` throw a `HealthException` with `HealthErrorCode.notSupported` for `ARCHERY`, `CURLING` and `WALKING_TREADMILL`, which Health Connect has no exercise type for, instead of returning `false` and an empty string without writing anything. They throw it before anything is written for every workout type that a platform does not have, such as `BIKING_STATIONARY` on iOS, and `WALKING_TREADMILL` is written on neither platform. Leave these types out on Android, or catch the exception - PR [#530](https://github.com/carp-dk/carp-health-flutter/pull/530) by @louisdeveseleer.
  * On Android, the `totalDistance`, `totalEnergyBurned` and `totalSteps` of a workout count only the records of the app that wrote the workout, as on iOS, where a workout's totals are its own: they added up the records of every app in the workout's time, so an activity that two apps recorded (for example a watch app and the phone) counted twice. A total that the workout's app did not write is `null`, for example the steps of a workout written with `writeWorkoutData`. To count the data of other apps too, read `DISTANCE_DELTA`, `TOTAL_CALORIES_BURNED` or `STEPS` over the workout's time - Fix [#39](https://github.com/carp-dk/carp-health-flutter/issues/39) and Fix [#524](https://github.com/carp-dk/carp-health-flutter/issues/524) - PR [#525](https://github.com/carp-dk/carp-health-flutter/pull/525) by @louisdeveseleer.
  * `getHealthAggregateDataFromTypes` is deprecated and throws an `UnsupportedError` without calling the platform: it has not worked on either platform since Google Fit was removed. Use `getHealthIntervalDataFromTypes`.
  * `writeHealthData` and `writeHealthDataUUID` throw an `ArgumentError` for types that have a write method of their own: on iOS `INSULIN_DELIVERY` (use `writeInsulinDelivery`) and `MENSTRUATION_FLOW` (use `writeMenstruationFlow`), which crashed the app because HealthKit requires metadata that only those methods set, and `ACTIVITY_INTENSITY` (use `writeActivityIntensity`) now also in `writeHealthDataUUID`.
  * HealthKit lets apps only read `APPLE_STAND_HOUR`, `APPLE_MOVE_TIME`, `APPLE_STAND_TIME`, `EXERCISE_TIME` and `SLEEP_WRIST_TEMPERATURE`, and `requestAuthorization` with `WRITE` or `READ_WRITE` access to them crashed the app: it throws an `ArgumentError`, as it does for the other types that HealthKit lets apps only read (`ELECTROCARDIOGRAM`, the heart rate events, `WALKING_HEART_RATE` and `ATRIAL_FIBRILLATION_BURDEN`). On iOS, `writeHealthData` and `writeHealthDataUUID` throw an `ArgumentError` for all of these types, as they did for `ELECTROCARDIOGRAM` and the heart rate events; for the others they returned `false` and an empty string, and `APPLE_STAND_HOUR` with a value it does not have, such as 5 or `NaN`, crashed the app. Ask only for `READ` access to these types, and do not write them.
  * `TOTAL_CALORIES_BURNED`, which HealthKit does not have, is no longer an iOS type: on iOS, `isDataTypeAvailable` returns `false` for it, and reads and writes of it throw a `HealthException` with `HealthErrorCode.notSupported` before anything is read or written (`writeHealthData` returned `false`, `writeHealthDataUUID` crashed the app, and reads failed when they reached it). `requestAuthorization` with only this type returns `false` (it crashed the app). On iOS, read `ACTIVE_ENERGY_BURNED` and `BASAL_ENERGY_BURNED` instead - Fix [#483](https://github.com/carp-dk/carp-health-flutter/issues/483) and Fix [#486](https://github.com/carp-dk/carp-health-flutter/issues/486) - PR [#484](https://github.com/carp-dk/carp-health-flutter/pull/484) by @mcaldas.
  * On Android, `writeHealthData` returns `false` and `writeHealthDataUUID` an empty string when Health Connect rejects the value, for example a `STEPS` count of 0, instead of throwing a `PlatformException`. Check the result. A record that needs a duration but ends when it starts still throws, now a `PlatformException` with code `INVALID_ARGUMENT` (it had the code `error`).
  * On iOS, `delete` with a sleep type or a headache severity deletes only the app's samples of that type; it deleted all of the app's sleep (or headache) samples in the range. Call `delete` for each type you want removed.
  * On Android, reads of the sleep stage types (`SLEEP_ASLEEP`, `SLEEP_AWAKE`, `SLEEP_AWAKE_IN_BED`, `SLEEP_LIGHT`, `SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_OUT_OF_BED`, `SLEEP_UNKNOWN`) in `getHealthDataFromTypes` and `getHealthDataPages` return the stages that start between `startTime` and `endTime`, whichever session they belong to, as on iOS. They returned every stage of the sessions that started in the range: a read from midnight returned no stage of a night that began before it, and a read of the evening returned stages after its end, so consecutive ranges lost or doubled stages. Stages of sessions that began up to 24 hours before `startTime` are found. To read a whole night, read up to its end. `SLEEP_SESSION` reads are unchanged.
  * On Android, a `preferredUnits` entry that Health Connect values are not converted to throws a `HealthException` with `HealthErrorCode.invalidArgument` before anything is read, instead of labelling the values with a unit they are not in. Android converts `WEIGHT` to `POUND`, `HEIGHT` to `CENTIMETER` and `INCH`, `BODY_TEMPERATURE` and `SKIN_TEMPERATURE` to `DEGREE_FAHRENHEIT` and `KELVIN`, and `BLOOD_GLUCOSE` to `MILLIMOLES_PER_LITER`; every other type comes in its default unit.
  * `HealthDataPoint.sourceDeviceId` of data read from the platform was always `unknown`; it is now this device's id: `identifierForVendor` on iOS and `Build.ID` on Android (from `device_info_plus`; a build id, which devices with the same build share). `HealthDataPoint.deviceModel` was always `null`; it is now the model of the device that recorded the data, when the app that wrote it reported one (see "Fixes on both platforms"). As both are part of `HealthDataPoint ==`, points read with this version are not equal to the same points stored by 13.x. To match new reads against points stored by 13.x, compare the fields that `==` compares except `sourceDeviceId` and `deviceModel`, instead of using `==` or `removeDuplicates`. `HealthDataPoint.fromHealthDataPoint`, `HealthChange.fromMethodChannel` and `HealthChangesResponse.fromMethodChannel` take an optional `sourceDeviceId`.
  * Classes that implement `Health` or `HealthException` (for example hand-written test fakes) must add the new members.
* New features:
  * Large amounts of data are read page by page and off the UI thread:
    * Both platforms read in pages, so each platform call returns a bounded amount of data: large reads crashed Android apps with an `OutOfMemoryError`. Health Connect returns at most 5000 records per call. A type listed twice in `types` is read once. `getHealthDataFromTypes` still returns all points in one list; use `getHealthDataPages` to keep memory bounded.
    * `getHealthDataPages()` returns a `Stream<HealthDataPage>` for large time ranges. It is lazy and reads the next page only when the listener is ready for it; cancelling the subscription stops the read. Each type ends with one page whose `isLastPageForType` is true, and on Android `readPermissionDenied` marks a type that was skipped for lack of read permission.
    * Health Connect records are converted, and HealthKit replies are sent, off the UI thread - PR [#531](https://github.com/carp-dk/carp-health-flutter/pull/531) by @Zeroupper.
    * Large replies are decoded and parsed in a worker isolate, so the UI keeps running: see `Health.isolateMode` (`HealthIsolateMode.auto` (default), `worker` and `inline`).
    * `Health.pageSize` sets the data points per platform call (default 20000, at most 50000): bigger pages mean fewer Health Connect calls, which count against its API quota, and more memory per call. Both can also be passed to `Health()`.
  * `getHealthDataFromTypes` takes an optional `limit`: at most that many of the newest data points of each type, newest end time first, for example the latest height or weight, without reading every page of the range (`null` or 0 means no limit, and a negative `limit` throws an `ArgumentError`). Pages are read newest first until `limit` points are in, so records that give no point, such as sleep sessions without the stage asked for or workouts without a route, cost more platform calls. On Android, the pages go by the start time of Health Connect's records, `BODY_MASS_INDEX` is computed from the latest height and the newest `limit` weights, and a limited read does not look for sleep sessions and records of a series, such as heart rate, that began before `startTime` - Fix [#279](https://github.com/carp-dk/carp-health-flutter/issues/279) - PR [#517](https://github.com/carp-dk/carp-health-flutter/pull/517) by @fabianvf.
  * Error handling: `HealthException` has an `errorCode` (`HealthErrorCode`: `rateLimitExceeded`, `permissionDenied`, `invalidArgument`, `notSupported`, `unavailable`, `deviceLocked`, `dataTooLarge` or `unknown`), the `platformCode` and `details` that the platform reported, and `isRetryable`. Errors that Health Connect or HealthKit report to a read are thrown as a `HealthPlatformException`, which is both a `PlatformException`, so existing `on PlatformException` handlers keep working, and a `HealthException`.
  * Add `HealthDataType.POWER` (in the new unit `WATT`: on iOS cycling power, on Android the power of any exercise, such as cycling or rowing) and `HealthDataType.CYCLING_CADENCE` (in the new unit `REVOLUTION_PER_MINUTE`), read only: HealthKit `cyclingPower` and `cyclingCadence` on iOS 17 and later, Health Connect `PowerRecord` and `CyclingPedalingCadenceRecord` on Android (declare `READ_POWER`, and `READ_EXERCISE` for cadence, as Health Connect has no cadence permission), with interval averages on both. Writing them throws an `ArgumentError` - PR [#487](https://github.com/carp-dk/carp-health-flutter/pull/487) by @atomfritte-lead.
  * Add `HealthDataType.VO2_MAX` (in the new unit `MILLILITER_PER_KILOGRAM_PER_MINUTE`), read and written with `writeHealthData`: HealthKit `vo2Max` on iOS, Health Connect `Vo2MaxRecord` on Android (declare `READ_VO2_MAX` and `WRITE_VO2_MAX`; Health Connect takes values from 0 to 100, and `writeHealthData` returns `false` for others). `getHealthIntervalDataFromTypes` returns averages on iOS and no data points on Android, as Health Connect has no VO2 max aggregate - PR [#481](https://github.com/carp-dk/carp-health-flutter/pull/481) by @jukkraputp.
  * iOS: 41 more HealthKit quantity types, also in `getHealthIntervalDataFromTypes` (sums for cumulative types, averages for the others): `BASAL_BODY_TEMPERATURE`, `NUMBER_OF_TIMES_FALLEN` (falls that Apple Watch detects), `ENVIRONMENTAL_AUDIO_EXPOSURE`, `HEADPHONE_AUDIO_EXPOSURE`, `PEAK_EXPIRATORY_FLOW` (in the new unit `LITER_PER_MINUTE`), `FORCED_VITAL_CAPACITY`, `INHALER_USAGE`, `BLOOD_ALCOHOL_CONTENT`, `NUMBER_OF_ALCOHOLIC_BEVERAGES`, `PUSH_COUNT`, `DISTANCE_WHEELCHAIR`, `SWIMMING_STROKE_COUNT`, `DISTANCE_DOWNHILL_SNOW_SPORTS`, `WALKING_STEP_LENGTH`, `WALKING_DOUBLE_SUPPORT_PERCENTAGE`, `WALKING_ASYMMETRY_PERCENTAGE`, `APPLE_WALKING_STEADINESS`, `STAIR_ASCENT_SPEED`, `STAIR_DESCENT_SPEED` and `SIX_MINUTE_WALK_TEST_DISTANCE`; on iOS 16 and later `RUNNING_POWER`, `RUNNING_SPEED`, `RUNNING_STRIDE_LENGTH`, `RUNNING_VERTICAL_OSCILLATION`, `RUNNING_GROUND_CONTACT_TIME`, `HEART_RATE_RECOVERY_ONE_MINUTE` and `ENVIRONMENTAL_SOUND_REDUCTION`; on iOS 17 and later `TIME_IN_DAYLIGHT`, `PHYSICAL_EFFORT` (in the new unit `KILOCALORIE_PER_HOUR_KILOGRAM`), `CYCLING_SPEED` and `CYCLING_FUNCTIONAL_THRESHOLD_POWER`; on iOS 18 and later `DISTANCE_CROSS_COUNTRY_SKIING`, `DISTANCE_PADDLE_SPORTS`, `DISTANCE_ROWING`, `DISTANCE_SKATING_SPORTS`, `CROSS_COUNTRY_SKIING_SPEED`, `PADDLE_SPORTS_SPEED`, `ROWING_SPEED`, `WORKOUT_EFFORT_SCORE` and `ESTIMATED_WORKOUT_EFFORT_SCORE` (both in the new unit `APPLE_EFFORT_SCORE`), and `APPLE_SLEEPING_BREATHING_DISTURBANCES`. On an older iOS version, reads of a type throw a `HealthPlatformException` with `HealthErrorCode.notSupported`. `WALKING_ASYMMETRY_PERCENTAGE`, `APPLE_WALKING_STEADINESS` and `APPLE_SLEEPING_BREATHING_DISTURBANCES` are read only: requesting write access to them, or writing them, throws an `ArgumentError`, where HealthKit would crash the app. `writeHealthData` and `writeHealthDataUUID` throw a `PlatformException` with code `INVALID_ARGUMENT`, before anything is saved, for a `WORKOUT_EFFORT_SCORE` or `ESTIMATED_WORKOUT_EFFORT_SCORE` outside 0 to 10, and for an `ENVIRONMENTAL_AUDIO_EXPOSURE` or `HEADPHONE_AUDIO_EXPOSURE` sample whose `endTime` is not after its `startTime` (also when it is not given), where HealthKit would crash the app - Fix [#8](https://github.com/carp-dk/carp-health-flutter/issues/8), Fix [#92](https://github.com/carp-dk/carp-health-flutter/issues/92) and Fix [#95](https://github.com/carp-dk/carp-health-flutter/issues/95) - PR [#522](https://github.com/carp-dk/carp-health-flutter/pull/522) by @zkrige.
  * Android: `writeHealthData` and `writeHealthDataUUID` write `MINDFULNESS` to Health Connect as a `MindfulnessSessionRecord` of type unknown, without a title or notes (declare `WRITE_MINDFULNESS`); they threw a `HealthException`, as the type was iOS only. As for the other types with a duration, a session that ends when it starts throws a `PlatformException` with code `INVALID_ARGUMENT` - PR [#460](https://github.com/carp-dk/carp-health-flutter/pull/460) by @lekanbar.
  * Android: `MINDFULNESS` is read from Health Connect (declare `READ_MINDFULNESS`) in `getHealthDataFromTypes`, `getHealthDataPages`, `getHealthDataByUUID` and the changes API, with the session's minutes as its value, as on iOS, and in `getHealthIntervalDataFromTypes` as the minutes of the sessions in each interval. `writeMindfulnessSession()` writes a session with a `MindfulnessSessionType` (`UNKNOWN` by default, `MEDITATION`, `BREATHING`, `MUSIC`, `MOVEMENT` or `UNGUIDED`), a title and notes, which iOS does not store and reads do not return. `isMindfulnessSessionAvailable()` tells whether the device's Health Connect has mindfulness sessions (always `true` on iOS); where it does not, reads, changes tokens and writes of `MINDFULNESS` throw a `HealthException` with `HealthErrorCode.notSupported` before anything is read or written, as for `SKIN_TEMPERATURE`, so leave the type out of reads of several types on such a device - PR [#510](https://github.com/carp-dk/carp-health-flutter/pull/510) by @ikhrustalev.
  * iOS: `getRequestStatusForAuthorization()`, HealthKit's `getRequestStatusForAuthorization(toShare:read:)`, says whether `requestAuthorization` with the same types and permissions would show the authorization sheet (`HealthAuthorizationRequestStatus.shouldRequest`) or not (`unnecessary`), so apps can tell a first request from one the user has already answered. It does not say whether read access was granted, which HealthKit does not disclose. Like `requestAuthorization`, it throws an `ArgumentError` for write access to a type that HealthKit lets apps only read. It throws a `PlatformException` when HealthKit cannot determine the status, and returns `null` on Android - Fix [#397](https://github.com/carp-dk/carp-health-flutter/issues/397) - PR [#499](https://github.com/carp-dk/carp-health-flutter/pull/499) by @touyou.
  * iOS: `writeWorkoutData` and `writeWorkoutDataUUID` take an optional `WorkoutMetadata` (brand name, indoor, group fitness, coached workout; HealthKit lets only Apple's apps set the Apple Fitness+ session key, so the PR's field for it is left out), saved as HealthKit workout metadata; Android ignores it - Fix [#74](https://github.com/carp-dk/carp-health-flutter/issues/74) - PR [#452](https://github.com/carp-dk/carp-health-flutter/pull/452) by @kvenn.
  * `writeWorkoutData` and `writeWorkoutDataUUID` can write a workout again without adding a copy: on Android they take `clientRecordId` and `clientRecordVersion`, as `writeHealthData` does (the workout's distance and energy records get the ids `<clientRecordId>:distance` and `<clientRecordId>:calories`), and on iOS `WorkoutMetadata` takes `syncIdentifier` and `syncVersion` (HealthKit's `HKMetadataKeySyncIdentifier` and `HKMetadataKeySyncVersion`). A workout with the id of one that the app wrote before replaces it if its version is greater; an id without its version, or a version without its id, throws an `ArgumentError`. On Android, `startZoneOffset` and `endZoneOffset` set the zone offsets of the workout's records (an `ArgumentError` for more than 18 hours); iOS ignores them - PR [#485](https://github.com/carp-dk/carp-health-flutter/pull/485) by @magic-fit.
  * iOS: `WorkoutHealthValue` has the workout's `totalFlightsClimbed` and `totalSwimmingStrokeCount`, HealthKit's totals for the workout (`null` when the workout has none, and on Android) - PR [#495](https://github.com/carp-dk/carp-health-flutter/pull/495) by @zkrige.
  * iOS: `WorkoutHealthValue` has more of what HealthKit records about a workout: `duration` (its time without pauses, in seconds), `avgMets`, `elevationAscended`, `elevationDescended`, `indoorWorkout`, `weatherTemperature`, `weatherHumidity`, `averageSpeed`, `maximumSpeed` and `workoutEvents`: the workout's pauses, laps, segments and other `WorkoutEvent`s, each with a `WorkoutEventType`, a `start` and an `end`. They are `null` on Android - PR [#522](https://github.com/carp-dk/carp-health-flutter/pull/522) by @zkrige.
  * Swimming workouts: `writeWorkoutData` and `writeWorkoutDataUUID` take `swimming`, a `SwimmingDetails` with the length of the pool in meters (`poolLength`, only for `SWIMMING_POOL`) and the laps (`laps`, each a `SwimmingLap` with a `startTime`, an `endTime` and a `SwimmingStrokeStyle`). They also take `totalSwimmingStrokeCount`, the number of strokes, which only iOS stores. `WorkoutHealthValue.swimming` reads the details back, also for the swims that other apps and watches recorded. Invalid details, such as a pool length on open water or laps that overlap or are not inside the workout, throw an `ArgumentError` before anything is written:
    * iOS: a `SWIMMING_POOL` workout with a pool length is saved with HealthKit's pool location and lap length (`HKMetadataKeyLapLength`), so it reads back as `SWIMMING_POOL`. The laps are lap events of the workout with their stroke style (`HKMetadataKeySwimmingStrokeStyle`; `kickboard` needs iOS 16 and is stored as `unknown` before, and `other` is stored as `unknown`), which `workoutEvents` also lists, and the stroke count is the workout's `totalSwimmingStrokeCount`. Reads give the pool length in meters (a 25-yard pool reads as 22.86).
    * Android: the laps are Health Connect `ExerciseLap`s with the pool length as their length, as Health Connect has no pool length of its own, and their stroke styles are `SWIMMING_*` exercise segments over them (`kickboard` and `other` both read back as `other`, and `unknown` gets no segment). Reads give the pool length that all laps of a pool swim share, and `swimming` is `null` for a swim without laps. Health Connect has no stroke count and no `SWIMMING` workout type.
  * Add `writeSleepSession()` to write a sleep session with its stages (each a `SleepSessionStage` with a `startTime`, an `endTime` and a `type`: `SLEEP_AWAKE`, `SLEEP_AWAKE_IN_BED`, `SLEEP_ASLEEP`, `SLEEP_LIGHT`, `SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_OUT_OF_BED` or `SLEEP_UNKNOWN`), which are checked before anything is written (`ArgumentError`) - Fix [#526](https://github.com/carp-dk/carp-health-flutter/issues/526):
    * Android: one Health Connect sleep session with its stages, title and notes. A sleep type written with `writeHealthData` is a session of its own, which is what #526 ran into for whole nights.
    * iOS: HealthKit has no sleep sessions, so the session is saved in one call as in-bed samples for the session without its out-of-bed stages and a sleep analysis sample for each stage (light, deep and REM as asleep before iOS 16). Unknown and out-of-bed stages get no sample of their own, and the title and notes are not stored. A session longer than 4 days throws a `PlatformException` with code `INVALID_ARGUMENT`.
    * The documentation of `writeSleepSession` says how to remove a session with `delete` on each platform.
  * iOS: `HealthDataType.SLEEP_UNKNOWN` reads the sleep analysis samples whose value no other sleep type covers: none in today's HealthKit, values Apple adds later. HealthKit's `asleepUnspecified` stays `SLEEP_ASLEEP`. It works in reads, intervals and `delete`; `writeHealthData` and `writeHealthDataUUID` throw a `HealthException` with `HealthErrorCode.notSupported` for it, as HealthKit has no unknown sleep value.
* Fixes on both platforms:
  * `writeMeal` dropped `b1Thiamin`: it was sent under a key that neither platform reads.
  * `removeDuplicates` kept duplicates of points with `metadata` (every iOS sample, and workout routes on both platforms), of ECGs and of audiograms: `HealthDataPoint ==` compared `metadata` maps by identity, `ElectrocardiogramHealthValue ==` its voltages, and `AudiogramHealthValue` hashed its lists by identity. Metadata is now compared by its contents, nested maps and lists included.
  * Fix [#1](https://github.com/carp-dk/carp-health-flutter/issues/1), Fix [#194](https://github.com/carp-dk/carp-health-flutter/issues/194) and Fix [#229](https://github.com/carp-dk/carp-health-flutter/issues/229): `HealthDataPoint.deviceModel` was `null` in 13.x. It is again the model of the device that recorded the data on iOS (`HKDevice.model`, such as `iPhone` or `Watch`, as in 12.x), now also on Android (the `model` of Health Connect's `Device`), and `null` when the app that wrote the data reported no device - PR [#478](https://github.com/carp-dk/carp-health-flutter/pull/478) by @nboswell216.
  * `WorkoutSummary.toString` had no comma after the workout type.
* Fixes on Android:
  * Fix [#513](https://github.com/carp-dk/carp-health-flutter/issues/513): on Android 14 and later, a step record whose start equals its end (written by some phones) no longer makes the whole read fail, as connect-client 1.2.0-alpha06 leaves record checks to the platform.
  * `HEART_RATE`, `SPEED` and `SKIN_TEMPERATURE` returned samples outside `startTime`–`endTime`. Records that began up to 24 hours before `startTime` now give their samples inside the range too (Health Connect matches these records by their start time only).
  * `getTotalStepsInInterval(includeManualEntry: false)` counted only the first 1000 step records.
  * Fix [#298](https://github.com/carp-dk/carp-health-flutter/issues/298): `getHealthIntervalDataFromTypes` failed with a `ClassCastException`, and with "Unsupported value" for masses, volumes and durations (`WEIGHT`, `WATER`, sleep, `ACTIVITY_INTENSITY`); values are now sent in kilograms, litres and minutes.
  * `getHealthDataByUUID` threw a `TypeError` when the record had no data of the requested type, for example a sleep stage type for a session without that stage, or `WORKOUT_ROUTE` for a workout without a route. It now returns `null`.
  * Fix [#40](https://github.com/carp-dk/carp-health-flutter/issues/40), Fix [#184](https://github.com/carp-dk/carp-health-flutter/issues/184), Fix [#471](https://github.com/carp-dk/carp-health-flutter/issues/471) and Fix [#489](https://github.com/carp-dk/carp-health-flutter/issues/489): workouts were missing from reads without the distance, calories or steps read permission; they are returned without those totals (`null`), as `totalDistance` needs `READ_DISTANCE`, `totalEnergyBurned` `READ_TOTAL_CALORIES_BURNED` and `totalSteps` `READ_STEPS` - PR [#528](https://github.com/carp-dk/carp-health-flutter/pull/528) by @agilst.
  * The `totalDistance`, `totalEnergyBurned` and `totalSteps` of workouts counted only the first 1000 distance, calorie and step records in the workout. Up to 5000 of each now count.
  * Writes stored `RecordingMethod.manual` as actively recorded and `RecordingMethod.active` as a manual entry. Records written by earlier versions keep the swapped value.
  * Fix [#116](https://github.com/carp-dk/carp-health-flutter/issues/116), Fix [#149](https://github.com/carp-dk/carp-health-flutter/issues/149) and Fix [#150](https://github.com/carp-dk/carp-health-flutter/issues/150): `hasPermissions`, `revokePermissions` and the history, background and skin temperature checks crashed the app when Health Connect threw, for example when the app had used up its API quota or could not reach the Health Connect service. They no longer crash: `hasPermissions` throws the error as a `PlatformException`, the checks return `false`, and `revokePermissions` completes without an error (the failure is only logged) - PR [#533](https://github.com/carp-dk/carp-health-flutter/pull/533) by @Cubel89.
  * `writeHealthDataUUID` checks the device's features as `writeHealthData` does: `SKIN_TEMPERATURE` on a device without the skin temperature feature throws a `HealthException` with `HealthErrorCode.notSupported` (it sent the write and returned an empty string).
  * `insertWorkoutRouteData` reports an invalid location (for example a latitude out of range) with code `INVALID_ARGUMENT` instead of `ARGUMENT_ERROR`.
  * `writeWorkoutData` and `writeWorkoutDataUUID` wrote no workout for `BIKING_STATIONARY` (they returned `false` and an empty string), and Health Connect's stationary biking workouts read as `OTHER`: `BIKING_STATIONARY` is now written and read as Health Connect's `EXERCISE_TYPE_BIKING_STATIONARY` - PR [#477](https://github.com/carp-dk/carp-health-flutter/pull/477) by @georgemac-labs.
  * `writeWorkoutData` and `writeWorkoutDataUUID` wrote no workout for `SOCCER` and `HOCKEY` either, and Health Connect's soccer, ice hockey and paddling workouts read as `OTHER`: `SOCCER`, `HOCKEY` (as Health Connect's ice hockey) and `PADDLE_SPORTS` (as its paddling; iOS only before) are now written and read on Android - PR [#530](https://github.com/carp-dk/carp-health-flutter/pull/530) by @louisdeveseleer.
  * Fix [#490](https://github.com/carp-dk/carp-health-flutter/issues/490) and Fix [#492](https://github.com/carp-dk/carp-health-flutter/issues/492): `HealthDataPoint.workoutSummary` of workouts was always `null`. It now holds the workout's type, as in `WorkoutHealthValue.workoutActivityType`, and its total distance, energy burned and steps (0 for a total that is missing), as on iOS - PR [#535](https://github.com/carp-dk/carp-health-flutter/pull/535) by @ChandraChaan.
  * Fix [#124](https://github.com/carp-dk/carp-health-flutter/issues/124): Health Connect permissions cannot be requested when the app's `MainActivity` extends `FlutterActivity` instead of `FlutterFragmentActivity`, and `requestAuthorization` returned `false` without saying why. Attached to such an activity, the plugin now logs an error naming the activity and the fix, and `requestAuthorization`, `requestHealthDataHistoryAuthorization` and `requestHealthDataInBackgroundAuthorization` (which still return `false`) log "Permission launcher not found" as an error. With a Flutter engine created before the activity (for example a cached engine, as `audio_service` uses), such an activity crashed the app with a `ClassCastException` when it started; it no longer does - PR [#511](https://github.com/carp-dk/carp-health-flutter/pull/511) by @giovanirasia.
  * `requestAuthorization`, `requestHealthDataHistoryAuthorization` and `requestHealthDataInBackgroundAuthorization` called while the Health Connect permission dialog was open took the place of the earlier call, which never got an answer; the later call now returns `false`. A `requestAuthorization` call for a type that Health Connect does not have, or with malformed arguments, made while the dialog was open crashed the app when the dialog closed. When the dialog cannot be opened, `requestAuthorization` throws a `PlatformException` with one of the plugin's error codes, such as `HEALTH_ERROR`, instead of the code `error`. Attached to an activity that has already started (for example when an add-to-app host adds a `FlutterFragment` with a cached engine to a running activity), the plugin crashed the app with an `IllegalStateException`; it now logs an error, and permission requests return `false` - PR [#508](https://github.com/carp-dk/carp-health-flutter/pull/508) by @Pratihar.
* Fixes on iOS:
  * `requestAuthorization` with no type this iOS version has (for example only `POWER` before iOS 17) crashed the app; it returns `false` without showing a sheet.
  * `getHealthIntervalDataFromTypes` crashed the app for `HEART_RATE` and other types that HealthKit averages over time.
  * A `preferredUnits` entry that cannot express the type crashed the app; it throws a `HealthPlatformException` with `HealthErrorCode.invalidArgument`. `CENTIMETER` and `MILLIMOLES_PER_LITER` work (they crashed the app).
  * An ECG whose voltage measurements cannot be read fails the read instead of being left out silently.
  * Writes that HealthKit raises an exception for, which crashed the app, throw a `PlatformException` with code `INVALID_ARGUMENT` before anything is saved:
    * samples longer than HealthKit allows for their type (4 days for most types) or ending in the year 4001 or later, in `writeHealthData`, `writeHealthDataUUID`, `writeBloodPressure`, `writeMeal`, `writeInsulinDelivery`, `writeMenstruationFlow`, `writeWorkoutData` and `writeWorkoutDataUUID`;
    * a unit the type cannot use in `writeHealthData` and `writeHealthDataUUID`, and a missing or wrong unit in `writeWorkoutData` and `writeWorkoutDataUUID`;
    * `writeMeal` without a nutrient that HealthKit stores.
  * `writeAudiogram` checks the audiogram first and throws a `PlatformException` with code `INVALID_ARGUMENT` for more than 30 frequencies, frequencies that are not unique and ascending, a frequency or threshold out of range, a range longer than 4 days, or a `metadata` value that is not a String. It never completed when `metadata` lacked `HKDeviceName` or `HKExternalUUID`; both keys are optional now.
  * `writeHealthDataUUID` crashed the app for a type or unit this iOS version does not have; it returns an empty string, as `writeHealthData` returns `false`.
  * `writeHealthDataUUID` and `writeWorkoutDataUUID` replied twice to one call.
  * On iOS 15, which has no light, deep or REM sleep values, `writeHealthDataUUID` now writes `SLEEP_LIGHT`, `SLEEP_DEEP` and `SLEEP_REM` as asleep, as `writeHealthData` did.
  * `writeMeal` without a `name` failed with `WRITE_ERROR`.
  * `insertWorkoutRouteData` stored a location without `altitude` as a valid altitude of 0 m (with a vertical accuracy of 100 m), so a route that mixed such locations with measured ones showed false climbs and descents. It now stores the altitude as invalid, so the location reads back without `altitude` and `verticalAccuracy`, as on Android.
* Docs: new README sections "Authorization on iOS", "Writing workouts (iOS & Android)" (with "Swimming workouts"), "Writing a night of sleep (iOS & Android)", "Writing a mindfulness session (iOS & Android)", "Reading large amounts of data", "Reading data over intervals", "Error handling" and "Health Connect limits" (API quotas, which depend on the Health Connect version, and the calls each read costs), and a row for the `DIETARY_*` types in the README's table of data types - Fix [#51](https://github.com/carp-dk/carp-health-flutter/issues/51). The README says that the app's `MainActivity` must extend `FlutterFragmentActivity` on every Android version, not only on Android 14. The API reference groups the methods of `Health` by topic in documented mixins (`HealthDataReads`, `HealthPermissions`, `HealthDataWrites`, ...); calling them is unchanged. The documentation of `getHealthIntervalDataFromTypes` says what `recordingMethodsToFilter` can leave out: on iOS only `RecordingMethod.manual`, and on Android only data of the sleep types, as the other intervals are Health Connect aggregates over every recording method (as before); a filter that cannot be applied now prints a warning to the console. The documentation of `WorkoutHealthValue` says which read permission each total of an Android workout needs. The example app shows read errors; writes its sample night with `writeSleepSession`, a mindfulness session with `writeMindfulnessSession`, a VO2 max value and a pool swim with laps; and on Android leaves out `MINDFULNESS` and `SKIN_TEMPERATURE` where Health Connect does not have them.

## 13.3.2

* Write data now returns UUID of records - PR [#448](https://github.com/carp-dk/carp-health-flutter/pull/448)
* Fix [#502](https://github.com/carp-dk/carp-health-flutter/issues/502)
* iOS: Fix [#480](https://github.com/carp-dk/carp-health-flutter/issues/480) - PR [#504](https://github.com/carp-dk/carp-health-flutter/pull/504) - the native plugin class is now `HealthPlugin` (previously `SwiftHealthPlugin` behind an Objective-C shim) - apps using the generated plugin registrant are unaffected
* iOS: Raise the minimum deployment target to 15.0

## 13.3.1

* iOS: Fix issues with app crashing on iOS 15
* iOS: Add support for `AppleSleepingWristTemperature` - PR [#468](https://github.com/carp-dk/carp-health-flutter/pull/468)
* Android: Add support for `SkinTemperatureRecord` (READ/WRITE)

## 13.3.0

* Add support for `WORKOUT_ROUTE` - PR [#454](https://github.com/carp-dk/carp-health-flutter/pull/454)
* Android: Add support for `ActivityIntensityRecord` (READ/WRITE/Aggregate)
* Update to `androidx.health.connect:connect-client:1.2.0-alpha02`

## 13.2.1

No changes - Now the [Health](https://pub.dev/packages/health) package lives in its own repository at [https://github.com/carp-dk/carp-health-flutter](https://github.com/carp-dk/carp-health-flutter)

## 13.2.0

* Add get health data by UUID (see `getHealthDataByUUID()`) - PR [#1193](https://github.com/carp-dk/flutter-plugins/pull/1193), [#1194](https://github.com/carp-dk/flutter-plugins/pull/1194)
* Add delete by UUID (`deleteByUUID()`)
* Add support for unit conversion in `WeightRecord`, `HeightRecord`, `BodyTemperatureRecord`, and `BloodGlucoseRecord` - PR [#1223](https://github.com/carp-dk/flutter-plugins/pull/1223)
* Update `compileSDK` to 36 - Fix [#1261](https://github.com/carp-dk/flutter-plugins/issues/1261)
* Update Gradle to 8.9.1
* Update `org.jetbrains.kotlin.android` to 2.1.0
* Update `androidx.health.connect:connect-client` to 1.1.0-rc03
* Update `device_info_plus` to 12.1.0 - Fix [#1264](https://github.com/carp-dk/flutter-plugins/issues/1264)

## 13.1.4

* Fix adding mindfulness resulted in crash in iOS
* Support SPM for iOS

## 13.1.3

* Fix permissions issues with iOS
* Fix [#1231](https://github.com/cph-cachet/flutter-plugins/issues/1231)

## 13.1.2

* Fix [#1250](https://github.com/cph-cachet/flutter-plugins/issues/1250)
* Fix [#1233](https://github.com/cph-cachet/flutter-plugins/issues/1233)

## 13.1.1

* Fix [#1207](https://github.com/cph-cachet/flutter-plugins/issues/1207) - (**Important**: Some property names might have changed compared to before for `Nutrition`)
* Fix [#1201](https://github.com/cph-cachet/flutter-plugins/issues/1201)
* iOS: Add `APPLE_STAND_TIME`, `APPLE_STAND_HOUR`, and `APPLE_MOVE_TIME` health data types (READ ONLY) [#1190](https://github.com/cph-cachet/flutter-plugins/issues/1190)

## 13.1.0

* Refactored Android native implementation (No Flutter API changes)
* Android: Add `SPEED` health data type - PR [#1183](https://github.com/cph-cachet/flutter-plugins/pull/1183)
* iOS: Add `WALKING_SPEED` health data type - PR [#1183](https://github.com/cph-cachet/flutter-plugins/pull/1183)
* Add `METER_PER_SECOND` health data unit

## 13.0.1

* Refactored Swift native implementation - See PR [#1175](https://github.com/cph-cachet/flutter-plugins/pull/1175) and [#1208](https://github.com/cph-cachet/flutter-plugins/pull/1208) for more information:

```
SwiftHealthPlugin (Main Plugin Class)
├── HealthDataReader (Reading health data)
├── HealthDataWriter (Writing health data)
├── HealthDataOperations (Permissions and deletion)
├── HealthUtilities (Helper functions)
└── HealthConstants (Constants and enums)
```

## 13.0.0

* Refactored Swift native implementation

## 12.2.1

* iOS: Add `swift_version` for add-to-app implementations - PR [#1205](https://github.com/cph-cachet/flutter-plugins/pull/1205)

## 12.2.0

* iOS: Add `deviceModel` in returned Health data to identify the device that generated the data of the receiver. (in iOS `source_name` represents the revision of the source responsible for saving the receiver.)
* Android: Add read health data in background - PR [#1184](https://github.com/cph-cachet/flutter-plugins/pull/1184)
* Fix [#1169](https://github.com/cph-cachet/flutter-plugins/issues/1169) where `meal_type` property in `Nutrition` was null always
* iOS: Add `CARDIO_DANCE` HealthDataType - [#1146](https://github.com/cph-cachet/flutter-plugins/pull/1146)

## 12.1.0

* Add delete record by UUID method. See function `deleteByUUID(required String uuid, HealthDataType? type)`
* iOS: Parse metadata to remove unsupported types - PR [#1120](https://github.com/cph-cachet/flutter-plugins/pull/1120)
* iOS: Add UV Index Types
* Android: Add request access to historic data [#1126](https://github.com/cph-cachet/flutter-plugins/issues/1126) - PR [#1127](https://github.com/cph-cachet/flutter-plugins/pull/1127)

```XML
<!-- Add the following permission into AndroidManifest.xml -->
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY"/>
```

* Android:
  * Update `androidx.compose:compose-bom` to `2025.02.00`
  * Update `androidx.health.connect:connect-client` to `1.1.0-alpha11`
  * Update `androidx.fragment:fragment-ktx` to `1.8.6`
  * Update to Java 11
* Update example apps

## 12.0.1

* Update of API and README doc
* Fix [#1118](https://github.com/cph-cachet/flutter-plugins/issues/1118)

## 12.0.0

* **BREAKING** This release introduces a significant architectural change to the `health` plugin by removing the `singleton` pattern.
  * **Dependency Injection for `DeviceInfoPlugin`**:
  * The `Health` class is no longer a singleton.
  * The `Health()` factory constructor is removed.
  * The `Health` class now accepts an (optional) `DeviceInfoPlugin` dependency through its constructor, this change was introduced to provide easy mocking of the `DeviceInfo` class during unit tests.
  * This architectural change means that, for the application to work correctly, the `Health` class *MUST* be initialized correctly as a global instance.
  * **Impact**:
    * For most users, **no immediate code changes are required** but it is paramount to initialize the `Health` class as a global instance (i.e. do not call `Health()` every time but rather define an instance `final health = Health();`).
* **BREAKING** (Android) Remove automatic permission request of `DISTANCE_DELTA` and `TOTAL_CALORIES_BURNED` data types when requesting permission for `WORKOUT` health data type.
  * For `WORKOUT`s that require above permissions, now those need to be requested manually.
  * Fix [#984](https://github.com/cph-cachet/flutter-plugins/issues/984) - PR [#1055](https://github.com/cph-cachet/flutter-plugins/pull/1055)
* Add `LEAN_BODY_MASS` data type [#1078](https://github.com/cph-cachet/flutter-plugins/issues/1078) - PR [#1097](https://github.com/cph-cachet/flutter-plugins/pull/1097)
  * The following AndroidManifest values are required to READ/WRITE `LEAN_BODY_MASS`:

  ```XML
  <uses-permission android:name="android.permission.health.READ_LEAN_BODY_MASS"/>
  <uses-permission android:name="android.permission.health.WRITE_LEAN_BODY_MASS"/>
  ```

* iOS: Add `WATER_TEMPERATURE` and `UNDERWATER_DEPTH` health values [#1096](https://github.com/cph-cachet/flutter-plugins/issues/1096)
* iOS: Add support for `Underwater Diving` workout [#1096](https://github.com/cph-cachet/flutter-plugins/issues/1096)
* Fix [#1072](https://github.com/cph-cachet/flutter-plugins/issues/1072) and [#1074](https://github.com/cph-cachet/flutter-plugins/issues/1074)
* Fix issue where iOS delete not deleting own records - PR [#1104](https://github.com/cph-cachet/flutter-plugins/pull/1104)
* Fix [#950](https://github.com/cph-cachet/flutter-plugins/issues/950) - PR [#1103](https://github.com/cph-cachet/flutter-plugins/pull/1103)
* Fix [#1047](https://github.com/cph-cachet/flutter-plugins/issues/1047) and [#939](https://github.com/cph-cachet/flutter-plugins/issues/939) - PR [#1091](https://github.com/cph-cachet/flutter-plugins/pull/1091)
* Fix issue where `SLEEP_LIGHT` type was not aligned correctly - PR [#1086](https://github.com/cph-cachet/flutter-plugins/pull/1086)
* Fix [#1051](https://github.com/cph-cachet/flutter-plugins/issues/1051) - PR [#1052](https://github.com/cph-cachet/flutter-plugins/pull/1052)
* Updated `intl` to ^0.20.1 [#1092](https://github.com/cph-cachet/flutter-plugins/issues/1092)
* Updated `device_info_plus` to ^11.2.0
* Example app: Updated `permission_handler` to ^11.3.1

## 11.1.1

* Fix of [#1059](https://github.com/cph-cachet/flutter-plugins/issues/1059)

## 11.1.0

* Fix of [#1043](https://github.com/cph-cachet/flutter-plugins/issues/1043)
* Type-safe JSON deserialization using carp_serializable v. 2.0

## 11.0.0

* **BREAKING** Remove Google Fit support in the Android code, as well as Google FIt related dependencies and references throughout the documentation
  * Remove `useHealthConnectIfAvailable` from the parameters of `Health().configure()`
  * Remove the `disconnect` method which was previously used to disconnect from Google Fit.
  * Remove the `flowRate` value from `writeBloodOxygen` as this is not supported by Health Connect.
  * Remove support for various `HealthWorkoutActivityType`s which were supported by Google Fit. Some of these do not have suitable alternatives in Google Health Connect (and are not supported on iOS). The list of removed types can be found in PR [#1014](https://github.com/cph-cachet/flutter-plugins/pull/1014)
* **BREAKING** introduce a new `RecordingMethod` enum
  * This can be used to filter records by automatic or manual entries when fetching data
  * You can also specify the recording method to write in the metadata
  * Remove `isManualEntry` from `HealthDataPoint` in favor of `recordingMethod`, of which the value is an enum `RecordingMethod`
  * Remove `includeManualEntry` (previously a boolean) from some of the querying methods in favor of `recordingMethodsToFilter`.
  * For complete details on relevant changes, see the description of PR [#1023](https://github.com/cph-cachet/flutter-plugins/pull/1023)
* Add support for all sleep stages across iOS and Android
  * Clean up relevant documentation
  * Remove undocumented sleep stages
  * **BREAKING** certain sleep stages were removed/combined into other related stages see PR [#1026](https://github.com/cph-cachet/flutter-plugins/pull/1026) for the complete list of changes and a discussion of the motivation in issue [#985](https://github.com/cph-cachet/flutter-plugins/issues/985)
* Android: Add support for `OTHER` workout type
* Cleaned up workout activity types for consistency across iOS and Android, see PR [#1020](https://github.com/cph-cachet/flutter-plugins/pull/1020) for a complete list of changes
* iOS: add support for menstruation flow, PR [#1008](https://github.com/cph-cachet/flutter-plugins/pull/1008)
* Android: Add support for heart rate variability, PR [#1009](https://github.com/cph-cachet/flutter-plugins/pull/1009)
* iOS: add support for atrial fibrillation burden, PR [#1031](https://github.com/cph-cachet/flutter-plugins/pull/1031)
* Add support for UUIDs in health records for both HealthKit and Health Connect, PR [#1019](https://github.com/cph-cachet/flutter-plugins/pull/1019)
* Fix an issue when querying workouts, the native code could respond with an activity that is not supported in the Health package, causing an error - this will fallback to `HealthWorkoutActivityType.other` - PR [#1016](https://github.com/cph-cachet/flutter-plugins/pull/1016)
* Remove deprecated Android v1 embeddings, PR [#1021](https://github.com/cph-cachet/flutter-plugins/pull/1021)

## 10.2.0

* Using named parameters in most methods for consistency.
* Added a `HealthPlatformType` to save which health platform the data originates from (Apple Health, Google Fit, or Google Health Connect).
* Android: Improved support for Google Health Connect
  * getHealthConnectSdkStatus, PR [#941](https://github.com/cph-cachet/flutter-plugins/pull/941)
  * installHealthConnect, PR [#943](https://github.com/cph-cachet/flutter-plugins/pull/943)
  * workout title, PR [#938](https://github.com/cph-cachet/flutter-plugins/pull/938)
* iOS: Add support for saving blood pressure as a correlation, PR [#919](https://github.com/cph-cachet/flutter-plugins/pull/919)

## 10.1.1

* Fix of error in `WorkoutSummary` JSON serialization.
* Fix of [#934](https://github.com/cph-cachet/flutter-plugins/issues/934)
* Empty value check for calories nutrition, PR [#926](https://github.com/cph-cachet/flutter-plugins/pull/926)
  
## 10.0.0

* **BREAKING** The plugin now works as a singleton using `Health()` to access it (instead of creating an instance of `HealthFactory`).
  * This entails that the plugin now need to be configured using the `configure()` method before use.
  * The example app has been update to demonstrate this new singleton model.
* Support for new data types:
  * body water mass, PR [#917](https://github.com/cph-cachet/flutter-plugins/pull/917)
  * caffeine, PR [#924](https://github.com/cph-cachet/flutter-plugins/pull/924)
  * workout summary, manual entry and new health data types, PR [#920](https://github.com/cph-cachet/flutter-plugins/pull/920)
* Fixed `SleepSessionRecord`, PR [#928](https://github.com/cph-cachet/flutter-plugins/pull/928)
* Update to API and README docs
* Upgrade to Dart 3.2 and Flutter 3.
* Added Dart linter and fixed a series of type casting issues.
* Using carp_serializable for consistent camel_case and type-safe generation of JSON serialization methods for polymorphic health data type classes.

## 9.0.0

* Updated HC to comply with Android 14, PR [#834](https://github.com/cph-cachet/flutter-plugins/pull/834) and [#882](https://github.com/cph-cachet/flutter-plugins/pull/882)
* Added checks for NullPointerException, closes issue [#878](https://github.com/cph-cachet/flutter-plugins/issues/878)
* Updated intl to ^0.19.0
* Upgrade to AGP 8, PR [#868](https://github.com/cph-cachet/flutter-plugins/pull/868)
* Added missing google fit workout types, PR [#836](https://github.com/cph-cachet/flutter-plugins/pull/836)
* Added pagination in HC, PR [#862](https://github.com/cph-cachet/flutter-plugins/pull/862)
* Fix of permission in example app + improvements to doc, PR [#875](https://github.com/cph-cachet/flutter-plugins/pull/875)

## 8.1.0

* Fixed sleep stages on iOS, Issue [#803](https://github.com/cph-cachet/flutter-plugins/issues/803)
* Added Nutrition data type, includes PR [#679](https://github.com/cph-cachet/flutter-plugins/pull/679)
* Lowered minSDK, Issue [#809](https://github.com/cph-cachet/flutter-plugins/issues/809)

## 8.0.0

* Fixed issue [#774](https://github.com/cph-cachet/flutter-plugins/issues/774), [#779](https://github.com/cph-cachet/flutter-plugins/issues/779)
* Merged PR [#579](https://github.com/cph-cachet/flutter-plugins/pull/579), [#717](https://github.com/cph-cachet/flutter-plugins/pull/717), [#770](https://github.com/cph-cachet/flutter-plugins/pull/770)
* Upgraded to mavenCentral, upgraded minSDK, compileSDK, targetSDK
* Updated health connect client to 1.1.0
* Added respiratory rate and peripheral perfusion index to HealthConnect
* Minor fixes to requestAuthorization, sleep stage filtering

## 7.0.1

* Updated dart doc

## 7.0.0

* Merged PR #722
* Added deep, light, REM, and out of bed sleep to iOS and Android HealthConnect

## 6.0.0

* Fixed issues #[694](https://github.com/cph-cachet/flutter-plugins/issues/694), #[696](https://github.com/cph-cachet/flutter-plugins/issues/696), #[697](https://github.com/cph-cachet/flutter-plugins/issues/697), #[698](https://github.com/cph-cachet/flutter-plugins/issues/698)
* added totalSteps for HealthConnect
* added supplemental oxygen flow rate for blood oxygen saturation on Android

## 5.0.0

* Added initial support for the new Health Connect API, as Google Fit is being deprecated.
  * Does not yet support `revokePermissions`, `getTotalStepsInInterval`.
* Changed Intl package version dependency to `^0.17.0` to work with flutter stable version.
* Updated the example app to handle more buttons.

## 4.6.0

* Added method for revoking permissions. On Android it uses `disableFit()` to remove access to Google Fit - `revokePermissions`. Documented lack of methods for iOS.

## 4.5.0

* Updated android sdk, gradle
* Updated `enumToString` to native `.name`
* Update and fixed JSON serialization of HealthDataPoints
* Removed auth request in `writeWorkoutData` to avoid bug when denying the auth.
* Merged pull requests [#653](https://github.com/cph-cachet/flutter-plugins/pull/653), [#652](https://github.com/cph-cachet/flutter-plugins/pull/652), [#639](https://github.com/cph-cachet/flutter-plugins/pull/639), [#644](https://github.com/cph-cachet/flutter-plugins/pull/644), [#668](https://github.com/cph-cachet/flutter-plugins/pull/668)
* Further developed [#644](https://github.com/cph-cachet/flutter-plugins/pull/644) on android to accommodate having the `writeBloodPressure` api.
* Small bug fixes

## 4.4.0

* Merged pull request #[566](https://github.com/cph-cachet/flutter-plugins/pull/566), [#578](https://github.com/cph-cachet/flutter-plugins/pull/578), [#596](https://github.com/cph-cachet/flutter-plugins/pull/596), [#623](https://github.com/cph-cachet/flutter-plugins/pull/623), [#632](https://github.com/cph-cachet/flutter-plugins/pull/632)
* ECG added as part of [#566](https://github.com/cph-cachet/flutter-plugins/pull/566)
* Small fixes

## 4.3.0

* upgrade to `device_info_plus: ^8.0.0`

## 4.2.0

* upgrade to `device_info_plus: ^7.0.0`

## 4.1.1

* fix of [#572](https://github.com/cph-cachet/flutter-plugins/issues/572).

## 4.1.0

* update of `device_info_plus: ^4.0.0`
* upgraded to Dart 2.17 and Flutter 3.0

## 4.0.0

* Large refactor of the `HealthDataPoint` value into generic `HealthValue` and added `NumericHealthValue`, `AudiogramHealthValue` and `WorkoutHealthValue`
* Added support for Audiograms with `writeAudiogram` and in `getHealthDataFromTypes`
* Added support for Workouts with `writeWorkout` and in `getHealthDataFromTypes`
* Added all `HealthWorkoutActivityType`s
* Added more `HealthDataUnit` types
* Fix of [#432](https://github.com/cph-cachet/flutter-plugins/issues/532)
* updated documentation in code
* updated documentation in README.md
* updated example app
* cleaned up code
* removed `requestPermissions` as it was essentially a duplicate of `requestAuthorization`

## 3.4.4

* Fix of [#500](https://github.com/cph-cachet/flutter-plugins/issues/500).
* Added Headache-types to HealthDataTypes on iOS

## 3.4.3

* fix of [#401](https://github.com/cph-cachet/flutter-plugins/issues/401).

## 3.4.2

* Resolved concurrent issues with native threads [PR#483](https://github.com/cph-cachet/flutter-plugins/pull/483).
* HealthKit CategorySample [PR#485](https://github.com/cph-cachet/flutter-plugins/pull/485).
* update of API documentation.

## 3.4.0

* Add sleep in bed to android [PR#457](https://github.com/cph-cachet/flutter-plugins/pull/457).
* Add the android.permission.ACTIVITY_RECOGNITION setup to the README [PR#458](https://github.com/cph-cachet/flutter-plugins/pull/458).
* Fixed (regression) issues with metric and permissions [PR#462](https://github.com/cph-cachet/flutter-plugins/pull/462).
* Get total steps [PR#471](https://github.com/cph-cachet/flutter-plugins/pull/471).
* update of example app to reflect new features.
* update of API documentation.

## 3.3.1

* DISTANCE_DELTA is for Android, not iOS [PR#428](https://github.com/cph-cachet/flutter-plugins/pull/428).
* added missing READ_ACCESS [PR#454](https://github.com/cph-cachet/flutter-plugins/pull/454).

## 3.3.0

* Write support on Google Fit and HealthKit [PR#430](https://github.com/cph-cachet/flutter-plugins/pull/430).

## 3.2.1

* Updated `device_info_plus` version dependency

## 3.2.0

* added simple `HKWorkout` and `ExerciseTime` support [PR#421](https://github.com/cph-cachet/flutter-plugins/pull/421).

## 3.1.1+1

* added functions to request authorization [PR#394](https://github.com/cph-cachet/flutter-plugins/pull/394)

## 3.1.0

* added sleep data to Android + fix of permissions and initialization [PR#372](https://github.com/cph-cachet/flutter-plugins/pull/372)
* testability of HealthDataPoint [PR#388](https://github.com/cph-cachet/flutter-plugins/pull/388).
* update to using the `device_info_plus` plugin

## 3.0.6

* Added two new fields to the `HealthDataPoint` - `SourceId` and `SourceName` and populate when data is read. This allows data points to be disambiguous and in some cases allows us to get more accurate data. For example the number of steps can be reported from Apple Health and Watch and without source data they are aggregated into just "steps" producing an inaccurate result [PR#281](https://github.com/cph-cachet/flutter-plugins/pull/281).

## 3.0.5

* Null safety in Dart has been implemented
* The plugin supports the Android v2 embedding

## 3.0.4

* Upgrade to `device_info` version 2.0.0

## 3.0.3

* Merged various PRs, mostly smaller fixes

## 3.0.2

* Upgrade to `device_info` version 1.0.0

## 3.0.1+1

* Bugfix regarding BMI from <https://github.com/cph-cachet/flutter-plugins/pull/258>

## 3.0.0

* Changed the flow for requesting access and reading data
  * Access must be requested manually before reading
  * This simplifies the data flow and makes it easier to reason about when debugging
* Data read access is no longer checked for each individual type, but rather on the set of types specified.

## 2.0.9

* Now handles the case when asking for BMI on Android when no height data has been collected.

## 2.0.8

* Fixed a merge issue which had deleted the data types added in 2.0.4.

## 2.0.7

* Fixed a Google sign-in issue, and a type issue on Android (<https://github.com/cph-cachet/flutter-plugins/issues/201>)

## 2.0.6

* Fixed a Google sign-in issue. (<https://github.com/cph-cachet/flutter-plugins/issues/172>)

## 2.0.5

* Now uses 'device_info' rather than 'device_id' for getting device information

## 2.0.4+1

* Static analysis, formatting etc.

## 2.0.4

* Added Sleep data, Water, and Mindfulness.

## 2.0.3

* The method `requestAuthorization` is now public again.

## 2.0.2

* Updated the API to take a list of types rather than a single type, when requesting health data.

## 2.0.1+1

* Removed the need for try-catch on the programmer's end

## 2.0.1

* Removed UUID and instead introduced a comparison operator

## 2.0.0

* Changed the API substantially to allow for granular Data Type permissions

## 1.1.6

Added the following Health Types as per PR #147

* DISTANCE_WALKING_RUNNING
* FLIGHTS_CLIMBED
* MOVE_MINUTES
* DISTANCE_DELTA

## 1.1.5

* Fixed an issue with google authorization
* See <https://github.com/cph-cachet/flutter-plugins/issues/133>

## 1.1.4

* Corrected table of units

## 1.1.3

* Updated table with units

## 1.1.2

* Now supports the data type `HEART_RATE_VARIABILITY_SDNN` on iOS

## 1.1.1

* Fixed issue #88 (<https://github.com/cph-cachet/flutter-plugins/issues/88>)

## 1.1.0

* Introduced UUID to the HealthDataPoint class
* Re-did the example application

## 1.0.6

* Fixed a null-check warning in the obj-c code (issue #87)

## 1.0.5

* Updated gradle-wrapper distribution url `gradle-5.4.1-all.zip`
* Updated docs

## 1.0.2

* Updated documentation for Android and Google Fit.

## 1.0.1

* Streamlined DataType units in Flutter.
