/// What a lookup by UUID found, shown inline with the same views as the data point sheet.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/data_point/data_point_details.dart';
import 'package:health_example/shared/data_point/data_point_sheet.dart';

import '../widgets/fact_pill.dart';
import 'lookup_controller.dart';

/// Shows a [LookupResult]: the time the call took and the record's [DataPointDetails] (header, typed value,
/// fields with the UUID, and raw JSON) with a button that opens it in the data point sheet, where it can be
/// read again or deleted; or, when `getHealthDataByUUID` returned null, an [EmptyState] whose info button
/// explains when that happens.
class LookupResultView extends StatelessWidget {
  /// Creates the view of [result].
  const LookupResultView({super.key, required this.result, required this.isIOS, required this.onDeleted});

  /// What the lookup found.
  final LookupResult result;

  /// Whether the app runs on iOS, where a text that is not a UUID also returns null.
  final bool isIOS;

  /// Called after the record was deleted from the data point sheet.
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final point = result.point;
    final took = '${formatNumber(result.elapsed.inMilliseconds)} ms';
    if (point == null) {
      return EmptyState(icon: Icons.search_off, title: 'No record found', message: '${result.type.label} · $took');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Found it',
          trailing: FactPill(icon: Icons.timer_outlined, text: took),
        ),
        DataPointDetails(
          point: point,
          actions: FilledButton.tonalIcon(
            onPressed: () => showDataPointSheet(context, point, onDeleted: (_) => onDeleted()),
            icon: const Icon(Icons.open_in_full),
            label: const Text('Open record'),
          ),
        ),
      ],
    );
  }
}
