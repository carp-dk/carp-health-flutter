# Health

Enables reading and writing health data from/to [Apple Health](https://www.apple.com/health/) and [Google Health Connect](https://health.google/health-connect-android/).

> **NOTE:** Google has deprecated the Google Fit API. According to the [documentation](https://developers.google.com/fit/android), as of **May 1st 2024** developers cannot sign up for using the API. As such, this package has removed support for Google Fit as of version 11.0.0 and users are urged to upgrade as soon as possible.

The plugin supports:

- handling permissions to access health data using the `hasPermissions`, `requestAuthorization`, `revokePermissions` methods, and on iOS `getRequestStatusForAuthorization`.
- reading health data using the `getHealthDataFromTypes` method, or only the newest data points of each type with its `limit`.
- reading large amounts of health data page by page using the `getHealthDataPages` method.
- reading health data aggregated over time intervals using the `getHealthIntervalDataFromTypes` method.
- writing health data using the `writeHealthData` method.
- writing workouts, also swims with their pool length, laps and stroke styles, using the `writeWorkoutData` method.
- writing workout routes on iOS and Android using the `startWorkoutRoute` / `insertWorkoutRouteData` / `finishWorkoutRoute` methods.
- writing a sleep session with its stages, such as a night of sleep, on iOS & Android using the `writeSleepSession` method.
- writing a mindfulness session, such as a meditation, on iOS & Android using the `writeMindfulnessSession` method.
- writing meals on iOS (Apple Health) & Android using the `writeMeal` method.
- writing audiograms on iOS using the `writeAudiogram` method.
- writing blood pressure data using the `writeBloodPressure` method.
- accessing total step counts using the `getTotalStepsInInterval` method.
- cleaning up duplicate data points via the `removeDuplicates` method.
- removing data of a given type in a selected period of time using the `delete` method.

Note that on Android 13 and lower, the phone **needs** the [Health Connect](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata&hl=en) app from Google Play: check `getHealthConnectSdkStatus` and, if it is `sdkUnavailableProviderUpdateRequired`, offer `installHealthConnect`. From Android 14 on, Health Connect is part of Android and updates with the system, and `installHealthConnect` does nothing. `sdkUnavailable` means that Health Connect cannot be used here: Android older than 9, a work profile (on any Android version), private space (Android 15 and later), or a device without Health Connect. Hide the Health Connect integration then, rather than offering to install it.

See the tables below for supported health and workout data types.

## Setup

### Apple Health (iOS)

First, add the following 2 entries to the `Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>We will sync your data with the Apple Health app to give you better insights</string>
<key>NSHealthUpdateUsageDescription</key>
<string>We will sync your data with the Apple Health app to give you better insights</string>
```

Then, open your Flutter project in Xcode by right clicking on the "ios" folder and selecting "Open in Xcode". Next, enable "HealthKit" by adding a capability inside the "Signing & Capabilities" tab of the Runner target's settings.

The iOS side of the plugin requires **iOS 15.0 or later** and ships both as a Swift package (`ios/health`) and as a CocoaPods pod. Apps with [Swift Package Manager](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers) enabled (Flutter 3.44 or later) get the Swift package, everything else keeps using CocoaPods. No extra setup is needed in either case.

### Google Health Connect (Android)

The plugin uses Health Connect's client library `androidx.health.connect:connect-client` 1.2.0-alpha06, which requires apps to compile against **Android API 37** with the **Android Gradle Plugin (AGP) 9.1.0 or later**. With Flutter 3.47, AGP 9.1 needs **Gradle 9.3.1 or later**. With a lower API level or AGP version, the build fails when it checks the AAR metadata of `connect-client`. Flutter 3.47's `flutter.compileSdkVersion` is 36, so set the API level in the app, as the example app does:

```kotlin
// android/settings.gradle.kts
plugins {
    id("com.android.application") version "9.1.0" apply false
    // ...
}

// android/app/build.gradle.kts
android {
    compileSdk = 37
    // ...
}
```

```properties
# android/gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-9.3.1-all.zip
```

The plugin needs Flutter 3.44 or later and does not apply the Kotlin Gradle plugin: its Kotlin is compiled by AGP's [built-in Kotlin](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin), or, in an app that sets `android.builtInKotlin=false`, by the Kotlin Gradle plugin that Flutter applies. The example app uses built-in Kotlin (`android.builtInKotlin=true`, Flutter 3.47 or later) and keeps `id("org.jetbrains.kotlin.android") version "2.3.20" apply false` in `settings.gradle.kts` to choose the Kotlin version (Flutter needs 2.2.20 or later).

Health Connect requires the following lines in the `AndroidManifest.xml` file (see also the example app):

```xml
<!-- Check whether Health Connect is installed or not -->
<queries>
  <package android:name="com.google.android.apps.healthdata" />
  <intent>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
  </intent>
</queries>
```

In the Health Connect permissions activity there is a link to your privacy policy. You need to grant the Health Connect app access in order to link back to your privacy policy. In the example below, you should either replace `.MainActivity` with an activity that presents the privacy policy or have the Main Activity route the user to the policy. This step may be required to pass Google app review when requesting access to sensitive permissions.

```xml
<activity-alias
     android:name="ViewPermissionUsageActivity"
     android:exported="true"
     android:targetActivity=".MainActivity"
     android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
        <intent-filter>
            <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
            <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
        </intent-filter>
</activity-alias>
```

For each data type you want to access, the READ and WRITE permissions need to be added to the `AndroidManifest.xml` file. The list of [permissions](https://developer.android.com/health-and-fitness/guides/health-connect/plan/data-types#permissions) can be found here on the [data types](https://developer.android.com/health-and-fitness/guides/health-connect/plan/data-types) page.

An example of asking for permission to read and write heart rate data is shown below and more examples can also be found in the example app.

```xml
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.WRITE_HEART_RATE"/>
```

If you plan to read or write Activity Intensity records (the `HealthDataType.ACTIVITY_INTENSITY` type, which not every Health Connect has: see [Health Connect features](#health-connect-features)), be sure to add the corresponding Health Connect permissions introduced with that data type:

```xml
<uses-permission android:name="android.permission.health.READ_ACTIVITY_INTENSITY"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVITY_INTENSITY"/>
```

VO2 max (`HealthDataType.VO2_MAX`) and mindfulness sessions (`HealthDataType.MINDFULNESS`, see [Writing a mindfulness session](#writing-a-mindfulness-session-ios--android)) need these permissions:

```xml
<uses-permission android:name="android.permission.health.READ_VO2_MAX"/>
<uses-permission android:name="android.permission.health.WRITE_VO2_MAX"/>
<uses-permission android:name="android.permission.health.READ_MINDFULNESS"/>
<uses-permission android:name="android.permission.health.WRITE_MINDFULNESS"/>
```

Workouts (`HealthDataType.WORKOUT`) need `READ_EXERCISE` and `WRITE_EXERCISE`, which also cover the laps of swims. The `totalDistance`, `totalEnergyBurned` and `totalSteps` of a workout are read only with `READ_DISTANCE`, `READ_TOTAL_CALORIES_BURNED` and `READ_STEPS` respectively (for a workout the app wrote itself, `WRITE_DISTANCE`, `WRITE_TOTAL_CALORIES_BURNED` and `WRITE_STEPS` are enough), and are `null` without them, so an app that does not need them can leave them out. A workout written with a `totalDistance` or a `totalEnergyBurned` is saved with a distance or energy record of its own, which needs `WRITE_DISTANCE` or `WRITE_TOTAL_CALORIES_BURNED`: without it, the workout is not written (`writeWorkoutData` returns `false`).

#### Health Connect features

Health Connect added some data types and permissions after its first release. On Android 14 and later they come with Android or with Google Play system updates (SDK extensions), on Android 13 and lower with updates of the Health Connect app. Check them before use: without the feature, reads and writes of the type throw a `HealthException` with `HealthErrorCode.notSupported` before Health Connect is called.

| Feature                                                               | Android 14 and later                                  | Check                                                                                             |
| --------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `SKIN_TEMPERATURE`, reading health data history and in the background | Android 15, or Android 14 with SDK extension 13       | `isSkinTemperatureAvailable`, `isHealthDataHistoryAvailable`, `isHealthDataInBackgroundAvailable` |
| `MINDFULNESS`                                                         | Android 16, or Android 14 or 15 with SDK extension 15 | `isMindfulnessSessionAvailable`                                                                   |
| `ACTIVITY_INTENSITY`                                                  | Android 16, or Android 14 or 15 with SDK extension 16 | `isActivityIntensityAvailable`                                                                    |

On Android 13 and lower, each needs a recent Health Connect app. A base Android 15 device (SDK extension 13) therefore has skin temperature and the history and background reads, but neither mindfulness sessions nor activity intensity until a system update brings them.

`hasPermissions` is no feature check. Android 15 at SDK extension 13 already defines `READ_MINDFULNESS` and `WRITE_MINDFULNESS`, so they can be granted (for example with `adb shell pm grant`) and `hasPermissions([HealthDataType.MINDFULNESS])` can return `true` while `isMindfulnessSessionAvailable()` returns `false`. The Health Connect permission dialog does not offer them there: a `requestAuthorization` call for only `MINDFULNESS` closes at once and returns `false`, and in a call with other types the dialog shows only those. The activity intensity permissions are not defined before SDK extension 16, so there `hasPermissions` returns `false` for `ACTIVITY_INTENSITY`. Check the feature with the method in the table.

By default, Health Connect restricts read data to 30 days from when permission has been granted. The records the app wrote itself are not limited this way: they were read without `READ_HEALTH_DATA_HISTORY` on Android 15 and 17.

You can check and request access to historical data using the `isHealthDataHistoryAuthorized` and `requestHealthDataHistoryAuthorization` methods, respectively, where `isHealthDataHistoryAvailable` is `true`.

The above methods require the following permission to be declared:

```xml
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY"/>
```

Accessing fitness data (e.g. Steps) requires permission to access the "Activity Recognition" API. To set it add the following line to your `AndroidManifest.xml` file.

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
```

The location permissions below are needed only to record workout routes (see [Writing workout routes](#writing-workout-routes-ios--android)), not for workouts or their distance.

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

Because this is labeled as a `dangerous` protection level, the permission system will not grant it automatically and it requires the user's action.
You can prompt the user for it using the [permission_handler](https://pub.dev/packages/permission_handler) plugin.
Follow the plugin setup instructions and add the following line before requesting the data:

```dart
await Permission.activityRecognition.request();
await Permission.location.request();
```

Finally, an `intent-filter` needs to be added to the `.MainActivity` activity.

```xml
<activity
  android:name=".MainActivity"
  android:exported="true"

  ....

  <!-- Intention to show Permissions screen for Health Connect API -->
  <intent-filter>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
  </intent-filter>
</activity>
```

There's a `debug`, `main` and `profile` version which are chosen depending on how you start your app. In general, it's sufficient to add permission only to the `main` version.

#### MainActivity: FlutterFragmentActivity

This plugin uses `registerForActivityResult` when requesting permissions from Health Connect, which needs a `ComponentActivity`.
For that to work, on every Android version, the app's main activity must extend `FlutterFragmentActivity` instead of `FlutterActivity`.
Otherwise `requestAuthorization`, `requestHealthDataHistoryAuthorization` and `requestHealthDataInBackgroundAuthorization` return `false`, and the plugin logs an error that names the activity.

In your MainActivity.kt file, update the `MainActivity` class so that it extends `FlutterFragmentActivity` instead of the default `FlutterActivity`:

```kotlin
...
import io.flutter.embedding.android.FlutterFragmentActivity
...

class MainActivity: FlutterFragmentActivity() {
...
}
```

#### Android X

Replace the content of the `android/gradle.properties` file with the following lines:

```bash
org.gradle.jvmargs=-Xmx1536M
android.enableJetifier=true
android.useAndroidX=true
```

## Usage

See the example app for detailed examples of how to use the Health API.

A instance of the Health plugin is create using the `Health()` constructor and is subsequently configured calling the `configure` method. Once configured, the plugin can be used for handling permissions and getting and adding data to Apple Health or Google Health Connect.
Below is a simplified flow of how to use the plugin.

```dart

  // Global Health instance
  final health = Health();

  // configure the health plugin before use.
  await health.configure();


  // define the types to get
  var types = [
    HealthDataType.STEPS,
    HealthDataType.BLOOD_GLUCOSE,
  ];

  // requesting access to the data types before reading them
  bool requested = await health.requestAuthorization(types);

  var now = DateTime.now();

  // fetch health data from the last 24 hours
  List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
    types: types,
    startTime: now.subtract(Duration(days: 1)),
    endTime: now,
  );

  // request permissions to write steps and blood glucose
  types = [HealthDataType.STEPS, HealthDataType.BLOOD_GLUCOSE];
  var permissions = [
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE
  ];
  await health.requestAuthorization(types, permissions: permissions);

  // write steps over the last 20 minutes (on Android, steps need an endTime after the startTime)
  // and a blood glucose value measured now
  var earlier = now.subtract(Duration(minutes: 20));
  bool success = await health.writeHealthData(
    value: 10, type: HealthDataType.STEPS, startTime: earlier, endTime: now);
  success = await health.writeHealthData(
    value: 3.1, type: HealthDataType.BLOOD_GLUCOSE, startTime: now);

  // you can also specify the recording method to store in the metadata (default is RecordingMethod.automatic)
  // on iOS only `RecordingMethod.automatic` and `RecordingMethod.manual` are supported
  // Android additionally supports `RecordingMethod.active` and `RecordingMethod.unknown`
  success &= await health.writeHealthData(
    value: 10,
    type: HealthDataType.STEPS,
    startTime: earlier,
    endTime: now,
    recordingMethod: RecordingMethod.manual,
  );

  // get the number of steps for today (0 if there are none)
  var midnight = DateTime(now.year, now.month, now.day);
  int steps = await health.getTotalStepsInInterval(midnight, now);
```

`true` from `requestAuthorization` does not mean that every requested permission was granted. On Android it means that at least one of the requested permissions is granted when the Health Connect permission dialog closes, also one granted before; it is `false` when none is, when the dialog cannot be shown (see [MainActivity: FlutterFragmentActivity](#mainactivity-flutterfragmentactivity)) or while another permission request waits for the dialog. The user may allow some permissions and not others, and the dialog does not offer those of a type that the device's Health Connect does not have (see [Health Connect features](#health-connect-features)). `hasPermissions` returns `true` only when every type given to it has its permission, so ask it about one type at a time to find the missing ones. On iOS, `true` only means that HealthKit handled the request (see [Authorization on iOS](#authorization-on-ios)).

### Authorization on iOS

HealthKit does not tell apps whether the user granted read access, so on iOS `hasPermissions` returns `null` for read access, and `true` from `requestAuthorization` does not mean that read access was granted: it means that HealthKit completed the request, whether it showed the authorization sheet or not (`false` means that HealthKit reported an error, or that this iOS version has none of the types). A denied read returns only the samples the app saved itself (see [Reads without the read permission](#reads-without-the-read-permission-ios--android)). `getRequestStatusForAuthorization` tells whether `requestAuthorization` with the same types and permissions would show the authorization sheet (`HealthAuthorizationRequestStatus.shouldRequest`) or not (`unnecessary`), so an app can tell a first request from one the user has already answered:

```dart
final status = await health.getRequestStatusForAuthorization(types, permissions: permissions);
if (status == HealthAuthorizationRequestStatus.shouldRequest) {
  // for example, first explain why the app asks for the data
  await health.requestAuthorization(types, permissions: permissions);
}
```

It throws a `PlatformException` when HealthKit cannot determine the status, and returns `null` on Android, where `hasPermissions` tells whether the permissions were granted.

HealthKit lets apps only read `ELECTROCARDIOGRAM`, `HIGH_HEART_RATE_EVENT`, `LOW_HEART_RATE_EVENT`, `IRREGULAR_HEART_RATE_EVENT`, `WALKING_HEART_RATE`, `ATRIAL_FIBRILLATION_BURDEN`, `APPLE_STAND_HOUR`, `APPLE_MOVE_TIME`, `APPLE_STAND_TIME`, `EXERCISE_TIME`, `SLEEP_WRIST_TEMPERATURE`, `WALKING_ASYMMETRY_PERCENTAGE`, `APPLE_WALKING_STEADINESS` and `APPLE_SLEEPING_BREATHING_DISTURBANCES`, and raises an exception that crashes the app when write access to one of them is requested. `requestAuthorization` and `getRequestStatusForAuthorization` therefore throw an `ArgumentError` for `WRITE` or `READ_WRITE` access to them, and so do `writeHealthData` and `writeHealthDataUUID` for them on iOS.

### Reads without the read permission (iOS & Android)

In `getHealthDataFromTypes` and `getHealthDataPages`, a missing read permission is not an error: the read returns only the data the app wrote itself.

- **Android:** Health Connect lets an app read the records it wrote with the type's write permission. Such a read returns the app's own records, and every page of it has `HealthDataPage.readPermissionDenied` set. Without the write permission either, the type has one empty page with `readPermissionDenied`. The app's own heart rate is read in time slices of about `pageSize` samples, as with the read permission. Health Connect counts an app's own samples without the read permission only from Android 14 QPR2 on, and in the background only with `READ_HEALTH_DATA_IN_BACKGROUND`; where it refuses (and possibly in the Health Connect app on Android 13 and lower), the read goes record by record instead, which costs many more calls (see [Health Connect limits](#health-connect-limits)). The first page decides this, so a heart rate read that started in the foreground can fail with `HealthErrorCode.permissionDenied` on a later page once the app is in the background: for heart rate reads that may go on in the background, also of the app's own records, request `READ_HEALTH_DATA_IN_BACKGROUND` (see [Android: Reading Health Data in Background](#android-reading-health-data-in-background)). The app's own records are not limited to the 30 days of history that Health Connect otherwise allows without `READ_HEALTH_DATA_HISTORY`. `getHealthDataByUUID` returns the app's own record and `null` for another app's, and throws a `HealthPlatformException` with `HealthErrorCode.permissionDenied` without either permission. The totals of a workout the app wrote are read with the write permission of each total's type. `getHealthIntervalDataFromTypes` and `getTotalStepsInInterval` cover the data of every app, so without the read permission they throw `permissionDenied`, also with the write permission.
- **iOS:** HealthKit hides a denied read: reads, `getHealthIntervalDataFromTypes` and `getTotalStepsInInterval` see only the samples the app saved (0 steps if none), and `getHealthDataByUUID` returns `null` for the samples of other apps. A type the app never requested authorization for throws a `HealthPlatformException` with `HealthErrorCode.permissionDenied` (HealthKit error code 5). On iOS 27 the user can share only a limited window of recent history; older samples then do not appear in any read. HealthKit's `getEarliestAuthorizedSampleDate(for:completion:)` tells the start of that window, which the plugin does not expose.

### Writing workouts (iOS & Android)

`writeWorkoutData` writes a workout, and `writeWorkoutDataUUID` writes one and returns its UUID:

```dart
bool saved = await health.writeWorkoutData(
  activityType: HealthWorkoutActivityType.RUNNING,
  start: start,
  end: start.add(const Duration(minutes: 30)),
  totalDistance: 5000, // in meters
  totalEnergyBurned: 300, // in kilocalories
  title: 'Morning run', // Android only
  metadata: const WorkoutMetadata(workoutBrandName: 'My App'), // iOS only
);
```

- On iOS, `totalDistance` and `totalEnergyBurned` are stored only on the workout (HealthKit's totals of the `HKWorkout`), without samples, so they do not appear in reads or intervals of `ACTIVE_ENERGY_BURNED` or the `DISTANCE_*` types. On Android they are a `DISTANCE_DELTA` and a `TOTAL_CALORIES_BURNED` record of their own (see below).
- `metadata` is HealthKit metadata of the workout, which Android ignores: a `WorkoutMetadata` with its brand name, whether it was indoors (`indoorWorkout`), whether it was a group fitness class or coached, and its sync identifier and version (see below). HealthKit lets only Apple's apps mark a workout as an Apple Fitness+ session, so `WorkoutMetadata` has no field for it. A run written with `WorkoutMetadata(indoorWorkout: true)` reads back as `RUNNING_TREADMILL` (see [Workout Types](#workout-types)).
- On Android, `startZoneOffset` and `endZoneOffset` set the offsets from UTC of the local time at the start and at the end of the workout, at most 18 hours either way (a larger offset throws an `ArgumentError`). Without them, the workout's records get Health Connect's default. iOS ignores them.
- A workout type that the platform has no workout type for, such as `ARCHERY` on Android or `DANCING` on iOS, throws a `HealthException` with `HealthErrorCode.notSupported`.

**Writing a workout again.** To write a workout again without adding a copy, for example after the user edited it, give it an id and a version: on Android `clientRecordId` and `clientRecordVersion`, as for `writeHealthData`, and on iOS `WorkoutMetadata.syncIdentifier` and `syncVersion` (HealthKit's `HKMetadataKeySyncIdentifier` and `HKMetadataKeySyncVersion`). Each platform ignores the other's. A workout written with the id of a workout this app wrote before replaces that workout if its version is greater, and is not added as a copy. An id without its version, or a version without its id, throws an `ArgumentError`.

```dart
await health.writeWorkoutData(
  activityType: HealthWorkoutActivityType.RUNNING,
  start: start,
  end: start.add(const Duration(minutes: 30)),
  totalDistance: 5100,
  clientRecordId: 'run-42', // Android
  clientRecordVersion: 2,
  metadata: const WorkoutMetadata(syncIdentifier: 'run-42', syncVersion: 2), // iOS
);
```

On Android, the workout's distance and energy burned are records of their own, with the client record ids `<clientRecordId>:distance` and `<clientRecordId>:calories` and the workout's version, so a rewrite without a distance or energy keeps the one written before. To delete such a workout on Android, call `deleteByClientRecordId(dataTypeKey: HealthDataType.WORKOUT, clientRecordId: 'run-42')`, and the same for `DISTANCE_DELTA` with `'run-42:distance'` and for `TOTAL_CALORIES_BURNED` with `'run-42:calories'`.

**Reading workouts.** Reads return a workout as a `WORKOUT` data point whose value is a `WorkoutHealthValue`, with the workout's `workoutActivityType`, `totalDistance` (in meters), `totalEnergyBurned` (in kilocalories) and, on Android, `totalSteps` (`null` on iOS). On iOS the totals are the workout's own, and `totalEnergyBurned` is its active energy. On Android `totalEnergyBurned` is Health Connect's total calories (active and basal), and these totals count only the records of the app that wrote the workout, so an activity that two apps recorded (for example a watch app and the phone) does not count twice. A total is `null` when that app wrote no such records or the read permission for it is missing (for a workout this app wrote, its write permission is enough); read `DISTANCE_DELTA`, `TOTAL_CALORIES_BURNED` or `STEPS` over the workout's time to count the data of other apps too. On iOS the value also holds what HealthKit records about the workout: `totalFlightsClimbed`, `totalSwimmingStrokeCount`, `duration` (its time without pauses, in seconds), `avgMets`, `elevationAscended`, `elevationDescended`, `indoorWorkout`, `weatherTemperature`, `weatherHumidity`, `averageSpeed`, `maximumSpeed` and `workoutEvents`: its pauses, laps, segments and other `WorkoutEvent`s, each with a `WorkoutEventType`, a `start` and an `end`. These are `null` when the workout has none, and always on Android. `swimming` holds the pool length and laps of a swim on both platforms (see [Swimming workouts](#swimming-workouts)). The data point's `workoutSummary` holds the name of the workout type and the totals on both platforms, with 0 for a missing total.

#### Swimming workouts

`writeWorkoutData` and `writeWorkoutDataUUID` take the pool length and the laps of a swim in `swimming`, and its number of strokes in `totalSwimmingStrokeCount` (iOS only). For example, four 25 m lengths in three stroke styles:

```dart
final start = DateTime(2026, 11, 10, 7, 0);
SwimmingLap lap(int minute, SwimmingStrokeStyle strokeStyle) => SwimmingLap(
  startTime: start.add(Duration(minutes: minute)),
  endTime: start.add(Duration(minutes: minute + 1)),
  strokeStyle: strokeStyle,
);

bool saved = await health.writeWorkoutData(
  activityType: HealthWorkoutActivityType.SWIMMING_POOL,
  start: start,
  end: start.add(const Duration(minutes: 4)),
  totalDistance: 100,
  swimming: SwimmingDetails(
    poolLength: 25, // in meters
    laps: [
      lap(0, SwimmingStrokeStyle.freestyle),
      lap(1, SwimmingStrokeStyle.freestyle),
      lap(2, SwimmingStrokeStyle.backstroke),
      lap(3, SwimmingStrokeStyle.breaststroke),
    ],
  ),
  totalSwimmingStrokeCount: 72, // iOS only
);
```

A `SwimmingDetails` holds the `poolLength` in meters, for `SWIMMING_POOL` only, and the `laps`, each a `SwimmingLap` with a `startTime`, an `endTime` and a `strokeStyle`: a `SwimmingStrokeStyle` (`unknown` by default, `mixed`, `freestyle`, `backstroke`, `breaststroke`, `butterfly`, `kickboard` or `other`). Swimming details are for `SWIMMING_POOL` and `SWIMMING_OPEN_WATER` workouts and, on iOS, `SWIMMING` ones. Reads return them in `WorkoutHealthValue.swimming`, also for the swims that other apps and watches wrote, and the stroke count in `WorkoutHealthValue.totalSwimmingStrokeCount`. What each platform stores and reads back:

|                                       | iOS (HealthKit)                                                                                                                  | Android (Health Connect)                                                                                                  |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Pool length                           | Saved as the lap length of the workout (`HKMetadataKeyLapLength`) with a pool location; read in meters (25 yards read as 22.86) | Saved as the length of each lap, so it is lost without laps; read as the length that all laps share, `null` if they differ |
| Pool length of an open water swim     | Rejected                                                                                                                         | Rejected; always reads back `null`                                                                                        |
| `SWIMMING_POOL` without a pool length | Saved without a location; reads back as `SWIMMING`                                                                               | Stays `SWIMMING_POOL`                                                                                                     |
| Laps                                  | Lap events of the workout; they also appear in `workoutEvents`, without stroke style                                             | `ExerciseLap`s of the session                                                                                             |
| Stroke styles                         | Saved with each lap; `kickboard` needs iOS 16 (`unknown` before); `other` is stored as `unknown`                                 | Saved as segments over the laps; `unknown` stores none; `kickboard` and `other` both read back as `other`                 |
| Stroke count                          | The workout's total, read as `totalSwimmingStrokeCount`                                                                          | Not stored                                                                                                                |
| `SWIMMING`                            | Supported                                                                                                                        | Not supported (`HealthErrorCode.notSupported`)                                                                            |

Both write methods throw an `ArgumentError` before anything is written if:

- `swimming` or `totalSwimmingStrokeCount` is given for a workout that is not a swim, or `totalSwimmingStrokeCount` is negative;
- `poolLength` is given for a workout that is not `SWIMMING_POOL`, or is not more than 0 and at most 1000 meters;
- a lap does not start before it ends or is not inside the workout, or the laps are not sorted by start time or overlap (a lap may start where the lap before it ends).

`WorkoutHealthValue.swimming` is `null` for other workouts, and for a swim with neither a known pool length nor laps (on Android, for a swim without laps). Laps come back sorted by start time, and a lap without a stroke style reads as `unknown`. On iOS, the laps are the workout's lap events: its sets (segments) and pauses are not laps and are only in `workoutEvents`, and the laps that an Apple Watch recorded before watchOS 4 have no duration. On Android, a lap reads with the stroke style of the swimming segment it starts in, as the segments of other apps need not match their laps.

### Writing workout routes (iOS & Android)

1. Request share/read permissions for both `HealthDataType.WORKOUT` and `HealthDataType.WORKOUT_ROUTE`, and ensure location permissions are granted (iOS: Core Location permissions; Android: `ACCESS_FINE_LOCATION` or `ACCESS_COARSE_LOCATION`).
2. When the workout session starts, open a builder with `final builderId = await health.startWorkoutRoute();`.
3. Collect GPS samples using `CLLocationManager` (or an equivalent service) and periodically push ordered batches of `WorkoutRouteLocation` values via `insertWorkoutRouteData`.
4. Save the workout itself with `writeWorkoutDataUUID`, which returns the workout's UUID.
5. Call `finishWorkoutRoute(builderId: builderId, workoutUuid: workoutUuid, metadata: {...})` to commit the route, or `discardWorkoutRoute(builderId)` if the session is cancelled.

> **Health Connect note:** Like other Health Connect reads, routes are read only while your app is
> in the foreground, unless it also has `READ_HEALTH_DATA_IN_BACKGROUND` (see
> [Android: Reading Health Data in Background](#android-reading-health-data-in-background)). To read
> the routes of other apps, your app also needs the *Exercise routes* permission
> (`READ_EXERCISE_ROUTES`). Without it, such a route is read as a `WORKOUT_ROUTE` data point without
> locations whose `metadata` has `route_requires_consent: true` (Health Connect's `ConsentRequired`).
> `requestAuthorization` does not request this permission, and the plugin does not launch Health
> Connect's `ExerciseRouteRequestContract`, so the user has to grant "Always allow" for
> *Exercise routes* in the Health Connect app
> (`Health Connect → App permissions → Your app → Exercise routes`).
> Also remember to declare the following permissions in your Android manifest:
> - `<uses-permission android:name="android.permission.health.READ_EXERCISE_ROUTES"/>`
> - `<uses-permission android:name="android.permission.health.WRITE_EXERCISE_ROUTE"/>`
> - `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>` (or `ACCESS_COARSE_LOCATION`)

### Writing a night of sleep (iOS & Android)

`writeSleepSession` writes a sleep session, such as a night, with its stages in one call. Each stage is a `SleepSessionStage` of one of the types `SLEEP_AWAKE`, `SLEEP_AWAKE_IN_BED`, `SLEEP_ASLEEP`, `SLEEP_LIGHT`, `SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_OUT_OF_BED` and `SLEEP_UNKNOWN`. The stages need not cover the whole session, but they must lie inside it, be sorted by start time and not overlap; otherwise `writeSleepSession` throws an `ArgumentError` before anything is written. All sleep types share one permission on each platform, so request write access to one of them, for example `HealthDataType.SLEEP_ASLEEP` (on Android, declare `android.permission.health.WRITE_SLEEP`).

```dart
final bedtime = DateTime(2026, 11, 9, 23, 0);
DateTime at(int minutes) => bedtime.add(Duration(minutes: minutes));

bool saved = await health.writeSleepSession(
  startTime: bedtime,
  endTime: at(480),
  stages: [
    SleepSessionStage(type: HealthDataType.SLEEP_AWAKE_IN_BED, startTime: at(0), endTime: at(20)),
    SleepSessionStage(type: HealthDataType.SLEEP_LIGHT, startTime: at(20), endTime: at(120)),
    SleepSessionStage(type: HealthDataType.SLEEP_DEEP, startTime: at(120), endTime: at(200)),
    SleepSessionStage(type: HealthDataType.SLEEP_REM, startTime: at(200), endTime: at(260)),
    SleepSessionStage(type: HealthDataType.SLEEP_LIGHT, startTime: at(260), endTime: at(470)),
    SleepSessionStage(type: HealthDataType.SLEEP_AWAKE, startTime: at(470), endTime: at(480)),
  ],
  title: 'Night', // stored on Android only, as are notes
);
```

- **Android** stores one Health Connect sleep session with its stages, title and notes. Reads return the session as a `SLEEP_SESSION` data point and each stage as a data point of its type, without the title and notes. A sleep type written with `writeHealthData` is a session of its own, so a night written stage by stage that way shows up as many sessions.
- **iOS** saves the session in one call as sleep analysis samples, as HealthKit has no sleep sessions: in-bed samples for the session except its `SLEEP_OUT_OF_BED` stages, read as `SLEEP_IN_BED`, and a sample for each stage, read as the stage's type. The exceptions: `SLEEP_AWAKE_IN_BED` stages are read as `SLEEP_AWAKE`; before iOS 16, light, deep and REM sleep are saved and read as `SLEEP_ASLEEP`; and `SLEEP_OUT_OF_BED` and `SLEEP_UNKNOWN` stages get no sample of their own (an unknown stage stays time in bed). The title and notes are not stored, and iOS has no `SLEEP_SESSION` type. HealthKit accepts at most 4 days for a sleep sample, so a longer session throws a `PlatformException` with code `INVALID_ARGUMENT` before anything is saved.

To remove a session, call `delete` over its time range. On Android, any sleep type deletes the app's sleep sessions in that range with all their stages. On iOS, `delete` removes only the app's samples of the type given, so delete `SLEEP_IN_BED` and each type the stages are read as.

Reads return a sleep data point when it starts in the range: a stage when the stage starts in it, whichever session it belongs to, and on Android a `SLEEP_SESSION` when the session starts in it. Reads of consecutive ranges therefore return each point once; to read a whole night, read up to its end. On Android, the stages of sessions that began up to 24 hours before `startTime` are found, and the stages of one session come together, so the stages of overlapping sessions (from one app or several) are not in one time order.

### Writing a mindfulness session (iOS & Android)

`writeMindfulnessSession` writes a mindfulness session, such as a meditation, from `startTime` to `endTime`; a session that does not end after it starts throws an `ArgumentError` before anything is written. Request write access to `HealthDataType.MINDFULNESS` first (on Android, declare `READ_MINDFULNESS` and `WRITE_MINDFULNESS`).

```dart
if (await health.isMindfulnessSessionAvailable()) {
  bool saved = await health.writeMindfulnessSession(
    startTime: now.subtract(const Duration(minutes: 10)),
    endTime: now,
    sessionType: MindfulnessSessionType.BREATHING, // Android only, as are title and notes
    title: 'Morning practice',
  );
}
```

- **Android** stores a Health Connect mindfulness session with its `sessionType` (a `MindfulnessSessionType`: `UNKNOWN` by default, `MEDITATION`, `BREATHING`, `MUSIC`, `MOVEMENT` or `UNGUIDED`), `title` and `notes`. Health Connect added mindfulness sessions after its first release (see [Health Connect features](#health-connect-features)): `isMindfulnessSessionAvailable` tells whether the Health Connect on the device has them, and where it does not, reading or writing `MINDFULNESS` throws a `HealthException` with `HealthErrorCode.notSupported`.
- **iOS** stores a HealthKit mindful session, which has no type, title or notes, so iOS ignores them. `isMindfulnessSessionAvailable` returns `true` on iOS.

Reads return a session as a `MINDFULNESS` data point whose value is its minutes, without its type, title and notes. `writeHealthData` with `HealthDataType.MINDFULNESS` writes a session of type `UNKNOWN` without a title and notes. `getHealthIntervalDataFromTypes` returns the minutes of mindfulness sessions in each interval on both platforms (see [Reading data over intervals](#reading-data-over-intervals)).

### Health Data

A [`HealthDataPoint`](https://pub.dev/documentation/health/latest/health/HealthDataPoint-class.html) object contains the following data fields:

```dart
String uuid;
HealthValue value;
HealthDataType type;
HealthDataUnit unit;
DateTime dateFrom;
DateTime dateTo;
HealthPlatformType sourcePlatform;
String sourceDeviceId;
String sourceId;
String sourceName;
RecordingMethod recordingMethod;
WorkoutSummary? workoutSummary;
Map<String, dynamic>? metadata;
String? deviceModel;
```

where a [`HealthValue`](https://pub.dev/documentation/health/latest/health/HealthValue-class.html) is a `NumericHealthValue` (most types), `AudiogramHealthValue` (`AUDIOGRAM`), `ElectrocardiogramHealthValue` (`ELECTROCARDIOGRAM`; its `voltageValues` are `ElectrocardiogramVoltageValue`s), `InsulinDeliveryHealthValue` (`INSULIN_DELIVERY`), `MenstruationFlowHealthValue` (`MENSTRUATION_FLOW`), `NutritionHealthValue` (`NUTRITION`), `ActivityIntensityHealthValue` (`ACTIVITY_INTENSITY`), `SkinTemperatureHealthValue` (`SKIN_TEMPERATURE`), `WorkoutHealthValue` (`WORKOUT`; see [Writing workouts](#writing-workouts-ios--android) for its fields) or `WorkoutRouteHealthValue` (`WORKOUT_ROUTE`). `getHealthIntervalDataFromTypes` returns a `NumericHealthValue` for every type.

`metadata` is set for iOS quantity and category samples, such as steps, heart rate and sleep (their HealthKit metadata, an empty map if there is none), and for workout routes on both platforms (for example `route_point_count`); it is `null` for other data. `deviceModel` is the model of the device that recorded the data: on iOS HealthKit's `HKDevice.model`, such as `iPhone` or `Watch`, and on Android the `model` of Health Connect's `Device`, such as `Pixel Watch 2`. It is `null` when the app that wrote the data reported no device, or no model for it.

A `HealthDataPoint` object can be serialized to and from JSON using the `toJson()` and `fromJson()` methods. JSON serialization uses camelCase field names, except for some fields of `NutritionHealthValue` and `SkinTemperatureHealthValue`, which keep snake_case keys (for example `meal_type`, `vitamin_a` and `temperature_delta`). Null values are not serialized. For example:

```json
{
  "uuid": "A91A2F10-3D7B-486A-B140-5ADCD3C9C6D0",
  "value": {
    "__type": "NumericHealthValue",
    "numericValue": 141.0
  },
  "type": "STEPS",
  "unit": "COUNT",
  "dateFrom": "2024-04-03T10:06:57.736",
  "dateTo": "2024-04-03T10:12:51.724",
  "sourcePlatform": "appleHealth",
  "sourceDeviceId": "F74938B9-C011-4DE4-AA5E-CF41B60B96E7",
  "sourceId": "com.apple.health.81AE7156-EC05-47E3-AC93-2D6F65C717DF",
  "sourceName": "iPhone12.bardram.net",
  "recordingMethod": "automatic",
  "metadata": {},
  "deviceModel": "iPhone"
}
```

### Fetch health data

See the example app for a showcasing of how it's done.

**Note** On iOS the device must be unlocked before health data can be requested. Otherwise the read throws a `HealthPlatformException` with `errorCode` `HealthErrorCode.deviceLocked` (native code `DEVICE_LOCKED`), which is retryable once the device is unlocked. See [Error handling](#error-handling).

**The newest data points.** With a `limit`, `getHealthDataFromTypes` returns at most that many of the newest data points of each type, newest end time first, without reading every page of the range. For example, the latest weight of the last year:

```dart
List<HealthDataPoint> latest = await health.getHealthDataFromTypes(
  types: [HealthDataType.WEIGHT],
  startTime: now.subtract(const Duration(days: 365)),
  endTime: now,
  limit: 1,
);
```

`null` or 0 means no limit, and a negative `limit` throws an `ArgumentError`. Pages are read newest first until `limit` points are in, so records that give no point, such as sleep sessions without the stage asked for or data left out by `recordingMethodsToFilter`, cost more platform calls. On Android the pages go by the start time of the records, and a read with a `limit` does not look for sleep sessions or heart rate, speed, power, cycling cadence and skin temperature records that began before `startTime`.

### Fetch single health data by UUID

`getHealthDataByUUID` reads one data point by its `uuid` and `type`, for example of a point your app stored in its database:

```dart
HealthDataPoint? healthPoint = await health.getHealthDataByUUID(
  uuid: 'E9F2EEAD-8FC5-4CE5-9FF5-7C4E535FB8B8',
  type: HealthDataType.WORKOUT,
);
```

It returns `null` if no record has that UUID, and on Android also if the record has no data of `type`, for example a sleep session without the stage asked for, or a workout without a route for `WORKOUT_ROUTE`. Without the read permission it returns only the app's own data (see [Reads without the read permission](#reads-without-the-read-permission-ios--android)). Printed, a workout read on iOS looks like this:

```
data by UUID: HealthDataPoint -
    uuid: E9F2EEAD-8FC5-4CE5-9FF5-7C4E535FB8B8,
    value: WorkoutHealthValue - workoutActivityType: RUNNING,
           totalEnergyBurned: null,
           totalEnergyBurnedUnit: KILOCALORIE,
           totalDistance: 2400,
           totalDistanceUnit: METER
           totalSteps: null,
           totalStepsUnit: null,
           totalFlightsClimbed: null,
           totalSwimmingStrokeCount: null,
           swimming: null,
           avgMets: null,
           elevationAscended: null,
           elevationDescended: null,
           duration: 3240.0,
           indoorWorkout: null,
           weatherTemperature: null,
           weatherHumidity: null,
           averageSpeed: null,
           maximumSpeed: null,
           workoutEvents: null events,
    unit: NO_UNIT,
    dateFrom: 2025-05-02 07:31:00.000,
    dateTo: 2025-05-02 08:25:00.000,
    dataType: WORKOUT,
    platform: HealthPlatformType.appleHealth,
    deviceId: F74938B9-C011-4DE4-AA5E-CF41B60B96E7,
    sourceId: com.apple.Health,
    sourceName: Health
    recordingMethod: RecordingMethod.manual
    workoutSummary: WorkoutSummary - workoutType: RUNNING, totalDistance: 2400, totalEnergyBurned: 0, totalSteps: 0
    metadata: null
    deviceModel: null
```

On Android the plugin also logs the record it found, for example of `STEPS`:

```
I/FLUTTER_HEALTH( 9161): Success: {uuid=random-uuid-string, source_id=, source_name=com.google.android.apps.fitness, recording_method=0, device_model=null, value=12, date_from=1742259061009, date_to=1742259092888}
```

### Reading large amounts of data

`getHealthDataFromTypes` returns all data points in one list. A few months of heart rate data can be millions of points, so for large time ranges use `getHealthDataPages`, which returns a `Stream<HealthDataPage>`. The stream is lazy: nothing is read until you listen to it, and the next page is read only when you are ready for it. With `await for`, memory therefore stays bounded as long as you process each page and let it go.

```dart
await for (final page in health.getHealthDataPages(
  types: [HealthDataType.HEART_RATE, HealthDataType.STEPS],
  startTime: lastSync,
  endTime: now,
)) {
  await store(page.points); // the next page is read after this
}
```

- Types are read one after another, each type once. Within a type, points are oldest first and without duplicates: on Android in the order of their records' start times, on iOS by end time. On Android the samples of one heart rate, speed, power, cycling cadence or skin temperature record come together, as do the stages of one sleep session, so the samples of overlapping records, from one app or several, are not merged into one time order.
- Each type ends with exactly one page whose `isLastPageForType` is true; it is empty if the type had no more data. All other pages hold at least one point.
- A missing read permission is not an error: the type returns only the data the app wrote itself, and on Android its pages have `readPermissionDenied` set (see [Reads without the read permission](#reads-without-the-read-permission-ios--android)).
- An error ends the stream; pages already delivered stay valid. Cancelling the subscription stops the read: no platform call is made after it, and `cancel()` completes once the call in flight has returned (an error it reports is dropped).
- `getHealthDataFromTypes` keeps every point in memory until it returns, which means long garbage collection pauses at millions of points. On iOS it still returns points newest first.

**Page size.** `pageSize` is the target number of data points per platform call: 20,000 by default, at most 50,000. Bigger pages need fewer Health Connect calls (see [Health Connect limits](#health-connect-limits)) but more memory per call. On Android a heart rate page holds at most about `pageSize` samples on every Android version, however they are spread over records; a record is never split, so one record with more samples makes a larger page, as do records that share a start time where a page ends among them (see below), and the first page also holds the samples in the range of the records that began before `startTime`. Set it for an instance with `Health(pageSize: 5000)` or `health.pageSize = 5000`, or for one read with `getHealthDataPages(..., pageSize: 5000)`.

**Workouts on Android 14 and 15.** Workouts are read 20 per page and workout routes 5 per page (fewer if `pageSize` is smaller). Health Connect on Android 14 and 15 fails such a read when the app may read routes (`READ_EXERCISE_ROUTES`, or `WRITE_EXERCISE_ROUTE` for its own, which the plugin requests for `WORKOUT_ROUTE` writes) and a session with such a route starts in the range but outside the page. That is a Health Connect bug, fixed in Android 16; a Health Connect that a system update brought up to date may not have it. The plugin catches exactly this error and reads the page again together with the rest of the range, up to 5,000 sessions with their routes, but still replies a page of the usual size: 20 workouts or 5 routes, and any further sessions that start at the same time as its last one. The next page goes on with the first session left out, so each session is returned once, in order, and a workout page reads the totals of its own workouts only. Each such page costs one more Health Connect call (the failed call counts against the quota too). As every read again also returns the rest of the range with its routes, such pages take more time and memory the more sessions with long routes follow them; reading shorter time ranges keeps them small. With a `limit`, only the newest sessions are converted until `limit` points are in, and the read ends there. If a session with a route lies more than 5,000 sessions after the start of such a page, the read again fails too, and the read fails with a `HealthPlatformException` with `HealthErrorCode.unknown` (platform code `HEALTH_ERROR`), as before.

**Records that share a start time on Android.** Health Connect returns a type's records in the order of their start times, a limited number per call: `pageSize` records, at most 5,000, for most types; 20 workouts, 5 workout routes or 500 sleep sessions; and fewer for heart rate, speed, power, cycling cadence and skin temperature, whose records can hold many samples each. Imported or synced data is often written with identical timestamps, and since Android 14 QPR2 Health Connect's page tokens lose count of records that share one start time, to the millisecond, where a page ends among them. Following the tokens then returns some of those records twice, or the same records on every further call, and on Android 15 also records without some of their samples, sleep stages or laps (measured on Android 15, 16 and 17). An Android 14 Health Connect older than QPR2 instead returns an empty page, on every further call too, where more records share the first start time of a call than it asks for. Before 14.0.0, such reads returned records twice or in part, or read again and again until the app ran out of memory or Health Connect quota. Now, where a page ends among such records or is such an empty page, the plugin reads all records of the type that start at that millisecond in one more Health Connect call, and the next page starts after them, so each record is returned once, whole and in order. The reads behind workout totals, sleep intervals, `getTotalStepsInInterval(includeManualEntry: false)` and the look-back for sleep sessions and heart rate records that began before `startTime` do the same. Each such page costs that one more call and holds more records than asked for: all those of its last start time, which for heart rate, speed, power, cycling cadence and skin temperature can be many more samples than `pageSize`. Where more than 5,000 records of a type start at the same millisecond, which one call cannot hold, the read fails with `HealthErrorCode.unknown` instead of reading the same records forever, as does a read on Android 13 and lower if the Health Connect app returns the same page token twice.

**Where parsing runs.** The platform call is always made from the isolate that calls the plugin. `isolateMode` decides where the reply is decoded and parsed into `HealthDataPoint`s:

| `HealthIsolateMode` | Decoding and parsing                                                                                                                                                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `auto` (default)    | Replies of 64 KiB or more (a few hundred points) are parsed in a short-lived worker isolate, so the UI keeps running. Smaller replies, calls from an isolate other than the root (UI) isolate and calls under `flutter test` are parsed inline. |
| `worker`            | Always in a short-lived worker isolate.                                                                                                                                                                                                    |
| `inline`            | Always in the calling isolate; no isolate is started.                                                                                                                                                                                      |

```dart
final health = Health(isolateMode: HealthIsolateMode.worker, pageSize: 10000);
health.isolateMode = HealthIsolateMode.inline; // used by reads started from now on
```

**Widget tests.** `testWidgets` runs on fake time and never sees work in another isolate finish. `auto` parses inline under `flutter test`, so it works there. With `worker`, use `inline` in the test or wrap the read in `tester.runAsync`.

**Method channel mocks.** Reads call the native method `getDataPage`. A mock written for older versions that only answers `getData` keeps working: when the first `getDataPage` call is not implemented, the plugin reads the type with one `getData` call, as before.

**Bring your own isolate.** To also keep your own processing of the points off the UI isolate, call the plugin from your own isolate. Request permissions on the UI isolate first. Off the root isolate, `auto` parses inline:

```dart
final token = RootIsolateToken.instance!;
final count = await Isolate.run(() async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  final health = Health();
  var count = 0;
  await for (final page in health.getHealthDataPages(
    types: [HealthDataType.HEART_RATE],
    startTime: start,
    endTime: end,
  )) {
    count += page.points.length; // process the points here
  }
  return count;
});
```

**Resuming.** The plugin does not keep track of what you have read. To sync a long range robustly, read it in time windows and record your progress per finished window; after an interruption, read the unfinished window again. Every read has a fixed cost in Health Connect calls (see [Health Connect limits](#health-connect-limits)), so prefer windows of a week or a month to windows of a day. Each window returns the samples inside it: a heart rate, speed, power, cycling cadence or skin temperature record that crosses a boundary is split between the two windows (on Android, records that began more than 24 hours before a window are not looked for, and with very dense heart rate data in those 24 hours only the newest records are: see [Health Connect limits](#health-connect-limits)). Reads are at-least-once at such a boundary: a point you already stored can be returned again. A sleep data point is returned in the window it starts in, so consecutive windows return it once (on Android, the stages of sessions that began more than 24 hours before a window are not looked for). Store points with an upsert keyed by `(type, uuid, dateFrom)`; on Android, the heart rate samples of one record share the record's `uuid`.

### Reading data over intervals

`getHealthIntervalDataFromTypes` aggregates each type over intervals of `interval` seconds from `startDate` to `endDate`, for example the steps and the average heart rate per hour:

```dart
List<HealthDataPoint> hourly = await health.getHealthIntervalDataFromTypes(
  types: [HealthDataType.STEPS, HealthDataType.HEART_RATE],
  startDate: now.subtract(Duration(days: 1)),
  endDate: now,
  interval: 3600,
);
```

- Each type has one data point per interval that has data. Intervals without data are left out on both platforms.
- The value of every point is a `NumericHealthValue` in the type's unit (see [Data Types](#data-types)): the sum for cumulative types such as steps, energy, distance and water, and the average for other types. For heart rate, that is the average beats per minute: HealthKit weights each sample by the time it covers, Health Connect takes the mean of the samples. On Android, activity intensity intervals hold the intensity minutes Health Connect computes, and mindfulness intervals the minutes of the mindfulness sessions.
- For a sleep type, the value is the number of minutes of the interval that the type's data points cover (the points `getHealthDataFromTypes` returns for the type), with overlapping points counted once. A point that began before `startDate` counts with its part after it; on Android, sleep sessions that began up to 24 hours before `startDate` are read for this. For the time in bed, use `SLEEP_SESSION` (the whole session) on Android and `SLEEP_IN_BED` on iOS. On iOS, `MINDFULNESS` intervals are computed the same way from the mindful sessions.
- Not every type has intervals. On Android, a type without them returns no data points; on iOS, it throws a `HealthPlatformException` with `HealthErrorCode.invalidArgument`, and a type this iOS version does not have (such as `ROWING_SPEED` before iOS 18) throws one with `HealthErrorCode.notSupported`, as reads of it do. The documentation of `getHealthIntervalDataFromTypes` lists the types of each platform.
- On both platforms, a point's `sourceName` names the apps whose data it holds, joined by `", "` (Android package names, iOS bundle identifiers), and its `sourceId` is empty. For sums and averages, these are the apps with data in that interval; on iOS they are sorted and can include devices. For the sleep types, and for `MINDFULNESS` on iOS, they are the apps whose samples cover part of the interval, each once, in the order their samples start.
- Without the read permission, Android throws a `HealthPlatformException` with `HealthErrorCode.permissionDenied`, and iOS returns the intervals of the app's own samples (see [Reads without the read permission](#reads-without-the-read-permission-ios--android)).

**Health Connect's app priority list.** On Android, the sums of the activity types (`STEPS`, `DISTANCE_DELTA`, `ACTIVE_ENERGY_BURNED`, `TOTAL_CALORIES_BURNED` and the `ACTIVITY_INTENSITY` minutes), on recent Health Connect versions also the `MINDFULNESS` minutes, and `getTotalStepsInInterval` (unless `includeManualEntry` is `false`) are Health Connect aggregates. They count only the apps in the user's priority list for the data's category, and where the data of several apps overlap, only the app with the highest priority. Health Connect ranks only activity, sleep and wellness data this way: other intervals, such as heart rate averages, combine the data of every app, and the plugin computes sleep intervals itself from the sessions of every app. An app joins the priority list when the user grants it a write permission of the category in Health Connect's permission screen (`requestAuthorization`), or adds it to the list in Health Connect's settings. Health Connect may also add apps with data to an empty list on its own.

> **Testing note:** permissions granted with `adb shell pm grant` do not add the app to the priority list, so the app's own data is missing from these sums until a write permission is granted through Health Connect's permission screen or the app is added to the list in Health Connect's settings.

### Error handling

Read methods throw a `HealthPlatformException` when Health Connect or HealthKit reports an error. It is both a `PlatformException` (what iOS threw before 14.0.0) and a `HealthException`, so existing `on PlatformException` and `on HealthException` handlers keep working. Put `on HealthPlatformException` before `on PlatformException`, as the earlier clause catches it otherwise. `errorCode` says what went wrong and `isRetryable` whether the same call may succeed later. The plugin never retries on its own.

```dart
try {
  final points = await health.getHealthDataFromTypes(types: types, startTime: start, endTime: end);
} on HealthPlatformException catch (e) {
  if (e.isRetryable) {
    // For example HealthErrorCode.rateLimitExceeded: try again later.
  } else if (e.errorCode == HealthErrorCode.permissionDenied) {
    // Ask for the permission.
  }
  // e.platformCode is the native code, e.details holds more information.
} on HealthException catch (e) {
  // For example a type that is not available on this platform (HealthErrorCode.notSupported).
}
```

| `HealthErrorCode`   | Native code                 | Meaning                                                                                                                                                                                   | `isRetryable` |
| ------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| `rateLimitExceeded` | `RATE_LIMIT_EXCEEDED`       | The app used up its Health Connect API quota. See [Health Connect limits](#health-connect-limits).                                                                                        | yes           |
| `permissionDenied`  | `PERMISSION_DENIED`         | The call needs a permission the app does not have, for example a background read without `READ_HEALTH_DATA_IN_BACKGROUND`, on Android `getHealthIntervalDataFromTypes` or `getTotalStepsInInterval` without the type's read permission, or, on iOS, a type the app never requested authorization for. In `getHealthDataFromTypes` and `getHealthDataPages`, a denied read permission for a type is not an error: the type returns only the data the app wrote itself (see [Reads without the read permission](#reads-without-the-read-permission-ios--android)). | no            |
| `invalidArgument`   | `INVALID_ARGUMENT`          | The request is not valid, for example a preferred unit that cannot express the data type. On Android, besides each type's default unit, Health Connect values are only converted to `POUND` (weight), `CENTIMETER` and `INCH` (height), `DEGREE_FAHRENHEIT` and `KELVIN` (body and skin temperature) and `MILLIMOLES_PER_LITER` (blood glucose). | no            |
| `notSupported`      | `NOT_SUPPORTED`             | The data type is not available on this platform or device.                                                                                                                                | no            |
| `unavailable`       | `UNAVAILABLE`               | Health Connect cannot be reached or is busy, for example while it syncs data.                                                                                                             | yes           |
| `deviceLocked`      | `DEVICE_LOCKED`             | iOS: protected health data cannot be read while the device is locked.                                                                                                                    | yes           |
| `dataTooLarge`      | `DATA_TOO_LARGE`            | The platform could not return this much data in one call. Use a smaller `pageSize` or a shorter time range.                                                                               | no            |
| `unknown`           | `HEALTH_ERROR` (and others) | Any other error.                                                                                                                                                                          | no            |

Codes may be added in minor releases, so a `switch` over `HealthErrorCode` needs a default case. Codes from before 14.0.0, such as `PERMISSION_ERROR`, `ARGUMENT_ERROR` and `INVALID_TYPE`, map to the matching value; `STEPS_ERROR` and `STATISTICS_ERROR` map to `unknown`.

What each method does on failure:

| Method                                                                   | On failure                                                                                                                                                                                       |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `getHealthDataFromTypes`                                                 | Throws `HealthPlatformException`. An empty list only means no data that the app may read (see [Reads without the read permission](#reads-without-the-read-permission-ios--android)). Before 14.0.0, Android returned an empty list on any failure. |
| `getHealthDataPages`                                                     | The stream emits the `HealthPlatformException` (or `HealthException`) and closes.                                                                                                                |
| `getHealthIntervalDataFromTypes`                                         | Throws `HealthPlatformException`, for example with `permissionDenied` on Android without the type's read permission.                                                                             |
| `getHealthDataByUUID`                                                    | Returns `null` if the record is not found or, without the read permission, was written by another app, and throws `HealthPlatformException` on other failures, on Android with `permissionDenied` without either the read or the write permission. |
| `getTotalStepsInInterval`                                                | Throws `HealthPlatformException`, for example with `permissionDenied` on Android without the steps read permission (HealthKit then counts only the steps the app saved). It returns 0 when there are no steps. Before 14.0.0, Android returned `null` on any failure. |
| `getChangesToken`, `getChanges`                                          | Throw `HealthPlatformException`. They return `null` only on iOS, which has no Health Connect. If Health Connect cannot return the pending changes because they are too many, or a single change holds more than 100,000 data points, `getChanges` returns `changesTokenExpired: true`: create a new token and read the data again. A larger page of changes is read again with fewer changes. Before 14.0.0, both returned `null` on any failure. |
| `getHealthAggregateDataFromTypes`                                        | Deprecated: throws an `UnsupportedError` without calling the platform. It has not worked on either platform since Google Fit was removed; use `getHealthIntervalDataFromTypes` instead.        |
| `writeSleepSession`                                                      | Throws an `ArgumentError` before anything is written if `startTime` is not before `endTime`, a stage is not valid (see [Writing a night of sleep](#writing-a-night-of-sleep-ios--android)) or, on iOS, `recordingMethod` is not `manual` or `automatic`. Returns `false` if the platform does not save the session. On iOS, a session HealthKit does not accept, such as one longer than 4 days, throws a `PlatformException` with code `INVALID_ARGUMENT`. |
| `writeMindfulnessSession`                                                | Throws an `ArgumentError` before anything is written if `startTime` is not before `endTime` or, on iOS, `recordingMethod` is not `manual` or `automatic`, and a `HealthException` with `HealthErrorCode.notSupported` where Health Connect has no mindfulness sessions. Returns `false` if the platform does not save the session. On iOS, a session HealthKit does not accept, such as one longer than 28 days, throws a `PlatformException` with code `INVALID_ARGUMENT`. |
| `writeWorkoutData`, `writeWorkoutDataUUID`                               | Throw an `ArgumentError` before anything is written for a client record id or sync identifier without its version (or a version without its id), a zone offset of more than 18 hours, or swimming details that are not valid (see [Swimming workouts](#swimming-workouts)), and a `HealthException` with `HealthErrorCode.notSupported` for a workout type the platform does not have. Return `false` (`writeWorkoutDataUUID` an empty string) if the platform does not save the workout. On iOS, a workout HealthKit does not accept throws a `PlatformException` with code `INVALID_ARGUMENT`. |
| `getRequestStatusForAuthorization`                                       | Throws a `PlatformException` when HealthKit cannot determine the status, and an `ArgumentError` for write access to a type that HealthKit lets apps only read (see [Authorization on iOS](#authorization-on-ios)). Returns `null` on Android. |
| Other writes, deletes, permissions and the Health Connect helpers        | As before 14.0.0, most return `false` on failure. Calls that crashed the app or never returned now fail instead: on iOS, data HealthKit does not accept, such as a sample longer than its type allows, throws a `PlatformException` with code `INVALID_ARGUMENT`, and on Android, `hasPermissions` throws a `PlatformException` when Health Connect fails. On Android, `writeHealthData` and `writeHealthDataUUID` of a type Health Connect stores with a duration (such as `STEPS`) whose `endTime` equals `startTime` throw a `PlatformException` with code `INVALID_ARGUMENT`. On iOS, `writeHealthData` and `writeHealthDataUUID` throw an `ArgumentError` for a type that HealthKit lets apps only read. On Android, a permission request made while the Health Connect permission dialog is open returns `false`. |

New in 14.0.0, on Android a `preferredUnits` entry that Health Connect values are not converted to throws a `HealthException` with `errorCode` `invalidArgument` before anything is read; before, the values were labelled with that unit without being converted to it. Other errors are as before: a `HealthException` (now with `errorCode` `notSupported`) when a data type is not available on the platform, which is checked for all types before anything is read (on Android also the [Health Connect features](#health-connect-features) of the device); an `UnsupportedError` when Health Connect is not available, whose message now says why (see `getHealthConnectSdkStatus`); and `ArgumentError`s for invalid arguments. A `MissingPluginException` is passed on as it is.

### Health Connect limits

Health Connect limits how often each app may call it. When a quota is used up, reads throw a `HealthPlatformException` with `HealthErrorCode.rateLimitExceeded` until the quota has refilled (writes return `false`). The quotas are part of the Health Connect module, so **they vary with the Health Connect version** and may change at any time. These are the values measured on three devices:

| Quota per app           | Pixel 8a, Android 17               | Android 16 emulator               | Android 15 emulator (SDK extension 13) |
| ----------------------- | ---------------------------------- | --------------------------------- | -------------------------------------- |
| Reads in the foreground | 80,000 per 15 min, 80,000 per 24 h | 2,000 per 15 min, 16,000 per 24 h | 2,000 per 15 min, 16,000 per 24 h      |
| Reads in the background | 1,000 per 15 min, 8,000 per 24 h   | 1,000 per 15 min, 8,000 per 24 h  | 1,000 per 15 min, 8,000 per 24 h       |
| Writes                  | 1,000 per 15 min, 8,000 per 24 h   | 1,000 per 15 min, 8,000 per 24 h  | 1,000 per 15 min, 8,000 per 24 h       |
| Data written            | 35 MB per 15 min                   | 35 MB per 15 min                  | 35 MB per 15 min                       |
| Size of a request       | 5 MB, and 1 MB per record          | 5 MB, and 1 MB per record         | not checked                            |

A quota refills continuously rather than all at once when its window ends. On the Android 15 emulator, 2,075 one-record reads went through in the foreground after 15 idle minutes, after which reads came back at about 2.2 per second; an emptied 15-minute quota was full again after about 15 minutes. The quotas of Android 14 and of the Health Connect app on Android 13 and lower were not measured.

The plugin reads Health Connect page by page, and every page is a call. What a read costs:

| Read                                                  | Health Connect calls                                                                                                                                                                                                                                                                                         |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| A type with one value per record (steps, weight, ...) | 1 permission check + 1 per 5,000 records (per `pageSize` records if that is smaller)                                                                                                                                                                                                                                        |
| Heart rate                                            | 1 permission check + 1 per page + 1 count of the samples per about 8 pages (a page holds at most `pageSize` samples, give or take one record) + 1 per record that holds more than `pageSize / 2` samples. The first page also looks for the records that began in the 24 hours before `startTime` and reach into the read, with at most 24 calls: 2 if those hours hold no heart rate, otherwise about 1 per 15,000 samples in them (fewer with a `pageSize` above 20,000), but about 1 per 4,000 records where each record holds one sample. So a day at one sample per second takes about 6 calls in records of a minute or an hour, but all 24 as one record per sample (86,400 records did on the Android 15 emulator). Where those hours hold more, for example such a day of one-sample records from two apps, or more than about 250,000 to 350,000 samples in longer records (depending on the records and the Android version), only the newest records are looked at, and a warning is logged. Every Android version makes this look-back, except that a read of only the app's own heart rate (write permission without read permission) that fits in one page makes it, on Android 16 and later, only when Health Connect's count of its samples shows such a record. Each page makes at most 40 calls, whatever the data and `pageSize`. For example, with no heart rate in the day before `startTime`, a week of heart rate at one sample per second (600,000 samples) costs about 40 calls at the default `pageSize`, and 30 days at one sample per minute (a record per sample) about 15. |
| Speed, power, cycling cadence and skin temperature    | 1 permission check + 1 look-back read + 1 per `pageSize / 3600` records (5 at the default `pageSize`): a record may hold an hour of samples at one per second, and Health Connect has no count of these samples to plan by. A page whose records hold more than twice `pageSize` samples is read again with the records that fit in `pageSize`: 1 more call each time, at most 3 per page. |
| A series type read with only its write permission (the app's own records) | As with the read permission: heart rate in time slices, the other series types as for speed. Where Health Connect refuses to count the app's own heart rate samples (an Android 14 Health Connect older than QPR2, a read started in the background without `READ_HEALTH_DATA_IN_BACKGROUND`, possibly the Health Connect app on Android 13 and lower), heart rate costs 1 refused count + as for speed. A week of heart rate written once a minute with `writeHealthData` (one record per sample) then costs about 2,000 calls, the whole 15-minute foreground quota of Android 15 and 16, against about 10 in time slices. |
| Workouts                                              | Per 20 workouts: 1 permission check + 1 read + up to 3 per workout for its distance, calories and steps (1 more per further 5,000 records of a total). Workout routes: 1 permission check + 1 per 5 sessions. On Android 14 and 15, both cost 1 more for each page that Health Connect fails to read for a route outside it (see [Workouts on Android 14 and 15](#reading-large-amounts-of-data)) |
| Sleep types                                           | 1 permission check + 1 per 500 sleep sessions (per `pageSize` sessions if that is smaller); a stage type (not `SLEEP_SESSION`) also reads the sessions that began in the 24 hours before `startTime`: 1 more per 500 sessions                                                                                |
| `getHealthDataFromTypes` with a `limit`               | 1 permission check + 1 per page, reading the pages newest first until `limit` points are in (the first page asks for at most `limit` records), without the reads of records that began before `startTime`; workouts also read their totals, as above. The latest weight (`limit: 1`) costs 1 permission check + 1 read. |
| `getTotalStepsInInterval(includeManualEntry: false)`  | 1 per 5,000 step records                                                                                                                                                                                                                                                                                     |
| `getHealthIntervalDataFromTypes`                      | 1 per type. A sleep type reads the sleep sessions from 24 hours before `startDate` to `endDate` instead: 1 per 500 sessions                                                                                                                                                                                  |
| `getChanges`                                          | 1 per call, and 1 more each time a page of changes that holds more than 100,000 data points is read again with fewer changes                                                                                                                                                                                 |

On Android 14 and later, every read whose page ends among records that share one start time costs 1 more call, also in the totals and look-backs above, and beyond the caps of 24 and 40 calls for heart rate (see [Records that share a start time on Android](#reading-large-amounts-of-data)).

Checking the granted permissions did not count against the read quota on the Android 16 emulator.

To stay within the quotas, read large ranges in the foreground (the background quota is much smaller), prefer a few long reads over many short ones, keep the default `pageSize` or raise it for heart rate data, and call `getChanges` instead of re-reading data you already have.

### Filtering by recording method

Google Health Connect and Apple HealthKit both provide ways to distinguish samples collected "automatically" and manually entered data by the user.

- Android provides an enum with 4 variations: <https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/metadata/Metadata#summary>
- iOS has a boolean value: <https://developer.apple.com/documentation/healthkit/hkmetadatakeywasuserentered>

As such, when fetching data you have the option to filter the fetched data by recording method as such:

```dart
List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
  types: types,
  startTime: yesterday,
  endTime: now,
  recordingMethodsToFilter: [RecordingMethod.manual, RecordingMethod.unknown],
);
```

**Note that for this to work, the information needs to have been provided when writing the data to Health Connect or Apple Health**. For example, steps added manually through the Apple Health App will set `HKWasUserEntered` to true (corresponding to `RecordingMethod.manual`), however it seems that adding steps manually to Google Fit does not write the data with the `RecordingMethod.manual` in the metadata, instead it shows up as `RecordingMethod.unknown`. This is an open issue, and as such filtering manual entries when querying step count on Android with `getTotalStepsInInterval(includeManualEntry: false)` does not necessarily filter out manual steps.

On Android, `getTotalStepsInInterval(includeManualEntry: false)` adds up the step records of every app that start in the interval, as Health Connect's aggregates cannot filter by recording method. Unlike the default, Health Connect's step aggregate, it does not leave out apps outside Health Connect's app priority list (see [Reading data over intervals](#reading-data-over-intervals)), counts the overlapping data of several apps twice, and does not split records that cross the interval's bounds.

**NOTE**: On iOS, only `RecordingMethod.manual` can be filtered out: HealthKit marks only the samples the user entered (`HKMetadataKeyWasUserEntered`). Most other samples read as `RecordingMethod.automatic`, but `RecordingMethod.automatic` or another method in `recordingMethodsToFilter` does not leave them out. In `getHealthIntervalDataFromTypes` on Android, only the sleep types are filtered: the intervals of the other types are Health Connect aggregates, which include data of every recording method. `getHealthIntervalDataFromTypes` prints a warning to the console for a filter it cannot apply; the other reads ignore it silently.

### Filtering out duplicates

If the same data is requested multiple times and saved in the same array, duplicates will occur.

Two data points can be compared with the `==` operator, i.e.

```dart
HealthDataPoint p1 = ...;
HealthDataPoint p2 = ...;
bool same = p1 == p2;
```

If you have a list of data points, duplicates can be removed with:

```dart
List<HealthDataPoint> points = ...;
points = health.removeDuplicates(points);
```

`==`, and so `removeDuplicates`, compares every field of the points, including the `sourceDeviceId`, the `deviceModel` and the contents of their `metadata` (before 14.0.0 a point with `metadata`, such as every iOS sample, was never equal to the same data read again). To match points only by the record they come from, compare `type`, `uuid` and `dateFrom`, the key recommended for resuming reads in [Reading large amounts of data](#reading-large-amounts-of-data):

```dart
final seen = <(HealthDataType, String, DateTime)>{};
points = points.where((p) => seen.add((p.type, p.uuid, p.dateFrom))).toList();
```

### Android: Reading Health Data in Background

Health Connect lets an app read health data in the background with the permission `READ_HEALTH_DATA_IN_BACKGROUND`. Declare it in `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND"/>
```

Where `isHealthDataInBackgroundAvailable()` is `true` (see [Health Connect features](#health-connect-features)), `isHealthDataInBackgroundAuthorized()` tells whether it is granted and `requestHealthDataInBackgroundAuthorization()` asks the user for it. On iOS, which has no such permission, `isHealthDataInBackgroundAvailable()` returns `false` and the other two `true`.

Without it, Health Connect lets an app in the background read only the records it wrote itself, and no aggregates. A read of a type with its read permission (which asks for the data of every app), `getHealthIntervalDataFromTypes` and `getTotalStepsInInterval` therefore fail there with a `HealthPlatformException` with `HealthErrorCode.permissionDenied`, also on a later page of a read that started in the foreground. A read with only the write permission returns the app's own records in the background too, but a heart rate read that started in the foreground can fail on a later page, as its pages are planned from Health Connect's counts of its samples (see [Reads without the read permission](#reads-without-the-read-permission-ios--android)).

## Data Types

The plugin supports the following [`HealthDataType`](https://pub.dev/documentation/health/latest/health/HealthDataType.html). A type marked iOS 16+, 17+ or 18+ needs that iOS version: on an earlier one, reading it fails with `HealthErrorCode.notSupported`. READ Only types cannot be written.

| **Data Type**                         | **Unit**                                | **Apple Health** | **Google Health Connect** | **Comments**                                                                                                                       |
| ------------------------------------- | --------------------------------------- | ---------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| ACTIVE_ENERGY_BURNED                  | KILOCALORIE                             | yes              | yes                       |                                                                                                                                    |
| ACTIVITY_INTENSITY                    | MINUTE                                  |                  | yes                       | Only where `isActivityIntensityAvailable()` is true (see [Health Connect features](#health-connect-features)); write with `writeActivityIntensity`, not `writeHealthData`; reads give an `ActivityIntensityHealthValue` |
| ATRIAL_FIBRILLATION_BURDEN            | PERCENT                                 | yes              |                           | READ Only - iOS 16+                                                                                                                |
| BASAL_BODY_TEMPERATURE                | DEGREE_CELSIUS                          | yes              |                           |                                                                                                                                    |
| BASAL_ENERGY_BURNED                   | KILOCALORIE                             | yes              | yes                       | on Android, Health Connect's basal metabolic rate (`BasalMetabolicRateRecord`) in kilocalories per day                             |
| BIRTH_DATE                            | NO_UNIT                                 | yes              |                           | READ Only - a HealthKit characteristic: the birth date in seconds since 1970                                                       |
| BLOOD_ALCOHOL_CONTENT                 | PERCENT                                 | yes              |                           |                                                                                                                                    |
| BLOOD_GLUCOSE                         | MILLIGRAM_PER_DECILITER                 | yes              | yes                       |                                                                                                                                    |
| BLOOD_OXYGEN                          | PERCENT                                 | yes              | yes                       |                                                                                                                                    |
| BLOOD_PRESSURE_DIASTOLIC              | MILLIMETER_OF_MERCURY                   | yes              | yes                       |                                                                                                                                    |
| BLOOD_PRESSURE_SYSTOLIC               | MILLIMETER_OF_MERCURY                   | yes              | yes                       |                                                                                                                                    |
| BLOOD_TYPE                            | NO_UNIT                                 | yes              |                           | READ Only - a HealthKit characteristic: the `HKBloodType` raw value                                                                |
| BODY_FAT_PERCENTAGE                   | PERCENT                                 | yes              | yes                       |                                                                                                                                    |
| BODY_MASS_INDEX                       | NO_UNIT                                 | yes              | yes                       |                                                                                                                                    |
| BODY_TEMPERATURE                      | DEGREE_CELSIUS                          | yes              | yes                       |                                                                                                                                    |
| BODY_WATER_MASS                       | KILOGRAM                                |                  | yes                       |                                                                                                                                    |
| ELECTRODERMAL_ACTIVITY                | SIEMEN                                  | yes              |                           |                                                                                                                                    |
| FORCED_EXPIRATORY_VOLUME              | LITER                                   | yes              |                           | HealthKit's `forcedExpiratoryVolume1` (FEV1)                                                                                       |
| FORCED_VITAL_CAPACITY                 | LITER                                   | yes              |                           |                                                                                                                                    |
| GENDER                                | NO_UNIT                                 | yes              |                           | READ Only - a HealthKit characteristic: the `HKBiologicalSex` raw value                                                            |
| HEART_RATE                            | BEATS_PER_MINUTE                        | yes              | yes                       |                                                                                                                                    |
| HEART_RATE_RECOVERY_ONE_MINUTE        | BEATS_PER_MINUTE                        | yes              |                           | iOS 16+                                                                                                                            |
| HEIGHT                                | METER                                   | yes              | yes                       |                                                                                                                                    |
| INHALER_USAGE                         | COUNT                                   | yes              |                           |                                                                                                                                    |
| NUMBER_OF_ALCOHOLIC_BEVERAGES         | COUNT                                   | yes              |                           |                                                                                                                                    |
| NUMBER_OF_TIMES_FALLEN                | COUNT                                   | yes              |                           |                                                                                                                                    |
| PEAK_EXPIRATORY_FLOW                  | LITER_PER_MINUTE                        | yes              |                           | HealthKit's `peakExpiratoryFlowRate`                                                                                               |
| RESTING_HEART_RATE                    | BEATS_PER_MINUTE                        | yes              | yes                       |                                                                                                                                    |
| RESPIRATORY_RATE                      | RESPIRATIONS_PER_MINUTE                 | yes              | yes                       |                                                                                                                                    |
| PERIPHERAL_PERFUSION_INDEX            | PERCENT                                 | yes              |                           |                                                                                                                                    |
| STEPS                                 | COUNT                                   | yes              | yes                       |                                                                                                                                    |
| TOTAL_CALORIES_BURNED                 | KILOCALORIE                             |                  | yes                       | Active and basal energy together (`TotalCaloriesBurnedRecord`)                                                                     |
| VO2_MAX                               | MILLILITER_PER_KILOGRAM_PER_MINUTE      | yes              | yes                       | On Android, values from 0 to 100 only (`writeHealthData` returns `false` for others), and no interval data                         |
| WAIST_CIRCUMFERENCE                   | METER                                   | yes              |                           |                                                                                                                                    |
| WALKING_HEART_RATE                    | BEATS_PER_MINUTE                        | yes              |                           | READ Only                                                                                                                          |
| WEIGHT                                | KILOGRAM                                | yes              | yes                       |                                                                                                                                    |
| DISTANCE_WALKING_RUNNING              | METER                                   | yes              |                           |                                                                                                                                    |
| DISTANCE_CYCLING                      | METER                                   | yes              |                           |                                                                                                                                    |
| DISTANCE_SWIMMING                     | METER                                   | yes              |                           |                                                                                                                                    |
| DISTANCE_WHEELCHAIR                   | METER                                   | yes              |                           |                                                                                                                                    |
| DISTANCE_DOWNHILL_SNOW_SPORTS         | METER                                   | yes              |                           |                                                                                                                                    |
| DISTANCE_CROSS_COUNTRY_SKIING         | METER                                   | yes              |                           | iOS 18+                                                                                                                            |
| DISTANCE_PADDLE_SPORTS                | METER                                   | yes              |                           | iOS 18+                                                                                                                            |
| DISTANCE_ROWING                       | METER                                   | yes              |                           | iOS 18+                                                                                                                            |
| DISTANCE_SKATING_SPORTS               | METER                                   | yes              |                           | iOS 18+                                                                                                                            |
| FLIGHTS_CLIMBED                       | COUNT                                   | yes              | yes                       |                                                                                                                                    |
| PUSH_COUNT                            | COUNT                                   | yes              |                           | Wheelchair pushes                                                                                                                  |
| SWIMMING_STROKE_COUNT                 | COUNT                                   | yes              |                           |                                                                                                                                    |
| DISTANCE_DELTA                        | METER                                   |                  | yes                       |                                                                                                                                    |
| MINDFULNESS                           | MINUTE                                  | yes              | yes                       | On Android only where `isMindfulnessSessionAvailable()` is true (see [Health Connect features](#health-connect-features)); see [Writing a mindfulness session](#writing-a-mindfulness-session-ios--android) |
| SLEEP_ASLEEP                          | MINUTE                                  | yes              | yes                       | on iOS, this refers to asleepUnspecified, and on Android this refers to STAGE_TYPE_SLEEPING (asleep but specific stage is unknown) |
| SLEEP_AWAKE                           | MINUTE                                  | yes              | yes                       |                                                                                                                                    |
| SLEEP_AWAKE_IN_BED                    | MINUTE                                  |                  | yes                       |                                                                                                                                    |
| SLEEP_DEEP                            | MINUTE                                  | yes              | yes                       |                                                                                                                                    |
| SLEEP_IN_BED                          | MINUTE                                  | yes              |                           |                                                                                                                                    |
| SLEEP_LIGHT                           | MINUTE                                  | yes              | yes                       | on iOS, this refers to asleepCore                                                                                                  |
| SLEEP_OUT_OF_BED                      | MINUTE                                  |                  | yes                       |                                                                                                                                    |
| SLEEP_REM                             | MINUTE                                  | yes              | yes                       |                                                                                                                                    |
| SLEEP_UNKNOWN                         | MINUTE                                  | yes              | yes                       | on iOS, sleep values that no other sleep type covers (none yet; values Apple adds later), READ Only; on Android, STAGE_TYPE_UNKNOWN |
| SLEEP_SESSION                         | MINUTE                                  |                  | yes                       |                                                                                                                                    |
| WATER                                 | LITER                                   | yes              | yes                       |                                                                                                                                    |
| EXERCISE_TIME                         | MINUTE                                  | yes              |                           | READ Only                                                                                                                          |
| PHYSICAL_EFFORT                       | KILOCALORIE_PER_HOUR_KILOGRAM           | yes              |                           | iOS 17+                                                                                                                            |
| WORKOUT_EFFORT_SCORE                  | APPLE_EFFORT_SCORE                      | yes              |                           | iOS 18+; a score from 0 to 10                                                                                                      |
| ESTIMATED_WORKOUT_EFFORT_SCORE        | APPLE_EFFORT_SCORE                      | yes              |                           | iOS 18+; a score from 0 to 10                                                                                                      |
| WORKOUT                               | NO_UNIT                                 | yes              | yes                       | See table below                                                                                                                    |
| WORKOUT_ROUTE                         | NO_UNIT                                 | yes              | yes                       | iOS 11+ and Android (as Exercise Route); use the workout route builder APIs described in the [Writing workout routes](#writing-workout-routes-ios--android) section above. |
| HIGH_HEART_RATE_EVENT                 | NO_UNIT                                 | yes              |                           | READ Only - requires Apple Watch to write the data                                                                                 |
| LOW_HEART_RATE_EVENT                  | NO_UNIT                                 | yes              |                           | READ Only - requires Apple Watch to write the data                                                                                 |
| IRREGULAR_HEART_RATE_EVENT            | NO_UNIT                                 | yes              |                           | READ Only - requires Apple Watch to write the data                                                                                 |
| HEART_RATE_VARIABILITY_RMSSD          | MILLISECOND                             |                  | yes                       |                                                                                                                                    |
| HEART_RATE_VARIABILITY_SDNN           | MILLISECOND                             | yes              |                           | Requires Apple Watch to write the data                                                                                             |
| HEADACHE_NOT_PRESENT                  | MINUTE                                  | yes              |                           |                                                                                                                                    |
| HEADACHE_MILD                         | MINUTE                                  | yes              |                           |                                                                                                                                    |
| HEADACHE_MODERATE                     | MINUTE                                  | yes              |                           |                                                                                                                                    |
| HEADACHE_SEVERE                       | MINUTE                                  | yes              |                           |                                                                                                                                    |
| HEADACHE_UNSPECIFIED                  | MINUTE                                  | yes              |                           |                                                                                                                                    |
| AUDIOGRAM                             | DECIBEL_HEARING_LEVEL                   | yes              |                           |                                                                                                                                    |
| ENVIRONMENTAL_AUDIO_EXPOSURE          | DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL | yes              |                           | Writes need an `endTime` after the `startTime`                                                                                     |
| HEADPHONE_AUDIO_EXPOSURE              | DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL | yes              |                           | Writes need an `endTime` after the `startTime`                                                                                     |
| ENVIRONMENTAL_SOUND_REDUCTION         | DECIBEL_A_WEIGHTED_SOUND_PRESSURE_LEVEL | yes              |                           | iOS 16+                                                                                                                            |
| ELECTROCARDIOGRAM                     | VOLT                                    | yes              |                           | READ Only - requires Apple Watch to write the data                                                                                 |
| NUTRITION                             | NO_UNIT                                 | yes              | yes                       |                                                                                                                                    |
| DIETARY_*                             | GRAM                                    | yes              |                           | One type per nutrient, such as `DIETARY_PROTEIN_CONSUMED`; `DIETARY_ENERGY_CONSUMED` is in KILOCALORIE. On Android, use `NUTRITION` |
| INSULIN_DELIVERY                      | INTERNATIONAL_UNIT                      | yes              |                           | Write with `writeInsulinDelivery`, not `writeHealthData`                                                                           |
| MENSTRUATION_FLOW                     | NO_UNIT                                 | yes              | yes                       | on iOS, write with `writeMenstruationFlow`, not `writeHealthData`                                                                  |
| WATER_TEMPERATURE                     | DEGREE_CELSIUS                          | yes              |                           | iOS 16+; related to/requires Apple Watch Ultra's Underwater Diving Workout                                                         |
| SLEEP_WRIST_TEMPERATURE               | DEGREE_CELSIUS                          | yes              |                           | READ Only - iOS 16+ (`appleSleepingWristTemperature`)                                                                              |
| APPLE_SLEEPING_BREATHING_DISTURBANCES | COUNT                                   | yes              |                           | READ Only - iOS 18+                                                                                                                |
| SKIN_TEMPERATURE                      | DEGREE_CELSIUS                          |                  | yes                       | Only where `isSkinTemperatureAvailable()` is true (see [Health Connect features](#health-connect-features))                         |
| UNDERWATER_DEPTH                      | METER                                   | yes              |                           | iOS 16+; related to/requires Apple Watch Ultra's Underwater Diving Workout                                                         |
| UV_INDEX                              | COUNT                                   | yes              |                           | iOS 16+                                                                                                                            |
| TIME_IN_DAYLIGHT                      | MINUTE                                  | yes              |                           | iOS 17+                                                                                                                            |
| LEAN_BODY_MASS                        | KILOGRAM                                | yes              | yes                       |                                                                                                                                    |
| WALKING_SPEED                         | METER_PER_SECOND                        | yes              |                           | Not on Android (`HealthErrorCode.notSupported`): use `SPEED`, which has the same unit                                              |
| WALKING_STEP_LENGTH                   | METER                                   | yes              |                           |                                                                                                                                    |
| WALKING_DOUBLE_SUPPORT_PERCENTAGE     | PERCENT                                 | yes              |                           |                                                                                                                                    |
| WALKING_ASYMMETRY_PERCENTAGE          | PERCENT                                 | yes              |                           | READ Only                                                                                                                          |
| APPLE_WALKING_STEADINESS              | PERCENT                                 | yes              |                           | READ Only                                                                                                                          |
| STAIR_ASCENT_SPEED                    | METER_PER_SECOND                        | yes              |                           |                                                                                                                                    |
| STAIR_DESCENT_SPEED                   | METER_PER_SECOND                        | yes              |                           |                                                                                                                                    |
| SIX_MINUTE_WALK_TEST_DISTANCE         | METER                                   | yes              |                           |                                                                                                                                    |
| SPEED                                 | METER_PER_SECOND                        |                  | yes                       | The speed of any exercise (`SpeedRecord`); for walking speed on iOS, see `WALKING_SPEED`                                           |
| RUNNING_SPEED                         | METER_PER_SECOND                        | yes              |                           | iOS 16+                                                                                                                            |
| RUNNING_POWER                         | WATT                                    | yes              |                           | iOS 16+                                                                                                                            |
| RUNNING_STRIDE_LENGTH                 | METER                                   | yes              |                           | iOS 16+                                                                                                                            |
| RUNNING_VERTICAL_OSCILLATION          | METER                                   | yes              |                           | iOS 16+                                                                                                                            |
| RUNNING_GROUND_CONTACT_TIME           | MILLISECOND                             | yes              |                           | iOS 16+                                                                                                                            |
| CYCLING_SPEED                         | METER_PER_SECOND                        | yes              |                           | iOS 17+                                                                                                                            |
| CROSS_COUNTRY_SKIING_SPEED            | METER_PER_SECOND                        | yes              |                           | iOS 18+                                                                                                                            |
| PADDLE_SPORTS_SPEED                   | METER_PER_SECOND                        | yes              |                           | iOS 18+                                                                                                                            |
| ROWING_SPEED                          | METER_PER_SECOND                        | yes              |                           | iOS 18+                                                                                                                            |
| POWER                                 | WATT                                    | yes              | yes                       | READ Only - iOS 17+ (`cyclingPower`); on Android the power of any exercise (`PowerRecord`)                                         |
| CYCLING_CADENCE                       | REVOLUTION_PER_MINUTE                   | yes              | yes                       | READ Only - iOS 17+ (`cyclingCadence`); on Android read with the `READ_EXERCISE` permission                                        |
| CYCLING_FUNCTIONAL_THRESHOLD_POWER    | WATT                                    | yes              |                           | iOS 17+                                                                                                                            |
| APPLE_MOVE_TIME                       | SECOND                                  | yes              |                           | READ Only                                                                                                                          |
| APPLE_STAND_HOUR                      | HOUR                                    | yes              |                           | READ Only                                                                                                                          |
| APPLE_STAND_TIME                      | SECOND                                  | yes              |                           | READ Only                                                                                                                          |

## Workout Types

The plugin supports the following [`HealthWorkoutActivityType`](https://pub.dev/documentation/health/latest/health/HealthWorkoutActivityType.html).

Some names share one workout type on a platform, as the comments below show. A name marked "(yes)" is written as the workout type of another name. Reads give one name for each such type, whichever name the workout was written with: DANCING, SKIING or WHEELCHAIR on Android, and RUNNING, CLIMBING or SWIMMING on iOS. On iOS the workout's metadata can refine this name: an indoor run reads as RUNNING_TREADMILL, and a swim with a pool or open water location as SWIMMING_POOL or SWIMMING_OPEN_WATER. `WorkoutSummary.workoutType` is this name too, on both platforms: before 14.0.0 it was HealthKit's own name on iOS, such as `running`, and `workoutSummary` was `null` on Android.

Writing a workout type that the platform has no workout type for throws a `HealthException` with `HealthErrorCode.notSupported` before anything is written, for example ARCHERY or CURLING on Android, DANCING on iOS, and WALKING_TREADMILL on both.

| **Workout Type**                 | **Apple Health** | **Google Health Connect** | **Comments**                                                                                    |
| -------------------------------- | ---------------- | ------------------------- | ----------------------------------------------------------------------------------------------- |
| AMERICAN_FOOTBALL                | yes              | yes                       |                                                                                                 |
| ARCHERY                          | yes              |                           |                                                                                                 |
| AUSTRALIAN_FOOTBALL              | yes              | yes                       |                                                                                                 |
| BADMINTON                        | yes              | yes                       |                                                                                                 |
| BARRE                            | yes              |                           |                                                                                                 |
| BASEBALL                         | yes              | yes                       |                                                                                                 |
| BASKETBALL                       | yes              | yes                       |                                                                                                 |
| BIKING                           | yes              | yes                       | on iOS this is CYCLING, but name changed here to fit with Android                               |
| BIKING_STATIONARY                |                  | yes                       |                                                                                                 |
| BOWLING                          | yes              |                           |                                                                                                 |
| BOXING                           | yes              | yes                       |                                                                                                 |
| CALISTHENICS                     |                  | yes                       |                                                                                                 |
| CARDIO_DANCE                     | yes              | (yes)                     | on Android this will be stored and read back as DANCING                                         |
| CLIMBING                         | yes              |                           |                                                                                                 |
| COOLDOWN                         | yes              |                           |                                                                                                 |
| CORE_TRAINING                    | yes              |                           |                                                                                                 |
| CRICKET                          | yes              | yes                       |                                                                                                 |
| CROSS_COUNTRY_SKIING             | yes              | (yes)                     | on Android this will be stored and read back as SKIING                                          |
| CROSS_TRAINING                   | yes              |                           |                                                                                                 |
| CURLING                          | yes              |                           |                                                                                                 |
| DANCING                          |                  | yes                       | not on iOS (`HealthErrorCode.notSupported`): use CARDIO_DANCE or SOCIAL_DANCE                   |
| DISC_SPORTS                      | yes              |                           |                                                                                                 |
| DOWNHILL_SKIING                  | yes              | (yes)                     | on Android this will be stored and read back as SKIING                                          |
| ELLIPTICAL                       | yes              | yes                       |                                                                                                 |
| EQUESTRIAN_SPORTS                | yes              |                           |                                                                                                 |
| FENCING                          | yes              | yes                       |                                                                                                 |
| FISHING                          | yes              |                           |                                                                                                 |
| FITNESS_GAMING                   | yes              |                           |                                                                                                 |
| FLEXIBILITY                      | yes              |                           |                                                                                                 |
| FRISBEE_DISC                     |                  | yes                       |                                                                                                 |
| FUNCTIONAL_STRENGTH_TRAINING     | yes              |                           | on Android use STRENGTH_TRAINING                                                                |
| GOLF                             | yes              | yes                       |                                                                                                 |
| GUIDED_BREATHING                 |                  | yes                       |                                                                                                 |
| GYMNASTICS                       | yes              | yes                       |                                                                                                 |
| HAND_CYCLING                     | yes              |                           |                                                                                                 |
| HANDBALL                         | yes              | yes                       |                                                                                                 |
| HIGH_INTENSITY_INTERVAL_TRAINING | yes              | yes                       |                                                                                                 |
| HIKING                           | yes              | yes                       |                                                                                                 |
| HOCKEY                           | yes              | yes                       | on Android this is Health Connect's ice hockey; its roller hockey reads as OTHER                |
| HUNTING                          | yes              |                           |                                                                                                 |
| ICE_SKATING                      |                  | yes                       |                                                                                                 |
| JUMP_ROPE                        | yes              |                           |                                                                                                 |
| KICKBOXING                       | yes              |                           |                                                                                                 |
| LACROSSE                         | yes              |                           |                                                                                                 |
| MARTIAL_ARTS                     | yes              | yes                       |                                                                                                 |
| MIND_AND_BODY                    | yes              |                           |                                                                                                 |
| MIXED_CARDIO                     | yes              |                           |                                                                                                 |
| PADDLE_SPORTS                    | yes              | yes                       | on Android this is Health Connect's paddling                                                    |
| PARAGLIDING                      |                  | yes                       |                                                                                                 |
| PICKLEBALL                       | yes              |                           |                                                                                                 |
| PILATES                          | yes              | yes                       |                                                                                                 |
| PLAY                             | yes              |                           |                                                                                                 |
| PREPARATION_AND_RECOVERY         | yes              |                           |                                                                                                 |
| RACQUETBALL                      | yes              | yes                       |                                                                                                 |
| ROCK_CLIMBING                    | (yes)            | yes                       | on iOS this will be stored and read back as CLIMBING                                            |
| ROWING                           | yes              | yes                       |                                                                                                 |
| ROWING_MACHINE                   |                  | yes                       |                                                                                                 |
| RUGBY                            | yes              | yes                       |                                                                                                 |
| RUNNING                          | yes              | yes                       |                                                                                                 |
| RUNNING_TREADMILL                | (yes)            | yes                       | on iOS this will be stored as an indoor RUNNING workout and read back as RUNNING_TREADMILL      |
| SAILING                          | yes              | yes                       |                                                                                                 |
| SCUBA_DIVING                     |                  | yes                       |                                                                                                 |
| SKATING                          | yes              | yes                       | On iOS this will be stored as SKATING_SPORTS                                                    |
| SKIING                           |                  | yes                       | not on iOS (`HealthErrorCode.notSupported`): use CROSS_COUNTRY_SKIING or DOWNHILL_SKIING        |
| SNOW_SPORTS                      | yes              |                           |                                                                                                 |
| SNOWBOARDING                     | yes              | yes                       |                                                                                                 |
| SNOWSHOEING                      |                  | yes                       |                                                                                                 |
| SOCCER                           | yes              | yes                       |                                                                                                 |
| SOCIAL_DANCE                     | yes              | (yes)                     | on Android this will be stored and read back as DANCING                                         |
| SOFTBALL                         | yes              | yes                       |                                                                                                 |
| SQUASH                           | yes              | yes                       |                                                                                                 |
| STAIR_CLIMBING                   | yes              | yes                       |                                                                                                 |
| STAIR_CLIMBING_MACHINE           |                  | yes                       |                                                                                                 |
| STAIRS                           | yes              |                           |                                                                                                 |
| STEP_TRAINING                    | yes              |                           |                                                                                                 |
| STRENGTH_TRAINING                |                  | yes                       | not on iOS (`HealthErrorCode.notSupported`): use FUNCTIONAL_STRENGTH_TRAINING or TRADITIONAL_STRENGTH_TRAINING |
| SURFING                          | yes              | yes                       | on iOS this is SURFING_SPORTS, but name changed here to fit with Android                        |
| SWIMMING                         | yes              |                           | not on Android (`HealthErrorCode.notSupported`): use SWIMMING_POOL or SWIMMING_OPEN_WATER       |
| SWIMMING_OPEN_WATER              | (yes)            | yes                       | on iOS this will be stored as SWIMMING in open water and read back as SWIMMING_OPEN_WATER       |
| SWIMMING_POOL                    | (yes)            | yes                       | on iOS this is stored as a pool swim and read back as SWIMMING_POOL when written with `swimming: SwimmingDetails(poolLength: ...)`; without a pool length it is stored and read back as SWIMMING (HealthKit needs a lap length for a pool swim) |
| TABLE_TENNIS                     | yes              | yes                       |                                                                                                 |
| TAI_CHI                          | yes              |                           |                                                                                                 |
| TENNIS                           | yes              | yes                       |                                                                                                 |
| TRACK_AND_FIELD                  | yes              |                           |                                                                                                 |
| TRADITIONAL_STRENGTH_TRAINING    | yes              |                           | on Android use STRENGTH_TRAINING                                                                |
| UNDERWATER_DIVING                | yes              |                           | iOS 17+; on earlier iOS versions, writing it throws a `PlatformException` with code `WRITE_ERROR` |
| VOLLEYBALL                       | yes              | yes                       |                                                                                                 |
| WALKING                          | yes              | yes                       |                                                                                                 |
| WALKING_TREADMILL                |                  |                           | supported on neither platform: HealthKit and Health Connect have no treadmill walking type      |
| WATER_FITNESS                    | yes              |                           |                                                                                                 |
| WATER_POLO                       | yes              | yes                       |                                                                                                 |
| WATER_SPORTS                     | yes              |                           |                                                                                                 |
| WEIGHTLIFTING                    |                  | yes                       |                                                                                                 |
| WHEELCHAIR                       |                  | yes                       | not on iOS (`HealthErrorCode.notSupported`): use WHEELCHAIR_RUN_PACE or WHEELCHAIR_WALK_PACE    |
| WHEELCHAIR_RUN_PACE              | yes              | (yes)                     | on Android this will be stored and read back as WHEELCHAIR                                      |
| WHEELCHAIR_WALK_PACE             | yes              | (yes)                     | on Android this will be stored and read back as WHEELCHAIR                                      |
| WRESTLING                        | yes              |                           |                                                                                                 |
| YOGA                             | yes              | yes                       |                                                                                                 |
| OTHER                            | yes              | yes                       |                                                                                                 |

## License

This software is copyright (c) the [Technical University of Denmark (DTU)](https://www.dtu.dk) and is part of the [Copenhagen Research Platform](https://carp.cachet.dk/).
This software is available 'as-is' under a [MIT license](LICENSE).
