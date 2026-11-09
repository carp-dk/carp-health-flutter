# Health

Enables reading and writing health data from/to [Apple Health](https://www.apple.com/health/) and [Google Health Connect](https://health.google/health-connect-android/).

> **NOTE:** Google has deprecated the Google Fit API. According to the [documentation](https://developers.google.com/fit/android), as of **May 1st 2024** developers cannot sign up for using the API. As such, this package has removed support for Google Fit as of version 11.0.0 and users are urged to upgrade as soon as possible.

The plugin supports:

- handling permissions to access health data using the `hasPermissions`, `requestAuthorization`, `revokePermissions` methods.
- reading health data using the `getHealthDataFromTypes` method.
- reading large amounts of health data page by page using the `getHealthDataPages` method.
- writing health data using the `writeHealthData` method.
- writing workouts using the `writeWorkout` method.
- writing workout routes on iOS and Android using the `startWorkoutRoute` / `insertWorkoutRouteData` / `finishWorkoutRoute` methods.
- writing meals on iOS (Apple Health) & Android using the `writeMeal` method.
- writing audiograms on iOS using the `writeAudiogram` method.
- writing blood pressure data using the `writeBloodPressure` method.
- accessing total step counts using the `getTotalStepsInInterval` method.
- cleaning up duplicate data points via the `removeDuplicates` method.
- removing data of a given type in a selected period of time using the `delete` method.

Note that for Android, the target phone **needs** to have the [Health Connect](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata&hl=en) app installed (which is currently in beta) and have access to the internet.

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
     now.subtract(Duration(days: 1)), now, types);

  // request permissions to write steps and blood glucose
  types = [HealthDataType.STEPS, HealthDataType.BLOOD_GLUCOSE];
  var permissions = [
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE
  ];
  await health.requestAuthorization(types, permissions: permissions);

  // write steps and blood glucose
  bool success = await health.writeHealthData(10, HealthDataType.STEPS, now, now);
  success = await health.writeHealthData(3.1, HealthDataType.BLOOD_GLUCOSE, now, now);

  // you can also specify the recording method to store in the metadata (default is RecordingMethod.automatic)
  // on iOS only `RecordingMethod.automatic` and `RecordingMethod.manual` are supported
  // Android additionally supports `RecordingMethod.active` and `RecordingMethod.unknown`
  success &= await health.writeHealthData(10, HealthDataType.STEPS, now, now, recordingMethod: RecordingMethod.manual);

  // get the number of steps for today
  var midnight = DateTime(now.year, now.month, now.day);
  int? steps = await health.getTotalStepsInInterval(midnight, now);
```

### Writing workout routes (iOS & Android)

1. Request share/read permissions for both `HealthDataType.WORKOUT` and `HealthDataType.WORKOUT_ROUTE`, and ensure location permissions are granted (iOS: Core Location permissions; Android: `ACCESS_FINE_LOCATION` or `ACCESS_COARSE_LOCATION`).
2. When the workout session starts, open a builder with `final builderId = await health.startWorkoutRoute();`.
3. Collect GPS samples using `CLLocationManager` (or an equivalent service) and periodically push ordered batches of `WorkoutRouteLocation` values via `insertWorkoutRouteData`.
4. Save the workout itself (for example, with `writeWorkoutData`) and capture the resulting HealthKit workout UUID.
5. Call `finishWorkoutRoute(builderId: builderId, workoutUuid: workoutUuid, metadata: {...})` to commit the route, or `discardWorkoutRoute(builderId)` if the session is cancelled.

> **Health Connect note:** Android only surfaces routes while your app is in the foreground, and
> other apps' routes may return a `ConsentRequired` flag. Today (Health Connect 1.1.0) the system
> does **not** expose the `ExerciseRouteRequestContract` documented by Google, so the only way to
> read third-party routes is to have the user manually grant "Always allow" for *Exercise routes*
> inside the Health Connect app (`Health Connect → App permissions → Your app → Exercise routes`).
> Also remember to declare the following permissions in your Android manifest:
> - `<uses-permission android:name="android.permission.health.READ_EXERCISE_ROUTE"/>`
> - `<uses-permission android:name="android.permission.health.WRITE_EXERCISE_ROUTE"/>`
> - `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>` (or `ACCESS_COARSE_LOCATION`)

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
```

where a [`HealthValue`](https://pub.dev/documentation/health/latest/health/HealthValue-class.html) can be any type of `AudiogramHealthValue`, `ElectrocardiogramHealthValue`, `ElectrocardiogramVoltageValue`, `NumericHealthValue`, `NutritionHealthValue`, or `WorkoutHealthValue`.

A `HealthDataPoint` object can be serialized to and from JSON using the `toJson()` and `fromJson()` methods. JSON serialization is using camel_case notation. Null values are not serialized. For example;

```json
{
  "value": {
    "__type": "NumericHealthValue",
    "numeric_value": 141.0
  },
  "type": "STEPS",
  "unit": "COUNT",
  "date_from": "2024-04-03T10:06:57.736",
  "date_to": "2024-04-03T10:12:51.724",
  "source_platform": "appleHealth",
  "source_device_id": "F74938B9-C011-4DE4-AA5E-CF41B60B96E7",
  "source_id": "com.apple.health.81AE7156-EC05-47E3-AC93-2D6F65C717DF",
  "source_name": "iPhone12.bardram.net",
  "recording_method": 3
  "value": {
    "__type": "NumericHealthValue",
    "numeric_value": 141.0
  },
  "type": "STEPS",
  "unit": "COUNT",
  "date_from": "2024-04-03T10:06:57.736",
  "date_to": "2024-04-03T10:12:51.724",
  "source_platform": "appleHealth",
  "source_device_id": "F74938B9-C011-4DE4-AA5E-CF41B60B96E7",
  "source_id": "com.apple.health.81AE7156-EC05-47E3-AC93-2D6F65C717DF",
  "source_name": "iPhone12.bardram.net",
  "recording_method": 2
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

- Types are read one after another, each type once. Within a type, points are oldest first and without duplicates: on Android in the order of their records' start times, on iOS by end time. On Android the samples of one heart rate, speed or skin temperature record come together, so the samples of overlapping records from different apps are not merged into one time order.
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

**Resuming.** The plugin does not keep track of what you have read. To sync a long range robustly, read it in time windows and record your progress per finished window; after an interruption, read the unfinished window again. Every read has a fixed cost in Health Connect calls (see [Health Connect limits](#health-connect-limits)), so prefer windows of a week or a month to windows of a day. Each window returns the samples inside it: a heart rate, speed or skin temperature record that crosses a boundary is split between the two windows (on Android, records that began more than 24 hours before a window are not looked for). Reads are at-least-once at such a boundary: a point you already stored can be returned again. Store points with an upsert keyed by `(type, uuid, dateFrom)`; on Android, the heart rate samples of one record share the record's `uuid`.

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
| `permissionDenied`  | `PERMISSION_DENIED`         | The call needs a permission the app does not have, for example a background read without `READ_HEALTH_DATA_IN_BACKGROUND`, or, on iOS, a type the app never requested authorization for. A denied read permission for a type is not an error: the type returns no data. | no            |
| `invalidArgument`   | `INVALID_ARGUMENT`          | The request is not valid, for example a preferred unit that cannot express the data type. On Android, besides each type's default unit, Health Connect values are only converted to `POUND` (weight), `CENTIMETER` and `INCH` (height), `DEGREE_FAHRENHEIT` and `KELVIN` (body and skin temperature) and `MILLIMOLES_PER_LITER` (blood glucose). | no            |
| `notSupported`      | `NOT_SUPPORTED`             | The data type is not available on this platform or device.                                                                                                                                | no            |
| `unavailable`       | `UNAVAILABLE`               | Health Connect cannot be reached or is busy, for example while it syncs data.                                                                                                             | yes           |
| `deviceLocked`      | `DEVICE_LOCKED`             | iOS: protected health data cannot be read while the device is locked.                                                                                                                    | yes           |
| `dataTooLarge`      | `DATA_TOO_LARGE`            | The platform could not return this much data in one call. Use a smaller `pageSize` or a shorter time range.                                                                               | no            |
| `unknown`           | `HEALTH_ERROR` (and others) | Any other error.                                                                                                                                                                          | no            |

Codes may be added in minor releases, so a `switch` over `HealthErrorCode` needs a default case. Codes from before 14.0.0, such as `PERMISSION_ERROR`, `ARGUMENT_ERROR` and `INVALID_TYPE`, map to the matching value; `STEPS_ERROR` and `STATISTICS_ERROR` map to `unknown`.

What each read method does on failure:

| Method                                                                   | On failure                                                                                                                                                                                       |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `getHealthDataFromTypes`                                                 | Throws `HealthPlatformException`. An empty list only means no data or, on Android, no read permission. Before 14.0.0, Android returned an empty list on any failure.                            |
| `getHealthDataPages`                                                     | The stream emits the `HealthPlatformException` (or `HealthException`) and closes.                                                                                                                |
| `getHealthIntervalDataFromTypes`, `getHealthAggregateDataFromTypes`      | Throws `HealthPlatformException`.                                                                                                                                                                |
| `getHealthDataByUUID`                                                    | Returns `null` if the record is not found, and throws `HealthPlatformException` on other failures.                                                                                              |
| `getTotalStepsInInterval`                                                | Returns `null`.                                                                                                                                                                                  |
| `getChangesToken`, `getChanges`                                          | Return `null`. If Health Connect cannot return the pending changes because they are too many, or a page of changes holds more than 100,000 data points, `getChanges` returns `changesTokenExpired: true`: create a new token and read the data again. |
| Writes, deletes, permissions and the Health Connect helpers              | Unchanged.                                                                                                                                                                                       |

Other errors are as before: a `HealthException` (now with `errorCode` `notSupported`) when a data type is not available on the platform, which is checked for all types before anything is read; on Android, a `HealthException` with `errorCode` `invalidArgument` for a preferred unit that Health Connect values are not converted to, also checked before anything is read; an `UnsupportedError` when Health Connect is not installed; and `ArgumentError`s for invalid arguments. A `MissingPluginException` is passed on as it is.

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
| Speed and skin temperature                            | 1 permission check + 1 look-back read + 1 per `pageSize / 3600` records (5 at the default `pageSize`): a record may hold an hour of samples at one per second, and Health Connect has no count of these samples to plan by. |
| Workouts                                              | Per 20 workouts: 1 permission check + 1 read + up to 3 per workout for its distance, calories and steps                                                                                                                                                                                                      |
| `getTotalStepsInInterval(includeManualEntry: false)`  | 1 per 5,000 step records                                                                                                                                                                                                                                                                                     |
| `getHealthIntervalDataFromTypes`                      | 1 per type                                                                                                                                                                                                                                                                                                   |
| `getChanges`                                          | 1 per call                                                                                                                                                                                                                                                                                                   |

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

**Note that for this to work, the information needs to have been provided when writing the data to Health Connect or Apple Health**. For example, steps added manually through the Apple Health App will set `HKWasUserEntered` to true (corresponding to `RecordingMethod.manual`), however it seems that adding steps manually to Google Fit does not write the data with the `RecordingMethod.manual` in the metadata, instead it shows up as `RecordingMethod.unknown`. This is an open issue, and as such filtering manual entries when querying step count on Android with `getTotalStepsInInterval(includeManualEntries: false)` does not necessarily filter out manual steps.

**NOTE**: On iOS, you can only filter by `RecordingMethod.automatic` and `RecordingMethod.manual` as it is stored `HKMetadataKeyWasUserEntered` is a boolean value in the metadata.

### Filtering out duplicates

If the same data is requested multiple times and saved in the same array duplicates will occur.

A single data point can be compared to each other with the == operator, i.e.

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
    workoutSummary: WorkoutSummary - workoutType: runningtotalDistance: 2400, totalEnergyBurned: 0, totalSteps: 0
    metadata: null
    deviceModel: null
```
> Assuming that the `uuid` and `type` are coming from your database.


## Data Types

The plugin supports the following [`HealthDataType`](https://pub.dev/documentation/health/latest/health/HealthDataType.html).

| **Data Type**                | **Unit**                | **Apple Health** | **Google Health Connect** | **Comments**                                                                                                                       |
| ---------------------------- | ----------------------- | ---------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| ACTIVE_ENERGY_BURNED         | CALORIES                | yes              | yes                       |                                                                                                                                    |
| ATRIAL_FIBRILLATION_BURDEN   | PERCENTAGE              | yes              |                           |                                                                                                                                    |
| BASAL_ENERGY_BURNED          | CALORIES                | yes              | yes                       |                                                                                                                                    |
| BLOOD_GLUCOSE                | MILLIGRAM_PER_DECILITER | yes              | yes                       |                                                                                                                                    |
| BLOOD_OXYGEN                 | PERCENTAGE              | yes              | yes                       |                                                                                                                                    |
| BLOOD_PRESSURE_DIASTOLIC     | MILLIMETER_OF_MERCURY   | yes              | yes                       |                                                                                                                                    |
| BLOOD_PRESSURE_SYSTOLIC      | MILLIMETER_OF_MERCURY   | yes              | yes                       |                                                                                                                                    |
| BODY_FAT_PERCENTAGE          | PERCENTAGE              | yes              | yes                       |                                                                                                                                    |
| BODY_MASS_INDEX              | NO_UNIT                 | yes              | yes                       |                                                                                                                                    |
| BODY_TEMPERATURE             | DEGREE_CELSIUS          | yes              | yes                       |                                                                                                                                    |
| BODY_WATER_MASS              | KILOGRAMS               |                  | yes                       |                                                                                                                                    |
| ELECTRODERMAL_ACTIVITY       | SIEMENS                 | yes              |                           |                                                                                                                                    |
| HEART_RATE                   | BEATS_PER_MINUTE        | yes              | yes                       |                                                                                                                                    |
| HEIGHT                       | METERS                  | yes              | yes                       |                                                                                                                                    |
| RESTING_HEART_RATE           | BEATS_PER_MINUTE        | yes              | yes                       |                                                                                                                                    |
| RESPIRATORY_RATE             | RESPIRATIONS_PER_MINUTE | yes              | yes                       |                                                                                                                                    |
| PERIPHERAL_PERFUSION_INDEX   | PERCENTAGE              | yes              |                           |                                                                                                                                    |
| STEPS                        | COUNT                   | yes              | yes                       |                                                                                                                                    |
| WAIST_CIRCUMFERENCE          | METERS                  | yes              |                           |                                                                                                                                    |
| WALKING_HEART_RATE           | BEATS_PER_MINUTE        | yes              |                           |                                                                                                                                    |
| WEIGHT                       | KILOGRAMS               | yes              | yes                       |                                                                                                                                    |
| DISTANCE_WALKING_RUNNING     | METERS                  | yes              |                           |                                                                                                                                    |
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
| SLEEP_UNKNOWN                | MINUTES                 |                  | yes                       |                                                                                                                                    |
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
| INSULIN_DELIVERY             | INTERNATIONAL_UNIT      | yes              |                           |                                                                                                                                    |
| MENSTRUATION_FLOW            | NO_UNIT                 | yes              | yes                       |                                                                                                                                    |
| WATER_TEMPERATURE            | DEGREE_CELSIUS          | yes              |                           | Related to/Requires Apple Watch Ultra's Underwater Diving Workout                                                                  |
| SLEEP_WRIST_TEMPERATURE      | DEGREE_CELSIUS          | yes              |                           | READ Only - `appleSleepingWristTemperature`                                                                                        |
| SKIN_TEMPERATURE             | DEGREE_CELSIUS          |                  | yes                       | Must check health connect for availability                                                                                         |
| UNDERWATER_DEPTH             | METER                   | yes              |                           | Related to/Requires Apple Watch Ultra's Underwater Diving Workout                                                                  |
| UV_INDEX                     | COUNT                   | yes              |                           |                                                                                                                                    |
| LEAN_BODY_MASS               | KILOGRAMS               | yes              | yes                       |                                                                                                                                    |
| WALKING_SPEED                | METER_PER_SECOND        | yes              | (yes)                     | On Android this will be recorded as `SPEED` with similar unit                                                                      |
| APPLE_MOVE_TIME              | SECOND                  | yes              |                           | READ Only                                                                                                                          |
| APPLE_STAND_HOUR             | HOUR                    | yes              |                           | READ Only                                                                                                                          |
| APPLE_MOVE_TIME              | SECOND                  | yes              |                           | READ Only                                                                                                                          |

## Workout Types

The plugin supports the following [`HealthWorkoutActivityType`](https://pub.dev/documentation/health/latest/health/HealthWorkoutActivityType.html).

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
| CARDIO_DANCE                     | yes              | (yes)                     | on Android this will be stored as DANCING                                                       |
| CLIMBING                         | yes              |                           |                                                                                                 |
| COOLDOWN                         | yes              |                           |                                                                                                 |
| CORE_TRAINING                    | yes              |                           |                                                                                                 |
| CRICKET                          | yes              | yes                       |                                                                                                 |
| CROSS_COUNTRY_SKIING             | yes              | (yes)                     | on Android this will be stored as SKIING                                                        |
| CROSS_TRAINING                   | yes              |                           |                                                                                                 |
| CURLING                          | yes              |                           |                                                                                                 |
| DANCING                          | yes              | yes                       | on iOS this is DANCE, but name changed here to fit with Android                                 |
| DISC_SPORTS                      | yes              |                           |                                                                                                 |
| DOWNHILL_SKIING                  | yes              | (yes)                     | on Android this will be stored as SKIING                                                        |
| ELLIPTICAL                       | yes              | yes                       |                                                                                                 |
| EQUESTRIAN_SPORTS                | yes              |                           |                                                                                                 |
| FENCING                          | yes              | yes                       |                                                                                                 |
| FISHING                          | yes              |                           |                                                                                                 |
| FITNESS_GAMING                   | yes              |                           |                                                                                                 |
| FLEXIBILITY                      | yes              |                           |                                                                                                 |
| FRISBEE_DISC                     |                  | yes                       |                                                                                                 |
| FUNCTIONAL_STRENGTH_TRAINING     | yes              | (yes)                     | on Android this will be stored as STRENGTH_TRAINING                                             |
| GOLF                             | yes              | yes                       |                                                                                                 |
| GUIDED_BREATHING                 |                  | yes                       |                                                                                                 |
| GYMNASTICS                       | yes              | yes                       |                                                                                                 |
| HAND_CYCLING                     | yes              |                           |                                                                                                 |
| HANDBALL                         | yes              | yes                       |                                                                                                 |
| HIGH_INTENSITY_INTERVAL_TRAINING | yes              | yes                       |                                                                                                 |
| HIKING                           | yes              | yes                       |                                                                                                 |
| HOCKEY                           | yes              |                           |                                                                                                 |
| HUNTING                          | yes              |                           |                                                                                                 |
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
| ROCK_CLIMBING                    | (yes)            | yes                       | on iOS this will be stored as CLIMBING                                                          |
| ROWING                           | yes              | yes                       |                                                                                                 |
| RUGBY                            | yes              | yes                       |                                                                                                 |
| RUNNING                          | yes              | yes                       |                                                                                                 |
| RUNNING_TREADMILL                | (yes)            | yes                       | on iOS this will be stored as RUNNING                                                           |
| SAILING                          | yes              | yes                       |                                                                                                 |
| SCUBA_DIVING                     |                  | yes                       |                                                                                                 |
| SKATING                          | yes              | yes                       | On iOS this will be stored as SKATING_SPORTS                                                    |
| SKIING                           | (yes)            | yes                       | on iOS you have to choose between CROSS_COUNTRY_SKIING and DOWNHILL_SKIING                      |
| SNOW_SPORTS                      | yes              |                           |                                                                                                 |
| SNOWBOARDING                     | yes              | yes                       |                                                                                                 |
| SOCCER                           | yes              |                           |                                                                                                 |
| SOCIAL_DANCE                     | yes              | (yes)                     | on Android this will be stored as DANCING                                                       |
| SOFTBALL                         | yes              | yes                       |                                                                                                 |
| SQUASH                           | yes              | yes                       |                                                                                                 |
| STAIR_CLIMBING                   | yes              | yes                       |                                                                                                 |
| STAIR_CLIMBING_MACHINE           |                  | yes                       |                                                                                                 |
| STAIRS                           | yes              |                           |                                                                                                 |
| STEP_TRAINING                    | yes              |                           |                                                                                                 |
| STRENGTH_TRAINING                | (yes)            | yes                       | on iOS you have to choose between FUNCTIONAL_STRENGTH_TRAINING or TRADITIONAL_STRENGTH_TRAINING |
| SURFING                          | yes              | yes                       | on iOS this is SURFING_SPORTS, but name changed here to fit with Android                        |
| SWIMMING                         | yes              | (yes)                     | on Android you have to choose between SWIMMING_OPEN_WATER and SWIMMING_POOL                     |
| SWIMMING_OPEN_WATER              | (yes)            | yes                       | on iOS this will be stored as SWIMMING                                                          |
| SWIMMING_POOL                    | (yes)            | yes                       | on iOS this will be stored as SWIMMING                                                          |
| TABLE_TENNIS                     | yes              | yes                       |                                                                                                 |
| TAI_CHI                          | yes              |                           |                                                                                                 |
| TENNIS                           | yes              | yes                       |                                                                                                 |
| TRACK_AND_FIELD                  | yes              |                           |                                                                                                 |
| TRADITIONAL_STRENGTH_TRAINING    | yes              | (yes)                     | on Android this will be stored as STRENGTH_TRAINING                                             |
| UNDERWATER_DIVING                | yes              |                           |                                                                                                 |
| VOLLEYBALL                       | yes              | yes                       |                                                                                                 |
| WALKING                          | yes              | yes                       |                                                                                                 |
| WATER_FITNESS                    | yes              |                           |                                                                                                 |
| WATER_POLO                       | yes              | yes                       |                                                                                                 |
| WATER_SPORTS                     | yes              |                           |                                                                                                 |
| WEIGHTLIFTING                    |                  | yes                       |                                                                                                 |
| WHEELCHAIR                       | (yes)            | yes                       | on iOS you have to choose between WHEELCHAIR_RUN_PACE or WHEELCHAIR_WALK_PACE                   |
| WHEELCHAIR_RUN_PACE              | yes              | (yes)                     | on Android this will be stored as WHEELCHAIR                                                    |
| WHEELCHAIR_WALK_PACE             | yes              | (yes)                     | on Android this will be stored as WHEELCHAIR                                                    |
| WRESTLING                        | yes              |                           |                                                                                                 |
| YOGA                             | yes              | yes                       |                                                                                                 |
| OTHER                            | yes              | yes                       |                                                                                                 |

## License

This software is copyright (c) the [Technical University of Denmark (DTU)](https://www.dtu.dk) and is part of the [Copenhagen Research Platform](https://carp.cachet.dk/).
This software is available 'as-is' under a [MIT license](LICENSE).
