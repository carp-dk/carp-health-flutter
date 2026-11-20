/// How every write in the app reports what the plugin returned: a snack bar, and an entry in the
/// app's log of its writes (`RecentWrites`) when something was saved.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/navigation/app_destination.dart';
import 'package:health_example/app/navigation/app_navigation.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/writes/recent_writes.dart';
import 'package:health_example/shared/data_point/open_by_uuid.dart';
import 'package:health_example/shared/scope_lookup.dart';

import 'error_dialog.dart';

/// Reports the result of a write of [type], described by [description] (such as "72 bpm").
///
/// * With an [error] (what the write threw), a snack bar names the problem, with "Details" for the
///   error dialog (`showErrorDialog`).
/// * Without [success] (the write methods return `false`, or an empty UUID, when Health Connect or
///   HealthKit did not save anything), a snack bar says so and points to the write permission, with a
///   way to the Setup page, where it is requested.
/// * With [success], the write is added to `RecentWrites` (with its [uuid] and [clientRecordId], so
///   Read and Write can look it up or delete it) and a snack bar confirms it, with "View" when the
///   write returned a [uuid]: "View" reads the record back with `getHealthDataByUUID` and shows it.
///
/// The snack bar shows on [context]'s `ScaffoldMessenger`, so it stays visible when a form page closes
/// right after the write; its actions therefore run on the root navigator, which outlives that page.
Future<void> reportWriteResult(
  BuildContext context, {
  required HealthDataType type,
  required String description,
  required bool success,
  String? uuid,
  String? clientRecordId,
  Object? error,
}) async {
  if (error != null) {
    showErrorSnackBar(context, error, message: '${type.label} not written: ${ErrorInfo.from(error).title}');
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.maybeOf(context, rootNavigator: true);
  if (!success) {
    // A false mostly means a missing write permission; Health Connect also refuses writes over its quota.
    final canOpenSetup = navigator != null && context.getInheritedWidgetOfExactType<AppNavigation>() != null;
    messenger?.showSnackBar(
      SnackBar(
        content: Text('${type.label} not written: check write access'),
        action: canOpenSetup
            ? SnackBarAction(
                label: 'Setup',
                onPressed: () => AppNavigation.goTo(navigator.context, AppDestination.setup),
              )
            : null,
      ),
    );
    return;
  }

  // RecentWrite keeps an empty UUID (nothing to look up) as null.
  final write = RecentWrite(type: type, description: description, uuid: uuid, clientRecordId: clientRecordId);
  final services = maybeAppServices(context);
  services?.recentWrites.add(write);

  final id = write.uuid;
  messenger?.showSnackBar(
    SnackBar(
      content: Text('${type.label} written: $description'),
      // "View" reads the record through the app's plugin instance, which AppScope provides.
      action: id == null || navigator == null || services == null
          ? null
          : SnackBarAction(
              label: 'View',
              onPressed: () => openDataPointByUuid(navigator.context, uuid: id, type: type),
            ),
    ),
  );
}
