# Health

Enables reading and writing health data from/to [Apple Health](https://www.apple.com/health/) and [Google Health Connect](https://health.google/health-connect-android/).

> **NOTE:** Google has deprecated the Google Fit API. According to the [documentation](https://developers.google.com/fit/android), as of **May 1st 2024** developers cannot sign up for using the API. As such, this package has removed support for Google Fit as of version 11.0.0 and users are urged to upgrade as soon as possible.

The plugin supports:

- handling permissions to access health data using the `hasPermissions`, `requestAuthorization`, `revokePermissions` methods.
- reading health data using the `getHealthDataFromTypes` method.
- reading large amounts of health data page by page using the `getHealthDataPages` method.
- reading health data aggregated over time intervals using the `getHealthIntervalDataFromTypes` method.
- writing health data using the `writeHealthData` method.
- writing workouts using the `writeWorkoutData` method.
- writing workout routes on iOS and Android using the `startWorkoutRoute` / `insertWorkoutRouteData` / `finishWorkoutRoute` methods.
- writing a sleep session with its stages, such as a night of sleep, on iOS & Android using the `writeSleepSession` method.
- writing meals on iOS (Apple Health) & Android using the `writeMeal` method.
- writing audiograms on iOS using the `writeAudiogram` method.
- writing blood pressure data using the `writeBloodPressure` method.
- accessing total step counts using the `getTotalStepsInInterval` method.
- cleaning up duplicate data points via the `removeDuplicates` method.
- removing data of a given type in a selected period of time using the `delete` method.

Note that on Android 13 and lower, the phone **needs** the [Health Connect](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata&hl=en) app from Google Play: check with `isHealthConnectAvailable` and, if it returns `false`, offer `installHealthConnect`. From Android 14 on, Health Connect is part of Android.

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

If you plan to read or write Activity Intensity records (the `HealthDataType.ACTIVITY_INTENSITY` type), be sure to add the corresponding Health Connect permissions introduced with that data type:

```xml
<uses-permission android:name="android.permission.health.READ_ACTIVITY_INTENSITY"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVITY_INTENSITY"/>
```

By default, Health Connect restricts read data to 30 days from when permission has been granted.

You can check and request access to historical data using the `isHealthDataHistoryAuthorized` and `requestHealthDataHistoryAuthorization` methods, respectively.

The above methods require the following permission to be declared:

```xml
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_HISTORY"/>
```

Accessing fitness data (e.g. Steps) requires permission to access the "Activity Recognition" API. To set it add the following line to your `AndroidManifest.xml` file.

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
```

Additionally, for workouts, if the distance of a workout is requested then the location permissions below are needed.

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

#### Android 14

This plugin uses the new `registerForActivityResult` when requesting permissions from Health Connect.
In order for that to work, the Main app's activity should extend `FlutterFragmentActivity` instead of `FlutterActivity`.
This adjustment allows casting from `Activity` to `ComponentActivity` for accessing `registerForActivityResult`.

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

Reads return a sleep data point when it starts in the range: a stage when the stage starts in it, whichever session it belongs to, and on Android a `SLEEP_SESSION` when the session starts in it. Reads of consecutive ranges therefore return each point once; to read a whole night, read up to its end. On Android, the stages of sessions that began up to 24 hours before `startTime` are found, and the stages of one session come together, so the stages of overlapping sessions (from different apps) are not in one time order.

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

where a [`HealthValue`](https://pub.dev/documentation/health/latest/health/HealthValue-class.html) is a `NumericHealthValue` (most types), `AudiogramHealthValue` (`AUDIOGRAM`), `ElectrocardiogramHealthValue` (`ELECTROCARDIOGRAM`; its `voltageValues` are `ElectrocardiogramVoltageValue`s), `InsulinDeliveryHealthValue` (`INSULIN_DELIVERY`), `MenstruationFlowHealthValue` (`MENSTRUATION_FLOW`), `NutritionHealthValue` (`NUTRITION`), `ActivityIntensityHealthValue` (`ACTIVITY_INTENSITY`), `SkinTemperatureHealthValue` (`SKIN_TEMPERATURE`), `WorkoutHealthValue` (`WORKOUT`) or `WorkoutRouteHealthValue` (`WORKOUT_ROUTE`). `getHealthIntervalDataFromTypes` returns a `NumericHealthValue` for every type.

`metadata` is set for iOS quantity and category samples, such as steps, heart rate and sleep (their HealthKit metadata, an empty map if there is none), and for workout routes on both platforms (for example `route_point_count`); it is `null` for other data. `deviceModel` is `null` in data read from Apple Health and Health Connect.

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
  "metadata": {}
}
```

### Fetch health data

See the example app for a showcasing of how it's done.

**Note** On iOS the device must be unlocked before health data can be requested. Otherwise the read throws a `HealthPlatformException` with `errorCode` `HealthErrorCode.deviceLocked` (native code `DEVICE_LOCKED`), which is retryable once the device is unlocked. See [Error handling](#error-handling).

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

- Types are read one after another, each type once. Within a type, points are oldest first and without duplicates: on Android in the order of their records' start times, on iOS by end time. On Android the samples of one heart rate, speed, power, cycling cadence or skin temperature record come together, as do the stages of one sleep session, so the samples of overlapping records from different apps are not merged into one time order.
- Each type ends with exactly one page whose `isLastPageForType` is true; it is empty if the type had no more data. All other pages hold at least one point.
- A missing read permission is not an error. On Android, the type then has a single empty page with `readPermissionDenied` set.
- An error ends the stream; pages already delivered stay valid. Cancelling the subscription stops the read: no platform call is made after it, and `cancel()` completes once the call in flight has returned (an error it reports is dropped).
- `getHealthDataFromTypes` keeps every point in memory until it returns, which means long garbage collection pauses at millions of points. On iOS it still returns points newest first.

**Page size.** `pageSize` is the target number of data points per platform call: 20,000 by default, at most 50,000. Bigger pages need fewer Health Connect calls (see [Health Connect limits](#health-connect-limits)) but more memory per call. On Android a heart rate page holds at most about `pageSize` samples, however they are spread over records; a record is never split, so one record with more samples makes a larger page. Set it for an instance with `Health(pageSize: 5000)` or `health.pageSize = 5000`, or for one read with `getHealthDataPages(..., pageSize: 5000)`.

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

**Resuming.** The plugin does not keep track of what you have read. To sync a long range robustly, read it in time windows and record your progress per finished window; after an interruption, read the unfinished window again. Every read has a fixed cost in Health Connect calls (see [Health Connect limits](#health-connect-limits)), so prefer windows of a week or a month to windows of a day. Each window returns the samples inside it: a heart rate, speed, power, cycling cadence or skin temperature record that crosses a boundary is split between the two windows (on Android, records that began more than 24 hours before a window are not looked for). Reads are at-least-once at such a boundary: a point you already stored can be returned again. A sleep data point is returned in the window it starts in, so consecutive windows return it once (on Android, the stages of sessions that began more than 24 hours before a window are not looked for). Store points with an upsert keyed by `(type, uuid, dateFrom)`; on Android, the heart rate samples of one record share the record's `uuid`.

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
- The value of every point is a `NumericHealthValue` in the type's unit (see [Data Types](#data-types)): the sum for cumulative types such as steps, energy, distance and water, and the average for other types. For heart rate, that is the average beats per minute: HealthKit weights each sample by the time it covers, Health Connect takes the mean of the samples. On Android, activity intensity intervals hold the intensity minutes Health Connect computes.
- For a sleep type, the value is the number of minutes of the interval that the type's data points cover (the points `getHealthDataFromTypes` returns for the type), with overlapping points counted once. A point that began before `startDate` counts with its part after it; on Android, sleep sessions that began up to 24 hours before `startDate` are read for this. For the time in bed, use `SLEEP_SESSION` (the whole session) on Android and `SLEEP_IN_BED` on iOS.
- Not every type has intervals. On Android, a type without them returns no data points; on iOS, it throws a `HealthPlatformException` with `HealthErrorCode.invalidArgument`. The documentation of `getHealthIntervalDataFromTypes` lists the types of each platform.

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
| `permissionDenied`  | `PERMISSION_DENIED`         | The call needs a permission the app does not have, for example a background read without `READ_HEALTH_DATA_IN_BACKGROUND`, on Android `getHealthIntervalDataFromTypes` or `getTotalStepsInInterval` without the type's read permission, or, on iOS, a type the app never requested authorization for. In `getHealthDataFromTypes` and `getHealthDataPages`, a denied read permission for a type is not an error: the type returns no data. | no            |
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
| `getHealthDataFromTypes`                                                 | Throws `HealthPlatformException`. An empty list only means no data or, on Android, no read permission. Before 14.0.0, Android returned an empty list on any failure.                            |
| `getHealthDataPages`                                                     | The stream emits the `HealthPlatformException` (or `HealthException`) and closes.                                                                                                                |
| `getHealthIntervalDataFromTypes`                                         | Throws `HealthPlatformException`, for example with `permissionDenied` on Android without the type's read permission.                                                                             |
| `getHealthDataByUUID`                                                    | Returns `null` if the record is not found, and throws `HealthPlatformException` on other failures.                                                                                              |
| `getTotalStepsInInterval`                                                | Throws `HealthPlatformException`, for example with `permissionDenied` on Android without the steps read permission (HealthKit returns 0 without it). It returns 0 when there are no steps. Before 14.0.0, Android returned `null` on any failure. |
| `getChangesToken`, `getChanges`                                          | Throw `HealthPlatformException`. They return `null` only on iOS, which has no Health Connect. If Health Connect cannot return the pending changes because they are too many, or a single change holds more than 100,000 data points, `getChanges` returns `changesTokenExpired: true`: create a new token and read the data again. A larger page of changes is read again with fewer changes. Before 14.0.0, both returned `null` on any failure. |
| `getHealthAggregateDataFromTypes`                                        | Deprecated: throws an `UnsupportedError` without calling the platform. It has not worked on either platform since Google Fit was removed; use `getHealthIntervalDataFromTypes` instead.        |
| `writeSleepSession`                                                      | Throws an `ArgumentError` before anything is written if `startTime` is not before `endTime`, a stage is not valid (see [Writing a night of sleep](#writing-a-night-of-sleep-ios--android)) or, on iOS, `recordingMethod` is not `manual` or `automatic`. Returns `false` if the platform does not save the session. On iOS, a session HealthKit does not accept, such as one longer than 4 days, throws a `PlatformException` with code `INVALID_ARGUMENT`. |
| Other writes, deletes, permissions and the Health Connect helpers        | As before 14.0.0, most return `false` on failure. Calls that crashed the app or never returned now fail instead: on iOS, data HealthKit does not accept, such as a sample longer than its type allows, throws a `PlatformException` with code `INVALID_ARGUMENT`, and on Android, `hasPermissions` throws a `PlatformException` when Health Connect fails. On Android, `writeHealthData` and `writeHealthDataUUID` of a type Health Connect stores with a duration (such as `STEPS`) whose `endTime` equals `startTime` throw a `PlatformException` with code `INVALID_ARGUMENT`. |

New in 14.0.0, on Android a `preferredUnits` entry that Health Connect values are not converted to throws a `HealthException` with `errorCode` `invalidArgument` before anything is read; before, the values were labelled with that unit without being converted to it. Other errors are as before: a `HealthException` (now with `errorCode` `notSupported`) when a data type is not available on the platform, which is checked for all types before anything is read; an `UnsupportedError` when Health Connect is not installed; and `ArgumentError`s for invalid arguments. A `MissingPluginException` is passed on as it is.

### Health Connect limits

Health Connect limits how often each app may call it. When a quota is used up, reads throw a `HealthPlatformException` with `HealthErrorCode.rateLimitExceeded` until the quota window has passed (writes return `false`). The quotas are part of the Health Connect module, so **they vary with the Health Connect version** and may change at any time. These are the values measured on two devices:

| Quota per app           | Pixel 8a, Android 17               | Android 16 emulator               |
| ----------------------- | ---------------------------------- | --------------------------------- |
| Reads in the foreground | 80,000 per 15 min, 80,000 per 24 h | 2,000 per 15 min, 16,000 per 24 h |
| Reads in the background | 1,000 per 15 min, 8,000 per 24 h   | 1,000 per 15 min, 8,000 per 24 h  |
| Writes                  | 1,000 per 15 min, 8,000 per 24 h   | 1,000 per 15 min, 8,000 per 24 h  |
| Data written            | 35 MB per 15 min                   | 35 MB per 15 min                  |
| Size of a request       | 5 MB, and 1 MB per record          | 5 MB, and 1 MB per record         |

The plugin reads Health Connect page by page, and every page is a call. What a read costs:

| Read                                                  | Health Connect calls                                                                                                                                                                                                                                                                                         |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| A type with one value per record (steps, weight, ...) | 1 permission check + 1 per 5,000 records (per `pageSize` records if that is smaller)                                                                                                                                                                                                                                        |
| Heart rate                                            | 1 permission check + 1 per page + 1 count of the samples per about 8 pages (a page holds at most `pageSize` samples, give or take one record) + 1 per record that holds more than `pageSize / 2` samples + 1–4 to look for records that began before `startTime`, if one reaches into the read. For example, a week of heart rate at one sample per second (600,000 samples) costs about 37 calls at the default `pageSize`, and 30 days at one sample per minute about 13. The same on every Android version. |
| Speed, power, cycling cadence and skin temperature    | 1 permission check + 1 look-back read + 1 per `pageSize / 3600` records (5 at the default `pageSize`): a record may hold an hour of samples at one per second, and Health Connect has no count of these samples to plan by. |
| Workouts                                              | Per 20 workouts: 1 permission check + 1 read + up to 3 per workout for its distance, calories and steps                                                                                                                                                                                                      |
| Sleep types                                           | 1 permission check + 1 per 500 sleep sessions (per `pageSize` sessions if that is smaller); a stage type (not `SLEEP_SESSION`) also reads the sessions that began in the 24 hours before `startTime`: 1 more per 500 sessions                                                                                |
| `getTotalStepsInInterval(includeManualEntry: false)`  | 1 per 5,000 step records                                                                                                                                                                                                                                                                                     |
| `getHealthIntervalDataFromTypes`                      | 1 per type. A sleep type reads the sleep sessions from 24 hours before `startDate` to `endDate` instead: 1 per 500 sessions                                                                                                                                                                                  |
| `getChanges`                                          | 1 per call, and 1 more each time a page of changes that holds more than 100,000 data points is read again with fewer changes                                                                                                                                                                                 |

Checking the granted permissions did not count against the read quota on the Android 16 emulator.

To stay within the quotas, read large ranges in the foreground (the background quota is much smaller), prefer a few long reads over many short ones, keep the default `pageSize` or raise it for heart rate data, and call `getChanges` instead of re-reading data you already have.

### Fetch single health data by UUID

In order to retrieve a single record, it is required to provide `String uuid` and `HealthDataType type`.

Please see example below:
```dart
HealthDataPoint? healthPoint = await health.getHealthDataByUUID(
  uuid: 'random-uuid-string',
  type: HealthDataType.STEPS,
);
```
```
I/FLUTTER_HEALTH( 9161): Success: {uuid=random-uuid-string, value=12, date_from=1742259061009, date_to=1742259092888, source_id=, source_name=com.google.android.apps.fitness, recording_method=0}
```
> Assuming that the `uuid` and `type` are coming from your database.

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

**NOTE**: On iOS, only `RecordingMethod.manual` can be filtered out: HealthKit marks only the samples the user entered (`HKMetadataKeyWasUserEntered`), so the other recording methods in `recordingMethodsToFilter` are ignored. In `getHealthIntervalDataFromTypes` on Android, only the sleep types are filtered: the intervals of the other types are Health Connect aggregates, which include data of every recording method. A filter that cannot be applied prints a warning to the console.

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

`==`, and so `removeDuplicates`, compares every field of the points, including the `sourceDeviceId` and the contents of their `metadata` (before 14.0.0 a point with `metadata`, such as every iOS sample, was never equal to the same data read again). To match points only by the record they come from, compare `type`, `uuid` and `dateFrom`, the key recommended for resuming reads in [Reading large amounts of data](#reading-large-amounts-of-data):

```dart
final seen = <(HealthDataType, String, DateTime)>{};
points = points.where((p) => seen.add((p.type, p.uuid, p.dateFrom))).toList();
```

### Android: Reading Health Data in Background
Currently health connect allows apps to read health data in the background. In order to achieve this add the following permission to your `AndroidManifest.XML`:
```XML
<!-- For reading data in background -->
<uses-permission android:name="android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND"/>
```
Furthermore, the plugin now exposes three new functions to help you check and request access to read data in the background:
1. `isHealthDataInBackgroundAvailable()`: Checks if the Health Data in Background feature is available
2. `isHealthDataInBackgroundAuthorized()`: Checks the current status of the Health Data in Background permission
3. `requestHealthDataInBackgroundAuthorization()`: Requests the Health Data in Background permission.

### Fetch single health data by UUID

In order to retrieve a single record, it is required to provide `String uuid` and `HealthDataType type`.

Please see example below:
```dart
HealthDataPoint? healthPoint = await health.getHealthDataByUUID(
  uuid: 'E9F2EEAD-8FC5-4CE5-9FF5-7C4E535FB8B8',
  type: HealthDataType.WORKOUT,
);
```
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
    unit: NO_UNIT,
    dateFrom: 2025-05-02 07:31:00.000,
    dateTo: 2025-05-02 08:25:00.000,
    dataType: WORKOUT,
    platform: HealthPlatformType.appleHealth,
    deviceId: F74938B9-C011-4DE4-AA5E-CF41B60B96E7,
    sourceId: com.apple.Health,
    sourceName: Health
    recordingMethod: RecordingMethod.manual
    workoutSummary: WorkoutSummary - workoutType: RUNNINGtotalDistance: 2400, totalEnergyBurned: 0, totalSteps: 0
    metadata: null
    deviceModel: null
```
> Assuming that the `uuid` and `type` are coming from your database.


## Data Types

The plugin supports the following [`HealthDataType`](https://pub.dev/documentation/health/latest/health/HealthDataType.html).

| **Data Type**                | **Unit**                | **Apple Health** | **Google Health Connect** | **Comments**                                                                                                                       |
| ---------------------------- | ----------------------- | ---------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| ACTIVE_ENERGY_BURNED         | KILOCALORIE             | yes              | yes                       |                                                                                                                                    |
| ACTIVITY_INTENSITY           | MINUTES                 |                  | yes                       | Write with `writeActivityIntensity`, not `writeHealthData`; reads give an `ActivityIntensityHealthValue`                           |
| ATRIAL_FIBRILLATION_BURDEN   | PERCENTAGE              | yes              |                           |                                                                                                                                    |
| BASAL_ENERGY_BURNED          | KILOCALORIE             | yes              | yes                       | on Android, Health Connect's basal metabolic rate (`BasalMetabolicRateRecord`) in kilocalories per day                             |
| BIRTH_DATE                   | NO_UNIT                 | yes              |                           | READ Only - a HealthKit characteristic: the birth date in seconds since 1970                                                       |
| BLOOD_GLUCOSE                | MILLIGRAM_PER_DECILITER | yes              | yes                       |                                                                                                                                    |
| BLOOD_OXYGEN                 | PERCENTAGE              | yes              | yes                       |                                                                                                                                    |
| BLOOD_PRESSURE_DIASTOLIC     | MILLIMETER_OF_MERCURY   | yes              | yes                       |                                                                                                                                    |
| BLOOD_PRESSURE_SYSTOLIC      | MILLIMETER_OF_MERCURY   | yes              | yes                       |                                                                                                                                    |
| BLOOD_TYPE                   | NO_UNIT                 | yes              |                           | READ Only - a HealthKit characteristic: the `HKBloodType` raw value                                                                |
| BODY_FAT_PERCENTAGE          | PERCENTAGE              | yes              | yes                       |                                                                                                                                    |
| BODY_MASS_INDEX              | NO_UNIT                 | yes              | yes                       |                                                                                                                                    |
| BODY_TEMPERATURE             | DEGREE_CELSIUS          | yes              | yes                       |                                                                                                                                    |
| BODY_WATER_MASS              | KILOGRAMS               |                  | yes                       |                                                                                                                                    |
| ELECTRODERMAL_ACTIVITY       | SIEMENS                 | yes              |                           |                                                                                                                                    |
| FORCED_EXPIRATORY_VOLUME     | LITER                   | yes              |                           | HealthKit's `forcedExpiratoryVolume1` (FEV1)                                                                                       |
| GENDER                       | NO_UNIT                 | yes              |                           | READ Only - a HealthKit characteristic: the `HKBiologicalSex` raw value                                                            |
| HEART_RATE                   | BEATS_PER_MINUTE        | yes              | yes                       |                                                                                                                                    |
| HEIGHT                       | METERS                  | yes              | yes                       |                                                                                                                                    |
| RESTING_HEART_RATE           | BEATS_PER_MINUTE        | yes              | yes                       |                                                                                                                                    |
| RESPIRATORY_RATE             | RESPIRATIONS_PER_MINUTE | yes              | yes                       |                                                                                                                                    |
| PERIPHERAL_PERFUSION_INDEX   | PERCENTAGE              | yes              |                           |                                                                                                                                    |
| STEPS                        | COUNT                   | yes              | yes                       |                                                                                                                                    |
| TOTAL_CALORIES_BURNED        | KILOCALORIE             |                  | yes                       | Active and basal energy together (`TotalCaloriesBurnedRecord`)                                                                     |
| WAIST_CIRCUMFERENCE          | METERS                  | yes              |                           |                                                                                                                                    |
| WALKING_HEART_RATE           | BEATS_PER_MINUTE        | yes              |                           |                                                                                                                                    |
| WEIGHT                       | KILOGRAMS               | yes              | yes                       |                                                                                                                                    |
| DISTANCE_WALKING_RUNNING     | METERS                  | yes              |                           |                                                                                                                                    |
| DISTANCE_CYCLING             | METERS                  | yes              |                           |                                                                                                                                    |
| DISTANCE_SWIMMING            | METERS                  | yes              |                           |                                                                                                                                    |
| FLIGHTS_CLIMBED              | COUNT                   | yes              | yes                       |                                                                                                                                    |
| DISTANCE_DELTA               | METERS                  |                  | yes                       |                                                                                                                                    |
| MINDFULNESS                  | MINUTES                 | yes              |                           |                                                                                                                                    |
| SLEEP_ASLEEP                 | MINUTES                 | yes              | yes                       | on iOS, this refers to asleepUnspecified, and on Android this refers to STAGE_TYPE_SLEEPING (asleep but specific stage is unknown) |
| SLEEP_AWAKE                  | MINUTES                 | yes              | yes                       |                                                                                                                                    |
| SLEEP_AWAKE_IN_BED           | MINUTES                 |                  | yes                       |                                                                                                                                    |
| SLEEP_DEEP                   | MINUTES                 | yes              | yes                       |                                                                                                                                    |
| SLEEP_IN_BED                 | MINUTES                 | yes              |                           |                                                                                                                                    |
| SLEEP_LIGHT                  | MINUTES                 | yes              | yes                       | on iOS, this refers to asleepCore                                                                                                  |
| SLEEP_OUT_OF_BED             | MINUTES                 |                  | yes                       |                                                                                                                                    |
| SLEEP_REM                    | MINUTES                 | yes              | yes                       |                                                                                                                                    |
| SLEEP_UNKNOWN                | MINUTES                 | yes              | yes                       | on iOS, sleep values that no other sleep type covers (none yet; values Apple adds later), READ Only; on Android, STAGE_TYPE_UNKNOWN |
| SLEEP_SESSION                | MINUTES                 |                  | yes                       |                                                                                                                                    |
| WATER                        | LITER                   | yes              | yes                       |                                                                                                                                    |
| EXERCISE_TIME                | MINUTES                 | yes              |                           |                                                                                                                                    |
| WORKOUT                      | NO_UNIT                 | yes              | yes                       | See table below                                                                                                                    |
| WORKOUT_ROUTE                | NO_UNIT                 | yes              | yes                       | iOS 11+ and Android (as Exercise Route); use the workout route builder APIs described in the [Writing workout routes](#writing-workout-routes-ios--android) section above. |
| HIGH_HEART_RATE_EVENT        | NO_UNIT                 | yes              |                           | Requires Apple Watch to write the data                                                                                             |
| LOW_HEART_RATE_EVENT         | NO_UNIT                 | yes              |                           | Requires Apple Watch to write the data                                                                                             |
| IRREGULAR_HEART_RATE_EVENT   | NO_UNIT                 | yes              |                           | Requires Apple Watch to write the data                                                                                             |
| HEART_RATE_VARIABILITY_RMSSD | MILLISECONDS            |                  | yes                       |                                                                                                                                    |
| HEART_RATE_VARIABILITY_SDNN  | MILLISECONDS            | yes              |                           | Requires Apple Watch to write the data                                                                                             |
| HEADACHE_NOT_PRESENT         | MINUTES                 | yes              |                           |                                                                                                                                    |
| HEADACHE_MILD                | MINUTES                 | yes              |                           |                                                                                                                                    |
| HEADACHE_MODERATE            | MINUTES                 | yes              |                           |                                                                                                                                    |
| HEADACHE_SEVERE              | MINUTES                 | yes              |                           |                                                                                                                                    |
| HEADACHE_UNSPECIFIED         | MINUTES                 | yes              |                           |                                                                                                                                    |
| AUDIOGRAM                    | DECIBEL_HEARING_LEVEL   | yes              |                           |                                                                                                                                    |
| ELECTROCARDIOGRAM            | VOLT                    | yes              |                           | Requires Apple Watch to write the data                                                                                             |
| NUTRITION                    | NO_UNIT                 | yes              | yes                       |                                                                                                                                    |
| DIETARY_*                    | GRAM                    | yes              |                           | One type per nutrient, such as `DIETARY_PROTEIN_CONSUMED`; `DIETARY_ENERGY_CONSUMED` is in KILOCALORIE. On Android, use `NUTRITION` |
| INSULIN_DELIVERY             | INTERNATIONAL_UNIT      | yes              |                           | Write with `writeInsulinDelivery`, not `writeHealthData`                                                                           |
| MENSTRUATION_FLOW            | NO_UNIT                 | yes              | yes                       | on iOS, write with `writeMenstruationFlow`, not `writeHealthData`                                                                  |
| WATER_TEMPERATURE            | DEGREE_CELSIUS          | yes              |                           | Related to/Requires Apple Watch Ultra's Underwater Diving Workout                                                                  |
| SLEEP_WRIST_TEMPERATURE      | DEGREE_CELSIUS          | yes              |                           | READ Only - `appleSleepingWristTemperature`                                                                                        |
| SKIN_TEMPERATURE             | DEGREE_CELSIUS          |                  | yes                       | Must check health connect for availability                                                                                         |
| UNDERWATER_DEPTH             | METER                   | yes              |                           | Related to/Requires Apple Watch Ultra's Underwater Diving Workout                                                                  |
| UV_INDEX                     | COUNT                   | yes              |                           |                                                                                                                                    |
| LEAN_BODY_MASS               | KILOGRAMS               | yes              | yes                       |                                                                                                                                    |
| WALKING_SPEED                | METER_PER_SECOND        | yes              | (yes)                     | On Android use `SPEED`, which has the same unit                                                                                    |
| SPEED                        | METER_PER_SECOND        |                  | yes                       | The speed of any exercise (`SpeedRecord`); for walking speed on iOS, see `WALKING_SPEED`                                           |
| POWER                        | WATT                    | yes              | yes                       | READ Only - iOS 17+ (`cyclingPower`); on Android the power of any exercise (`PowerRecord`)                                         |
| CYCLING_CADENCE              | REVOLUTION_PER_MINUTE   | yes              | yes                       | READ Only - iOS 17+ (`cyclingCadence`); on Android read with the `READ_EXERCISE` permission                                        |
| APPLE_MOVE_TIME              | SECOND                  | yes              |                           | READ Only                                                                                                                          |
| APPLE_STAND_HOUR             | HOUR                    | yes              |                           | READ Only                                                                                                                          |
| APPLE_STAND_TIME             | SECOND                  | yes              |                           | READ Only                                                                                                                          |

## Workout Types

The plugin supports the following [`HealthWorkoutActivityType`](https://pub.dev/documentation/health/latest/health/HealthWorkoutActivityType.html).

Some names share one workout type on a platform, as the comments below show. Reads give one name for each such type, whichever name the workout was written with: DANCING, SKIING or WHEELCHAIR on Android, and RUNNING, CLIMBING or SWIMMING on iOS. On iOS the workout's metadata can refine this name: an indoor run reads as RUNNING_TREADMILL, and a swim with a pool or open water location as SWIMMING_POOL or SWIMMING_OPEN_WATER. On iOS, `WorkoutSummary.workoutType` is this name too; before 14.0.0 it was HealthKit's own name, such as `running`.

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
| DANCING                          | (yes)            | yes                       | on iOS you have to choose between CARDIO_DANCE and SOCIAL_DANCE                                 |
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
| HOCKEY                           | yes              |                           |                                                                                                 |
| HUNTING                          | yes              |                           |                                                                                                 |
| ICE_SKATING                      |                  | yes                       |                                                                                                 |
| JUMP_ROPE                        | yes              |                           |                                                                                                 |
| KICKBOXING                       | yes              |                           |                                                                                                 |
| LACROSSE                         | yes              |                           |                                                                                                 |
| MARTIAL_ARTS                     | yes              | yes                       |                                                                                                 |
| MIND_AND_BODY                    | yes              |                           |                                                                                                 |
| MIXED_CARDIO                     | yes              |                           |                                                                                                 |
| PADDLE_SPORTS                    | yes              |                           |                                                                                                 |
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
| SKIING                           | (yes)            | yes                       | on iOS you have to choose between CROSS_COUNTRY_SKIING and DOWNHILL_SKIING                      |
| SNOW_SPORTS                      | yes              |                           |                                                                                                 |
| SNOWBOARDING                     | yes              | yes                       |                                                                                                 |
| SNOWSHOEING                      |                  | yes                       |                                                                                                 |
| SOCCER                           | yes              |                           |                                                                                                 |
| SOCIAL_DANCE                     | yes              | (yes)                     | on Android this will be stored and read back as DANCING                                         |
| SOFTBALL                         | yes              | yes                       |                                                                                                 |
| SQUASH                           | yes              | yes                       |                                                                                                 |
| STAIR_CLIMBING                   | yes              | yes                       |                                                                                                 |
| STAIR_CLIMBING_MACHINE           |                  | yes                       |                                                                                                 |
| STAIRS                           | yes              |                           |                                                                                                 |
| STEP_TRAINING                    | yes              |                           |                                                                                                 |
| STRENGTH_TRAINING                | (yes)            | yes                       | on iOS you have to choose between FUNCTIONAL_STRENGTH_TRAINING or TRADITIONAL_STRENGTH_TRAINING |
| SURFING                          | yes              | yes                       | on iOS this is SURFING_SPORTS, but name changed here to fit with Android                        |
| SWIMMING                         | yes              | (yes)                     | on Android you have to choose between SWIMMING_OPEN_WATER and SWIMMING_POOL                     |
| SWIMMING_OPEN_WATER              | (yes)            | yes                       | on iOS this will be stored as SWIMMING in open water and read back as SWIMMING_OPEN_WATER       |
| SWIMMING_POOL                    | (yes)            | yes                       | on iOS this will be stored and read back as SWIMMING: HealthKit needs a lap length for a pool swim |
| TABLE_TENNIS                     | yes              | yes                       |                                                                                                 |
| TAI_CHI                          | yes              |                           |                                                                                                 |
| TENNIS                           | yes              | yes                       |                                                                                                 |
| TRACK_AND_FIELD                  | yes              |                           |                                                                                                 |
| TRADITIONAL_STRENGTH_TRAINING    | yes              |                           | on Android use STRENGTH_TRAINING                                                                |
| UNDERWATER_DIVING                | yes              |                           |                                                                                                 |
| VOLLEYBALL                       | yes              | yes                       |                                                                                                 |
| WALKING                          | yes              | yes                       |                                                                                                 |
| WATER_FITNESS                    | yes              |                           |                                                                                                 |
| WATER_POLO                       | yes              | yes                       |                                                                                                 |
| WATER_SPORTS                     | yes              |                           |                                                                                                 |
| WEIGHTLIFTING                    |                  | yes                       |                                                                                                 |
| WHEELCHAIR                       | (yes)            | yes                       | on iOS you have to choose between WHEELCHAIR_RUN_PACE or WHEELCHAIR_WALK_PACE                   |
| WHEELCHAIR_RUN_PACE              | yes              | (yes)                     | on Android this will be stored and read back as WHEELCHAIR                                      |
| WHEELCHAIR_WALK_PACE             | yes              | (yes)                     | on Android this will be stored and read back as WHEELCHAIR                                      |
| WRESTLING                        | yes              |                           |                                                                                                 |
| YOGA                             | yes              | yes                       |                                                                                                 |
| OTHER                            | yes              | yes                       |                                                                                                 |

## License

This software is copyright (c) the [Technical University of Denmark (DTU)](https://www.dtu.dk) and is part of the [Copenhagen Research Platform](https://carp.cachet.dk/).
This software is available 'as-is' under a [MIT license](LICENSE).
