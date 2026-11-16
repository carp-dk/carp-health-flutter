/// Opens a record by its UUID: reads it with `Health.getHealthDataByUUID`, then shows it in the data
/// point sheet. Used by the "View" actions of writes and of the Write page's recent writes.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';
import 'package:health_example/shared/widgets/error_dialog.dart';

import 'data_point_sheet.dart';
import 'data_point_text.dart';

/// Reads the [type] record with [uuid] (`getHealthDataByUUID`) and shows it with [showDataPointSheet].
///
/// A small dialog shows progress while the plugin reads. When the plugin returns null, a snack bar
/// explains why that happens; when it throws, a snack bar names the error, with its details one tap
/// away. Nothing escapes as an exception.
Future<void> openDataPointByUuid(BuildContext context, {required String uuid, required HealthDataType type}) async {
  final health = AppScope.of(context).health;
  final lookup = AsyncValue.guard(() => health.getHealthDataByUUID(uuid: uuid, type: type));
  final result = await showDialog<AsyncValue<HealthDataPoint?>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _LookupProgressDialog(type: type, lookup: lookup),
  );
  if (result == null || !context.mounted) return;
  switch (result) {
    case AsyncData(value: final point?):
      await showDataPointSheet(context, point);
    case AsyncData():
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(uuidNotFoundMessage(type))));
    case AsyncError(:final error):
      showErrorSnackBar(context, error);
    case AsyncIdle() || AsyncLoading():
      break;
  }
}

/// A dialog that shows a loading indicator until [lookup] completes, then closes itself with its result.
/// The back button cannot close it, so the result always arrives.
class _LookupProgressDialog extends StatefulWidget {
  const _LookupProgressDialog({required this.type, required this.lookup});

  final HealthDataType type;
  final Future<AsyncValue<HealthDataPoint?>> lookup;

  @override
  State<_LookupProgressDialog> createState() => _LookupProgressDialogState();
}

/// Closes the dialog with the lookup's result as soon as it arrives.
class _LookupProgressDialogState extends State<_LookupProgressDialog> {
  @override
  void initState() {
    super.initState();
    widget.lookup.then((result) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 20,
            children: [
              const ExpressiveLoadingIndicator(contained: true, semanticsLabel: 'Reading by UUID'),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reading ${widget.type.label}', style: theme.textTheme.titleMediumEmphasized),
                    Text(
                      'getHealthDataByUUID',
                      style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurfaceVariant).monospace,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
