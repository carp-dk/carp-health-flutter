# health_example

A Material 3 Expressive app that shows every capability of the health plugin on Apple Health (iOS) and
Health Connect (Android). Each screen makes real plugin calls, names the methods it uses, and explains
what each platform does differently.

## What the app shows

| Destination | Plugin calls |
| --- | --- |
| **Overview** | `getHealthConnectSdkStatus`, `deviceId`, `hasPermissions` and `requestAuthorization` for a core set of types, and today's highlights: `getTotalStepsInInterval`, `getHealthDataFromTypes` with `limit: 1`, and `getHealthIntervalDataFromTypes`. |
| **Read** | *Query*: `getHealthDataFromTypes` (with `limit`, `preferredUnits` and `recordingMethodsToFilter`), `getHealthDataPages` (a cancellable stream of pages, with `readPermissionDenied` on Android) and `removeDuplicates`. *Lookup*: `getHealthDataByUUID`. *Changes* (Android): `getChangesToken` and `getChanges`. A sheet shows every field of a data point, with `deleteByUUID`. |
| **Insights** | `getHealthIntervalDataFromTypes` as a bar chart (hour, day or week intervals) and `getTotalStepsInInterval`, with and without manual entries. |
| **Write** | A sample data set written step by step, and one form per write method: `writeHealthData` / `writeHealthDataUUID`, `writeBloodPressure`, `writeBloodOxygen`, `writeMeal`, `writeWorkoutData` / `writeWorkoutDataUUID` (with swimming laps and iOS workout metadata), the workout route calls, `writeSleepSession`, `writeMindfulnessSession`, `writeMenstruationFlow`, `writeInsulinDelivery` (iOS), `writeAudiogram` (iOS) and `writeActivityIntensity` (Android). Deleting with `delete` and `deleteByClientRecordId`, and a log of this session's writes. |
| **Setup** | Health Connect status and `installHealthConnect`, `requestAuthorization`, `hasPermissions`, `getRequestStatusForAuthorization` (iOS) and `revokePermissions` (Android), the Health Connect feature checks and history and background authorization, Android runtime permissions, and the plugin's `pageSize` and `isolateMode`. |

Methods that one platform lacks stay visible with a badge and the reason, rather than being hidden.

## Structure

```
lib/
  main.dart      creates the one Health instance, calls configure() and starts the app
  app/           app widget, dependency scope (AppScope), adaptive navigation shell
  design/        the Material 3 Expressive design layer (no plugin code)
  core/          plugin-facing logic: platform capabilities, type catalog, settings, formatting
  shared/        widgets several features use: type picker, data point sheet, form fields
  features/      overview/, read/, insights/, write/, setup/ - one folder per destination
test/            unit and widget tests, mirroring lib/
```

Each feature keeps its plugin calls in `ChangeNotifier` controllers and exposes their state as an
`AsyncValue` (idle, loading, data or error), so widgets never call the plugin and errors are shown, not
thrown. No file is longer than 300 lines.

## Design

Flutter 3.47 has no Material 3 Expressive widgets yet (only the expressive colour scheme variant), so
`lib/design/` implements what the app uses: the expressive scheme (`DynamicSchemeVariant.expressive`),
the shape scale and morphing polygon library, emphasized and tabular typography, collapsing medium
app bars, spring motion (respecting reduced motion), connected button groups, the morphing loading
indicator, a wavy progress indicator and a vibrant floating toolbar. Copy is kept minimal so data,
statuses and controls stay front and center.

## Running

```sh
flutter run
```

Two `--dart-define` settings help with screenshots:

- `HEALTH_EXAMPLE_TAB=overview|read|insights|write|setup` opens that destination first.
- `HEALTH_EXAMPLE_THEME=light|dark|system` forces a theme.

Platform setup (Health Connect permissions in the Android manifest, HealthKit usage descriptions on iOS)
is described in the plugin's README; this app's `android/` and `ios/` folders are a working example.

## Health Connect changes (Android)

Read > Changes demonstrates incremental sync:

1. Pick the types and tap **Create token** (`getChangesToken`).
2. Tap **Fetch changes** (`getChanges`). The token changes after each call: keep `nextChangesToken` for
   the next one. While `hasMore` is true, the app fetches again.
3. If `changesTokenExpired` is true, tap **Read in Query** to read the data in full, then create a
   new token.

The same in code:

```dart
final token = await health.getChangesToken(types: [HealthDataType.STEPS, HealthDataType.WORKOUT]);
if (token != null) {
  final response = await health.getChanges(changesToken: token);
  if (response != null) {
    for (final change in response.changes) {
      if (change.type == HealthChangeType.delete) {
        localStore.remove(change.recordId);
      } else if (change.dataPoint case final point?) {
        localStore[point.uuid] = point;
      }
    }
    final nextToken = response.nextChangesToken; // store it for the next call
  }
}
```
