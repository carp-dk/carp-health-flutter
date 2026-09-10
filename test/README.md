# Health Plugin Testing Framework

This folder contains the reusable test harness, fixtures, and templates for the health plugin.

**Structure**
- `test/support` shared helpers used by tests.
- `test/templates` non-running templates. Copy into `test/unit` or `test/channel` and rename to `*_test.dart`.
- `example/integration_test` device/simulator tests that exercise native HealthKit/Health Connect.

**How To Add A Method-Channel Test**
1. Copy a template from `test/templates` into `test/unit` and rename to `*_test.dart`.
2. Create a `HealthTestContext`.
3. Stub the channel responses using `ctx.channel.when(...)` or a custom responder.
4. Call the API under test.
5. Assert on `ctx.channel.lastCallFor(...)` and parsed outputs.

**Platform Notes**
- Many APIs are platform-gated. For iOS/Android-only behavior, keep the unit test focused on arguments and parsing.
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
- `Health.getHealthIntervalDataFromTypes`
- `Health.getHealthAggregateDataFromTypes`
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
