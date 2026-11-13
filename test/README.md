# Health Plugin Testing Framework

This folder contains the reusable test harness, fixtures, and templates for the health plugin.

**Structure**
- `test/support` shared helpers used by tests.
- `test/templates` non-running templates. Copy into `test/unit` or `test/channel` and rename to `*_test.dart`.
- `example/integration_test` device/simulator tests that exercise native HealthKit/Health Connect.

**How To Add A Method-Channel Test**
1. Copy a template from `test/templates` into `test/unit` and rename to `*_test.dart`.
2. Create a `HealthTestContext`.
3. Stub the channel responses using `ctx.channel.when(...)`, `ctx.channel.whenSequence(...)` (one reply per call, and a `PlatformException` in the list becomes an error reply) or a custom responder. Reads call the native `getDataPage` method; build its replies with `HealthFixtures.page(...)`.
4. Call the API under test. For reads, `test/support/read_helpers.dart` adds `ctx.collect(...)`, `ctx.pages(...)`, `ctx.pageCalls()` and `ctx.serve(...)`.
5. Assert on `ctx.channel.lastCallFor(...)` and parsed outputs, and on errors with `platformError(...)` from `test/support/error_matchers.dart`.

**Platform Notes**
- Many APIs are platform-gated. For iOS/Android-only behavior, keep the unit test focused on arguments and parsing.
- The tests run on a desktop host, where `Health.platformType` is Health Connect and `Health.isDataTypeAvailable` has the iOS data types. Checks that depend on `platformType` run as on iOS with `HealthOnIOS` from `test/support/health_on_ios.dart`, and checks that depend on the Android data types run with `HealthOnAndroid` from `test/support/health_on_android.dart`. `Platform.isAndroid` and `Platform.isIOS` stay false in both.
- Validate platform-specific behavior in `example/integration_test` on a real device or emulator.

**Coverage Checklist**
- `Health.configure`
- `Health.isDataTypeAvailable`
- `Health.hasPermissions`
- `Health.requestAuthorization`
- `Health.revokePermissions`
- `Health.getHealthConnectSdkStatus`
- `Health.isHealthConnectAvailable`
- `Health.installHealthConnect`
- `Health.isHealthDataHistoryAvailable`
- `Health.isHealthDataHistoryAuthorized`
- `Health.requestHealthDataHistoryAuthorization`
- `Health.isHealthDataInBackgroundAvailable`
- `Health.isHealthDataInBackgroundAuthorized`
- `Health.requestHealthDataInBackgroundAuthorization`
- `Health.getHealthDataFromTypes`
- `Health.getHealthDataPages`
- `Health.getHealthIntervalDataFromTypes`
- `Health.getHealthAggregateDataFromTypes` (deprecated: throws an `UnsupportedError` without calling the platform)
- `Health.getHealthDataByUUID`
- `Health.getChangesToken`
- `Health.getChanges`
- `Health.getTotalStepsInInterval`
- `Health.writeHealthData`
- `Health.writeActivityIntensity`
- `Health.writeWorkoutData`
- `Health.writeBloodPressure`
- `Health.writeBloodOxygen`
- `Health.writeMeal`
- `Health.writeSleepSession`
- `Health.writeMenstruationFlow`
- `Health.writeAudiogram`
- `Health.writeInsulinDelivery`
- `Health.delete`
- `Health.deleteByUUID`
- `Health.deleteByClientRecordId`
- `Health.startWorkoutRoute`
- `Health.insertWorkoutRouteData`
- `Health.finishWorkoutRoute`
- `Health.discardWorkoutRoute`
