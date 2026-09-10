# health_example

Demonstrates how to use the health plugin.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Health Connect Change Tokens (Android)

This example app includes a simple change-token flow for incremental sync
using Google Health Connect.

Steps:
1. Tap `Authenticate` to request permissions.
2. Tap `Create Changes Token` to create a token for `STEPS` and `WORKOUT`.
3. Tap `Get Changes` to fetch changes. The token **changes after each call**
   (you must store `nextChangesToken` and use it for the next call).
4. If `hasMore` is `true`, tap again to page through changes.
5. If `tokenExpired` is `true`, do a full resync and create a new token.

Example usage from code:
```dart
final token = await health.getChangesToken(
  types: [HealthDataType.STEPS, HealthDataType.WORKOUT],
);

if (token != null) {
  final response = await health.getChanges(changesToken: token);
  if (response != null) {
    // Apply changes to your local store.
    // Upserts replace existing items by uuid; deletions remove by recordId.
    for (final change in response.changes) {
      if (change.type == HealthChangeType.delete) {
        localStore.remove(change.recordId);
        continue;
      }
      final dataPoint = change.dataPoint;
      if (dataPoint != null) {
        localStore[dataPoint.uuid] = dataPoint;
      }
    }

    // Persist the next token for the next pull.
    final nextToken = response.nextChangesToken;
  }
}
```
