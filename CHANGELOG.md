## 14.0.0

### Added

- Paged, off-UI-thread data reading for large time ranges:
  - `getHealthDataPages()`, returns a lazy `Stream<HealthDataPage>` that fetches the next page only on demand and stops when cancelled (unlike `getHealthDataFromTypes`, which returns a single list)
  - `Health.pageSize` (default `20000`, max `50000`, Health Connect limits single calls at 5,000 records) and `Health.isolateMode` (`HealthIsolateMode.auto` [default], `worker`, `inline`) to decode and parse large replies in a worker isolate. Both can also be passed to `Health()`
  - Record conversion on Android and HealthKit reply delivery on iOS now run off the UI thread - PR [#531](https://github.com/carp-dk/carp-health-flutter/pull/531)
  - Android: Heart rate reads use adaptive time slices based on Health Connect sample counts so pages stay near `pageSize` without splitting individual records
- Optional `limit` parameter on `getHealthDataFromTypes` to fetch up to `limit` newest data points per type without scanning the entire range - Fixes [#279](https://github.com/carp-dk/carp-health-flutter/issues/279), PR [#517](https://github.com/carp-dk/carp-health-flutter/pull/517)
- Structured error handling, see `HealthPlatformException` (extends `PlatformException` and implements `HealthException`) and `HealthErrorCode`
- Android: Reading a data type with write permission but without read permission now returns records written by your own app (matching iOS behaviour), marking those pages with `HealthDataPage.readPermissionDenied`. The 30-day history limit does not apply to your app's own records, and workout totals written by your app can be read with the proper write permissions (`WRITE_DISTANCE`, `WRITE_TOTAL_CALORIES_BURNED`, `WRITE_STEPS`). Interval reads still require read permission
- Android: `isActivityIntensityAvailable()` to check whether the device's Health Connect version supports `ACTIVITY_INTENSITY` records (returns `false` on iOS)
- Writing read-only `HealthDataType.POWER` (cycling power on iOS 17+ unit `WATT`, and any exercise power on Android with `READ_POWER`) and `HealthDataType.CYCLING_CADENCE` (iOS 17+ unit `REVOLUTION_PER_MINUTE`, Android with `READ_EXERCISE`) types throws `ArgumentError` - PR [#487](https://github.com/carp-dk/carp-health-flutter/pull/487)
- `HealthDataType.VO2_MAX` support on iOS (`vo2Max`) and Android (`Vo2MaxRecord`, requiring `READ_VO2_MAX`/`WRITE_VO2_MAX` and values from `0` to `100`). Interval averages are returned on iOS (none on Android) - PR [#481](https://github.com/carp-dk/carp-health-flutter/pull/481)
- `HealthDataType.SEXUAL_ACTIVITY` support (`SexualActivityHealthValue`, `SexualActivityProtection`, and `writeSexualActivity()`) on Android (`SexualActivityRecord`, requiring `READ_SEXUAL_ACTIVITY`/`WRITE_SEXUAL_ACTIVITY`) and iOS (`HKCategoryTypeIdentifier.sexualActivity` with `HKMetadataKeySexualActivityProtectionUsed`)
- iOS: 41 additional HealthKit quantity types along with new units `LITER_PER_MINUTE`, `KILOCALORIE_PER_HOUR_KILOGRAM`, and `APPLE_EFFORT_SCORE` - Fixes [#8](https://github.com/carp-dk/carp-health-flutter/issues/8), [#92](https://github.com/carp-dk/carp-health-flutter/issues/92), [#95](https://github.com/carp-dk/carp-health-flutter/issues/95) - PR [#522](https://github.com/carp-dk/carp-health-flutter/pull/522):
  - **iOS 15+:** `BASAL_BODY_TEMPERATURE`, `NUMBER_OF_TIMES_FALLEN`, `ENVIRONMENTAL_AUDIO_EXPOSURE`, `HEADPHONE_AUDIO_EXPOSURE`, `PEAK_EXPIRATORY_FLOW`, `FORCED_VITAL_CAPACITY`, `INHALER_USAGE`, `BLOOD_ALCOHOL_CONTENT`, `NUMBER_OF_ALCOHOLIC_BEVERAGES`, `PUSH_COUNT`, `DISTANCE_WHEELCHAIR`, `SWIMMING_STROKE_COUNT`, `DISTANCE_DOWNHILL_SNOW_SPORTS`, `WALKING_STEP_LENGTH`, `WALKING_DOUBLE_SUPPORT_PERCENTAGE`, `WALKING_ASYMMETRY_PERCENTAGE` (read-only), `APPLE_WALKING_STEADINESS` (read-only), `STAIR_ASCENT_SPEED`, `STAIR_DESCENT_SPEED`, `SIX_MINUTE_WALK_TEST_DISTANCE`
  - **iOS 16+:** `RUNNING_POWER`, `RUNNING_SPEED`, `RUNNING_STRIDE_LENGTH`, `RUNNING_VERTICAL_OSCILLATION`, `RUNNING_GROUND_CONTACT_TIME`, `HEART_RATE_RECOVERY_ONE_MINUTE`, `ENVIRONMENTAL_SOUND_REDUCTION`
  - **iOS 17+:** `TIME_IN_DAYLIGHT`, `PHYSICAL_EFFORT`, `CYCLING_SPEED`, `CYCLING_FUNCTIONAL_THRESHOLD_POWER`
  - **iOS 18+:** `DISTANCE_CROSS_COUNTRY_SKIING`, `DISTANCE_PADDLE_SPORTS`, `DISTANCE_ROWING`, `DISTANCE_SKATING_SPORTS`, `CROSS_COUNTRY_SKIING_SPEED`, `PADDLE_SPORTS_SPEED`, `ROWING_SPEED`, `WORKOUT_EFFORT_SCORE`, `ESTIMATED_WORKOUT_EFFORT_SCORE`, `APPLE_SLEEPING_BREATHING_DISTURBANCES` (read-only)
  - Reading a type on an older iOS version throws `HealthPlatformException(HealthErrorCode.notSupported)`
- Android: Full `MINDFULNESS` support via Health Connect (`READ_MINDFULNESS`, `WRITE_MINDFULNESS`). The new `writeMindfulnessSession()` writes typed sessions (`MindfulnessSessionType`: `UNKNOWN`, `MEDITATION`, `BREATHING`, `MUSIC`, `MOVEMENT`, `UNGUIDED`) with optional title and notes. Added `isMindfulnessSessionAvailable()` (always `true` on iOS), unsupported devices throw `HealthException(HealthErrorCode.notSupported)`, and zero-duration writes throw `PlatformException` (`INVALID_ARGUMENT`) - PR [#460](https://github.com/carp-dk/carp-health-flutter/pull/460), PR [#510](https://github.com/carp-dk/carp-health-flutter/pull/510)
- iOS: `MINDFULNESS` support in `getHealthIntervalDataFromTypes`, returning deduplicated mindful minutes per interval
- iOS: `HealthDataType.SLEEP_UNKNOWN` for reading, interval-aggregating, and deleting HealthKit sleep analysis values not mapped to another sleep type (`asleepUnspecified` remains `SLEEP_ASLEEP` and writing throws `HealthException(HealthErrorCode.notSupported)`)
- iOS: `getRequestStatusForAuthorization()` (wrapping HealthKit's `getRequestStatusForAuthorization(toShare:read:)`) returning `HealthAuthorizationRequestStatus.shouldRequest` or `unnecessary`, so apps can tell whether `requestAuthorization` will display the permission sheet (returns `null` on Android and throws `ArgumentError` for write access to read-only types and `PlatformException` on HealthKit errors) - Fixes [#397](https://github.com/carp-dk/carp-health-flutter/issues/397), PR [#499](https://github.com/carp-dk/carp-health-flutter/pull/499)
- iOS: Support `WorkoutMetadata` (`workoutBrandName`, `indoorWorkout`, `groupFitness`, `coachedWorkout`) on `writeWorkoutData` and `writeWorkoutDataUUID` to save metadata (ignored on Android) - Fixes [#74](https://github.com/carp-dk/carp-health-flutter/issues/74), PR [#452](https://github.com/carp-dk/carp-health-flutter/pull/452)
- Idempotent workout writes in `writeWorkoutData` and `writeWorkoutDataUUID` so re-writing with the same ID and a higher version replaces the existing workout instead of duplicating it: use `clientRecordId` and `clientRecordVersion` on Android (distance and calorie records use `<clientRecordId>:distance` and `<clientRecordId>:calories`, supports `startZoneOffset` and `endZoneOffset` up to ±18 hours) or `WorkoutMetadata.syncIdentifier` and `syncVersion` on iOS (providing only an ID or version throws `ArgumentError`) - PR [#485](https://github.com/carp-dk/carp-health-flutter/pull/485)
- iOS: Add `totalFlightsClimbed`, `totalSwimmingStrokeCount`, `duration` (excluding pauses, in seconds), `avgMets`, `elevationAscended`, `elevationDescended`, `indoorWorkout`, `weatherTemperature`, `weatherHumidity`, `averageSpeed`, `maximumSpeed`, and `workoutEvents` (`WorkoutEvent` with `WorkoutEventType`, `start`, and `end`) for workout metrics and events on `WorkoutHealthValue` (all `null` on Android) - PR [#495](https://github.com/carp-dk/carp-health-flutter/pull/495), PR [#522](https://github.com/carp-dk/carp-health-flutter/pull/522)
- Swimming workout support via `SwimmingDetails` (`poolLength` in meters for `SWIMMING_POOL`, `laps` as `List<SwimmingLap>` with `startTime`, `endTime`, and `SwimmingStrokeStyle`) and `totalSwimmingStrokeCount` (iOS only) in `writeWorkoutData` and `writeWorkoutDataUUID`, readable via `WorkoutHealthValue.swimming` (invalid pool lengths or overlapping/out-of-bounds laps throw `ArgumentError` before writing):
  - iOS: Saves pool location, lap length (`HKMetadataKeyLapLength`), lap events with stroke style (`kickboard` requires iOS 16+ and `other` maps to `unknown`), and stroke count. `SWIMMING_POOL` workouts with a pool length read back as `SWIMMING_POOL` (lengths converted to meters)
  - Android: Saves laps as Health Connect `ExerciseLap` records (with `poolLength` as lap length) and stroke styles as `SWIMMING_*` exercise segments (`kickboard` and `other` read back as `other`, `unknown` omits a segment). `swimming` is `null` if a swim has no laps. Health Connect has no stroke count or generic `SWIMMING` type
- `writeSleepSession()` to write a complete sleep session with validated `SleepSessionStage` entries (`SLEEP_AWAKE`, `SLEEP_AWAKE_IN_BED`, `SLEEP_ASLEEP`, `SLEEP_LIGHT`, `SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_OUT_OF_BED`, `SLEEP_UNKNOWN`) - Fixes [#526](https://github.com/carp-dk/carp-health-flutter/issues/526):
  - Android: Writes a single Health Connect sleep session with its stages, optional title, and notes
  - iOS: Writes in-bed samples (excluding out-of-bed stages) and per-stage sleep samples in one call (light, deep, and REM map to asleep before iOS 16; unknown/out-of-bed stages, title, and notes are not stored; sessions over 4 days throw `INVALID_ARGUMENT`)

### Changed (All Breaking)

- Raised minimum Dart SDK to `>=3.12.0 <4.0.0` and Flutter to `>=3.44.0`.
- Android: Updated `androidx.health.connect:connect-client` to `1.2.0-alpha06`, requiring Android `compileSdk` 37 and AGP 9.1.0 - PR [#491](https://github.com/carp-dk/carp-health-flutter/pull/491)
- Android: Data reads now throw `HealthPlatformException` when Health Connect returns an error instead of silently returning no data
- Android: `getChangesToken` and `getChanges` now throw `HealthPlatformException` when Health Connect returns an error
- iOS: Data reads now throw `HealthPlatformException` with classified platform error codes (`PERMISSION_DENIED`, `DEVICE_LOCKED`, `NOT_SUPPORTED`, `INVALID_ARGUMENT`, `DATA_TOO_LARGE`, or `HEALTH_ERROR`).
- `getTotalStepsInInterval` now returns `Future<int>` instead of `Future<int?>`, returning `0` when there are no steps and throwing `HealthPlatformException` on errors - Fixes [#237](https://github.com/carp-dk/carp-health-flutter/issues/237), Fixes [#282](https://github.com/carp-dk/carp-health-flutter/issues/282)
- iOS: `AudiogramHealthValue.leftEarSensitivities` and `rightEarSensitivities` are now `List<num?>` instead of `List<num>`
- Updated `getHealthIntervalDataFromTypes` return format:
  - Intervals without data are omitted. Do not expect a point for every interval!
  - All points return `NumericHealthValue` (including `SKIN_TEMPERATURE` and `ACTIVITY_INTENSITY`), holding sums for cumulative types, Health Connect intensity minutes for `ACTIVITY_INTENSITY`, and averages for other types
  - On Android, `HEART_RATE` now returns average BPM instead of sample count.
  - Sleep types return deduplicated duration in minutes within each interval (including sleep that began before `startDate`), with `sourceName` listing contributing apps in start order (bundle identifiers on iOS) and an empty `sourceId`
- `HealthDataPoint` and `HealthDataPoint.fromJson` now keep the `value` passed to them for sleep, headache, and mindfulness types instead of overwriting it with the duration in minutes (`HealthDataPoint.fromHealthDataPoint` still computes the duration for platform data). Pass the duration in minutes explicitly when creating these points yourself
- `HealthDataPoint.sourceDeviceId` returns device's ID (`identifierForVendor` on iOS, `Build.ID` on Android via `device_info_plus`)
- `HealthDataPoint.deviceModel` returns from the recording device instead of always being `null`. Note that because both fields participate in `HealthDataPoint ==`, points read in 14.0.0 will not equal points persisted by 13.x—compare fields excluding `sourceDeviceId` and `deviceModel` when matching against older stored data `HealthDataPoint.fromHealthDataPoint`, `HealthChange.fromMethodChannel`, and `HealthChangesResponse.fromMethodChannel` now accept an optional `sourceDeviceId`.
- iOS: Workout types that share a HealthKit activity type now map deterministically instead of choosing a name at random per app launch: they read as `RUNNING` (or `RUNNING_TREADMILL` for indoor runs), `CLIMBING`, or `SWIMMING` (`SWIMMING_POOL` or `SWIMMING_OPEN_WATER` when swimming location metadata is set). `RUNNING_TREADMILL` (saved as indoor unless `WorkoutMetadata.indoorWorkout` overrides it) and `SWIMMING_OPEN_WATER` now round-trip under the same name, `ROCK_CLIMBING` reads back as `CLIMBING`, and `SWIMMING_POOL` reads back as `SWIMMING` unless written with `SwimmingDetails.poolLength`. `writeWorkoutData` and `writeWorkoutDataUUID` now accept `RUNNING_TREADMILL` and `ROCK_CLIMBING` instead of throwing `HealthException` - Fixes [#473](https://github.com/carp-dk/carp-health-flutter/issues/473)
- iOS: `WorkoutSummary.workoutType` now uses the `HealthWorkoutActivityType` name (matching `WorkoutHealthValue.workoutActivityType`, e.g. `BIKING`, or `OTHER` for unmapped types) instead of HealthKit's raw type string (e.g. `cycling`)
- Android: Health Connect exercise types shared by multiple workout types now consistently report canonical names across workouts, routes, changes, and UUID reads: `DANCING` (for `CARDIO_DANCE`, `SOCIAL_DANCE`), `SKIING` (for `CROSS_COUNTRY_SKIING`, `DOWNHILL_SKIING`), and `WHEELCHAIR` (for `WHEELCHAIR_RUN_PACE`, `WHEELCHAIR_WALK_PACE`).
- `writeWorkoutData` and `writeWorkoutDataUUID` now throw `HealthException(HealthErrorCode.notSupported)` (`ARCHERY`, `CURLING`, and `WALKING_TREADMILL` on Android (previously returning `false`/empty string) and `BIKING_STATIONARY` or `WALKING_TREADMILL` on iOS) - PR [#530](https://github.com/carp-dk/carp-health-flutter/pull/530)
- Android: Workout `totalDistance`, `totalEnergyBurned`, and `totalSteps` now count only records written by the same app as the workout (matching iOS and preventing double-counting across watch and phone apps). Totals not written by that app are `null`. For other app's records read `DISTANCE_DELTA`, `TOTAL_CALORIES_BURNED`, or `STEPS` over the workout's time range - Fixes [#39](https://github.com/carp-dk/carp-health-flutter/issues/39), Fixes [#524](https://github.com/carp-dk/carp-health-flutter/issues/524), PR [#525](https://github.com/carp-dk/carp-health-flutter/pull/525)
- `writeHealthData` and `writeHealthDataUUID` now throw `ArgumentError` for types with dedicated write methods
- iOS: Requesting `WRITE` or `READ_WRITE` access for read-only HealthKit types or writing them via `writeHealthData`/`writeHealthDataUUID`, now throws `ArgumentError` instead of crashing or returning `false`/empty string
- Android: `writeHealthData` now returns `false` and `writeHealthDataUUID` returns an empty string when Health Connect rejects a value (such as `0` steps)
- iOS: `delete` with a sleep type or headache severity now deletes only your app's samples of that specific type instead of all sleep or headache samples in the range
- Android: Reading individual sleep stage types (`SLEEP_ASLEEP`, `SLEEP_AWAKE`, `SLEEP_AWAKE_IN_BED`, `SLEEP_LIGHT`, `SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_OUT_OF_BED`, `SLEEP_UNKNOWN`) via `getHealthDataFromTypes` and `getHealthDataPages` now returns stages starting within `[startTime, endTime]` (including stages from sessions starting up to 24 hours earlier), matching iOS instead of returning every stage of sessions starting in the range. `SLEEP_SESSION` reads are unchanged
- Android: Passing a `preferredUnits` entry that Android does not convert now throws `HealthException(HealthErrorCode.invalidArgument)` before reading instead of mislabeling values
- Android: Operations with `ACTIVITY_INTENSITY` now throw `HealthException(HealthErrorCode.notSupported)` up front on devices whose Health Connect lacks activity intensity support (e.g., Android 15 before SDK extension 16)
- Custom classes implementing `Health` or `HealthException` must implement the newly added members

### Deprecated

- **Breaking:** `getHealthAggregateDataFromTypes` is deprecated and throws `UnsupportedError` without calling the platform (it has been non-functional since Google Fit was removed). Migrate to `getHealthIntervalDataFromTypes`.

### Removed

- iOS: **Breaking:** Removed `TOTAL_CALORIES_BURNED` from iOS supported data types as HealthKit does not have a total calories type. Use `ACTIVE_ENERGY_BURNED` and `BASAL_ENERGY_BURNED` on iOS instead - Fixes [#483](https://github.com/carp-dk/carp-health-flutter/issues/483), Fixes [#486](https://github.com/carp-dk/carp-health-flutter/issues/486), PR [#484](https://github.com/carp-dk/carp-health-flutter/pull/484)

### Fixed

- `writeMeal` no longer drops `b1Thiamin` (it was previously sent under an unrecognized key on both platforms)
- `removeDuplicates` now deduplicates points with `metadata` (including all iOS samples and workout routes), ECGs, and audiograms by comparing nested maps and lists by value rather than identity
- Fixed `HealthDataPoint.deviceModel` from `HKDevice.model` on iOS and Health Connect's `Device.model` on Android - Fixes [#1](https://github.com/carp-dk/carp-health-flutter/issues/1), [#194](https://github.com/carp-dk/carp-health-flutter/issues/194), Fixes [#229](https://github.com/carp-dk/carp-health-flutter/issues/229), PR [#478](https://github.com/carp-dk/carp-health-flutter/pull/478)
- `WorkoutSummary.toString` no longer omits the comma after the workout type
- Android: Step records whose start and end times are equal no longer cause the entire read to fail on Android 14+ - Fixes [#513](https://github.com/carp-dk/carp-health-flutter/issues/513)
- Android: `HEART_RATE`, `SPEED`, and `SKIN_TEMPERATURE` reads no longer return out-of-range samples and now include in-range samples from records that started up to 24 hours before `startTime`
- Android: `getTotalStepsInInterval(includeManualEntry: false)` now counts all step records instead of stopping after the first 1,000
- Android: `getHealthIntervalDataFromTypes` no longer fails with `ClassCastException` or `"Unsupported value"` for mass, volume, and duration types (`WEIGHT`, `WATER`, sleep, `ACTIVITY_INTENSITY`), returning values in kilograms, liters, and minutes - Fixes [#298](https://github.com/carp-dk/carp-health-flutter/issues/298)
- Android: `getHealthDataByUUID` now returns `null` instead of throwing a `TypeError` when a record has no data for the requested type
- Android: Workouts are no longer omitted when distance, calorie, or step read permissions are missing. Unavailable totals (`READ_DISTANCE`, `READ_TOTAL_CALORIES_BURNED`, `READ_STEPS`) are returned as `null` - Fixes [#40](https://github.com/carp-dk/carp-health-flutter/issues/40), Fixes [#184](https://github.com/carp-dk/carp-health-flutter/issues/184), Fixes [#471](https://github.com/carp-dk/carp-health-flutter/issues/471), Fixes [#489](https://github.com/carp-dk/carp-health-flutter/issues/489), PR [#528](https://github.com/carp-dk/carp-health-flutter/pull/528)
- Android: Workout `totalDistance`, `totalEnergyBurned`, and `totalSteps` now sum all records in the workout instead of stopping after the first 1,000
- Android: Prevented duplicate, truncated, or infinitely looping reads (which could exhaust memory or Health Connect quota) when multiple records share the exact same millisecond start time across a page boundary. If more than 5,000 records share one millisecond, reads fail with `HealthErrorCode.unknown` instead of looping (see "Records that share a start time on Android" in README)
- Android: Fixed writes swapping `RecordingMethod.manual` and `RecordingMethod.active` when saving to Health Connect
- Android: `hasPermissions`, `revokePermissions`, and history, background, and feature availability checks no longer crash when Health Connect throws an error - Fixes [#116](https://github.com/carp-dk/carp-health-flutter/issues/116), Fixes [#149](https://github.com/carp-dk/carp-health-flutter/issues/149), Fixes [#150](https://github.com/carp-dk/carp-health-flutter/issues/150), PR [#533](https://github.com/carp-dk/carp-health-flutter/pull/533)
- Android: `writeHealthDataUUID` now checks device feature availability like `writeHealthData`, throwing `HealthException(HealthErrorCode.notSupported)` for `SKIN_TEMPERATURE` on unsupported devices instead of returning an empty string
- Android: `insertWorkoutRouteData` invalid locations now return `INVALID_ARGUMENT` 
- Android: `BIKING_STATIONARY`, `SOCCER`, `HOCKEY` (mapped to Health Connect ice hockey), and `PADDLE_SPORTS` (mapped to paddling, previously iOS-only) can now be written and read instead of failing as `OTHER` - PR [#477](https://github.com/carp-dk/carp-health-flutter/pull/477), PR [#530](https://github.com/carp-dk/carp-health-flutter/pull/530)
- Android: `HealthDataPoint.workoutSummary` is now populated for workouts (matching iOS, with `0` for missing totals) instead of being `null` - Fixes [#490](https://github.com/carp-dk/carp-health-flutter/issues/490), Fixes [#492](https://github.com/carp-dk/carp-health-flutter/issues/492), PR [#535](https://github.com/carp-dk/carp-health-flutter/pull/535)
- Android: Prevented `ClassCastException` crashes on cached Flutter engines when `MainActivity` extends `FlutterActivity` instead of `FlutterFragmentActivity`, added error logs fixes when permission launchers are unavailable - Fixes [#124](https://github.com/carp-dk/carp-health-flutter/issues/124), PR [#511](https://github.com/carp-dk/carp-health-flutter/pull/511)
- Android: Concurrent permission requests no longer overwrite an active Health Connect dialog or crash when it closes, dialog failures now use plugin error codes, and attaching to an already-started activity (e.g., add-to-app with a cached engine) logs an error instead of crashing with `IllegalStateException` - PR [#508](https://github.com/carp-dk/carp-health-flutter/pull/508)
- Android: `installHealthConnect` is now a no-op on Android 14+
- Android: `finishWorkoutRoute` no longer drops the workout session's rate of perceived exertion (RPE) when attaching a route
- Android: Fixed Android 14/15 Health Connect bug where reading `WORKOUT` or `WORKOUT_ROUTE` threw a `NullPointerException` when a session with a route fell outside the current page (see "Workouts on Android 14 and 15" in README)
- iOS: Fixed a crash when reading audiograms where only one ear was tested at a given frequency
- iOS: `requestAuthorization` no longer crashes when none of the requested types exist on the current iOS version (e.g., `POWER` before iOS 17) and returns `false` without showing a permission sheet
- iOS: `getHealthIntervalDataFromTypes` no longer crashes for `HEART_RATE` and other time-averaged HealthKit types
- iOS: `preferredUnits` now supports `CENTIMETER` and `MILLIMOLES_PER_LITER` and throws `HealthPlatformException(HealthErrorCode.invalidArgument)` for incompatible units instead of crashing
- iOS: ECG samples with unreadable voltage measurements now fail the read instead of being skipped
- iOS: Invalid writes that previously caused native HealthKit crashes now fail up front with `PlatformException` (`INVALID_ARGUMENT`), including durations over 4 days or ending in year 4001+, incompatible or missing units in `writeHealthData`/`writeWorkoutData` (and `*UUID` variants), and `writeMeal` calls with no HealthKit-supported nutrients
- iOS: `writeAudiogram` no longer hangs when `metadata` omits `HKDeviceName` or `HKExternalUUID` (optional), and validates frequency count (max 30), ordering, ranges, duration (max 4 days), and string metadata up front with `PlatformException` (`INVALID_ARGUMENT`)
- iOS: `writeHealthDataUUID` no longer crashes for types or units unavailable on the current iOS version and returns an empty string (matching `writeHealthData` returning `false`)
- iOS: `writeHealthDataUUID` and `writeWorkoutDataUUID` no longer send two replies for a single call
- iOS: `writeHealthDataUUID` with `MINDFULNESS` now returns the saved session UUID (or an empty string on failure) instead of `"true"` or `"false"`
- iOS: `sourceName` in `getHealthIntervalDataFromTypes` quantity points - Fixes [#1201](https://github.com/cph-cachet/flutter-plugins/issues/1201). Lists sorted contributing bundle identifiers joined with `", "` (with an empty `sourceId`, matching Android)
- iOS: `writeHealthDataUUID` on iOS 15 now maps `SLEEP_LIGHT`, `SLEEP_DEEP`, and `SLEEP_REM` to asleep
- iOS: `writeMeal` no longer fails with `WRITE_ERROR` when `name` is omitted
- iOS: `insertWorkoutRouteData` no longer stores missing altitudes as `0 m` (which caused false climbs and descents). Locations without altitude now read back without `altitude` or `verticalAccuracy`, matching Android
- Fixes [#51](https://github.com/carp-dk/carp-health-flutter/issues/51)

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
