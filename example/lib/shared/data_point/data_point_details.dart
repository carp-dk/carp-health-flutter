/// Everything the plugin returned for one `HealthDataPoint`, as one column: the data point sheet shows it
/// in a bottom sheet, and Read's lookup by UUID (`getHealthDataByUUID`) shows it inline.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'sheet/data_point_fields.dart';
import 'sheet/data_point_header.dart';
import 'value_views/raw_json_view.dart';
import 'value_views/typed_value_view.dart';

/// The details of [point], top to bottom:
///
/// * a [DataPointHeader]: the type in its category's shape, the value in big emphasized type, when it
///   was recorded, and pills for its recording method and platform;
/// * [actions], when given, such as the sheet's "Re-read by UUID" and "Delete";
/// * a [TypedValueView] for the point's kind of `HealthValue` (a workout with its swimming laps and
///   events, a meal, an audiogram, an ECG, a route, ...);
/// * the [DataPointFields] every point has, and its metadata;
/// * a [RawJsonView] with the point as the plugin serializes it.
///
/// It is a column of its full height: put it in a scrolling parent, such as a `ListView` or a
/// `SliverToBoxAdapter`.
class DataPointDetails extends StatelessWidget {
  /// Creates the details of [point], with optional [actions] under the header.
  const DataPointDetails({super.key, required this.point, this.actions});

  /// The data point to show.
  final HealthDataPoint point;

  /// Widgets that act on the record, shown between the header and the value.
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataPointHeader(point: point),
        if (actions case final actions?) ...[const SizedBox(height: 20), actions],
        TypedValueView(point: point),
        DataPointFields(point: point),
        RawJsonView(point: point),
      ],
    );
  }
}
