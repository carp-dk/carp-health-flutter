# Kubikos fork of `health`

Fork of [`carp-dk/carp-health-flutter`](https://github.com/carp-dk/carp-health-flutter)
(the `health` package, v13.3.1) with **one** behavioural change on branch
`kubikos/guard-workout-subqueries`. Used by kubikos-app via a `dependency_overrides`
git ref. `main` tracks upstream unchanged.

## The change

`android/.../HealthDataReader.kt` → `handleWorkoutData` enriches every
`ExerciseSessionRecord` by sub-querying `DistanceRecord`,
`TotalCaloriesBurnedRecord` and `StepsRecord`. Upstream runs those three reads
**unguarded**, and the whole workout read is wrapped in
`try { … } catch { result.success(emptyList()) }`. So if the consuming app does
not hold `READ_STEPS`/`READ_DISTANCE`, the sub-query throws `SecurityException`
→ the catch swallows it → **every imported workout silently disappears**.

This forces apps to request Health Connect permissions for data types they never
use (e.g. Steps), which Google Play rejects under the **"Minimum Scope"** policy.

The patch wraps each of the three sub-queries in its own `try/catch`, so a missing
permission enriches that field with `null` instead of aborting the whole read.
Grep for `PATCH` in `HealthDataReader.kt`.

## Upstream

Intended for an upstream PR to `carp-dk/carp-health-flutter`. Once merged and
released, kubikos-app should drop this fork and return to the pub package.
