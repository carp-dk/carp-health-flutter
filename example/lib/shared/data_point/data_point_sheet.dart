/// The data point sheet: everything the plugin returned for one `HealthDataPoint`, and the calls the
/// plugin offers on a single record.
///
/// Demonstrates `Health.getHealthDataByUUID` ("Re-read by UUID") and `Health.deleteByUUID` ("Delete"),
/// and shows each kind of `HealthValue` with a view of its own (`TypedValueView`): workouts with their
/// swimming laps and events, meals, audiograms, ECGs, routes and the smaller typed values.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/health/health_type_info.dart';

import 'data_point_details.dart';
import 'sheet/data_point_actions.dart';
import 'sheet/data_point_sheet_controller.dart';

/// Shows [point] in a modal bottom sheet ([DataPointSheet]) and completes when the sheet closes.
///
/// [onDeleted] is called with the point after the user deleted it from the sheet (which then closes),
/// so a list that shows it can drop it.
Future<void> showDataPointSheet(
  BuildContext context,
  HealthDataPoint point, {
  ValueChanged<HealthDataPoint>? onDeleted,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => DataPointSheet(point: point, onDeleted: onDeleted),
);

/// The content of the data point sheet: the [DataPointDetails] of the point, with the record's actions
/// (Re-read by UUID, Delete) under its header.
///
/// It drags between two fifths of the screen and full height, opening at three quarters. Its
/// [DataPointSheetController] makes the plugin calls and is created and disposed with the sheet; it
/// reads the plugin instance and the app's recent writes from `AppScope`.
class DataPointSheet extends StatefulWidget {
  /// Creates the sheet for [point].
  const DataPointSheet({super.key, required this.point, this.onDeleted});

  /// The data point shown first; a re-read by UUID replaces it.
  final HealthDataPoint point;

  /// Called with the point once it was deleted.
  final ValueChanged<HealthDataPoint>? onDeleted;

  @override
  State<DataPointSheet> createState() => _DataPointSheetState();
}

/// Owns the sheet's [DataPointSheetController] and runs the confirm-and-delete flow.
class _DataPointSheetState extends State<DataPointSheet> {
  late final DataPointSheetController _controller;

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be called here.
    final services = AppScope.of(context);
    _controller = DataPointSheetController(widget.point, health: services.health, recentWrites: services.recentWrites);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Confirms, deletes with `deleteByUUID`, and on success closes the sheet and says so. A `false`
  /// from the plugin or an error stays in the sheet, under the buttons.
  Future<void> _delete() async {
    final point = _controller.point;
    if (!await confirmDataPointDelete(context) || !mounted) return;
    if (!await _controller.deleteByUuid() || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    widget.onDeleted?.call(point);
    messenger?.showSnackBar(SnackBar(content: Text('${point.type.label} record deleted')));
  }

  @override
  Widget build(BuildContext context) {
    // The sheet reaches the bottom of the screen: keep the end of the content above the home
    // indicator or navigation bar.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (context, scrollController) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(24, 0, 24, 32 + bottomInset),
          children: [
            DataPointDetails(
              point: _controller.point,
              actions: DataPointActions(controller: _controller, onDelete: _delete),
            ),
          ],
        ),
      ),
    );
  }
}
