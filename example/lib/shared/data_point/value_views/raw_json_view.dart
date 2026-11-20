/// A data point exactly as the plugin serializes it: `HealthDataPoint.toJson`, printed with
/// carp_serializable's `toJsonString`.
library;

import 'dart:convert' show JsonUnsupportedObjectError;

import 'package:carp_serializable/carp_serializable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';

/// A collapsed section that shows [point] as JSON when opened, with a button that copies it.
///
/// Every `HealthDataPoint` and `HealthValue` is JSON serializable (carp_serializable's `Serializable`,
/// with a `__type` for the value), which is how apps usually store or upload what they read. The JSON
/// is only built when the section is opened or copied, as an ECG or a long route makes a large text;
/// at most [maxShown] characters are shown, and copying gives all of it.
class RawJsonView extends StatefulWidget {
  /// Creates the JSON section of [point].
  const RawJsonView({super.key, required this.point});

  /// The data point to serialize.
  final HealthDataPoint point;

  /// The most characters shown.
  static const int maxShown = 20000;

  /// [point] as indented JSON (`toJsonString`), or a note with its `toString` if a value in its
  /// metadata cannot be encoded.
  static String encode(HealthDataPoint point) {
    try {
      return toJsonString(point);
    } on JsonUnsupportedObjectError catch (error) {
      return '// Not encodable as JSON: ${error.unsupportedObject.runtimeType}\n$point';
    }
  }

  @override
  State<RawJsonView> createState() => _RawJsonViewState();
}

/// Encodes the point once, when the JSON is first shown or copied, and copies it to the clipboard.
class _RawJsonViewState extends State<RawJsonView> {
  String? _json;

  /// The JSON, built once per point.
  String get _encoded => _json ??= RawJsonView.encode(widget.point);

  @override
  void didUpdateWidget(RawJsonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A re-read by UUID replaces the point.
    if (oldWidget.point != widget.point) _json = null;
  }

  Future<void> _copy() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: _encoded));
    messenger?.showSnackBar(const SnackBar(content: Text('JSON copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Raw JSON',
          trailing: IconButton.filledTonal(tooltip: 'Copy JSON', onPressed: _copy, icon: const Icon(Icons.copy)),
        ),
        Material(
          color: scheme.surfaceContainer,
          shape: ExpressiveShapes.rounded(ExpressiveShapes.largeIncreased),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Show JSON'),
            // Collapsed, ExpansionTile does not build its children: the builder encodes on opening.
            children: [Builder(builder: (context) => _JsonText(json: _encoded))],
          ),
        ),
      ],
    );
  }
}

/// The JSON in a monospace, selectable, horizontally scrolling text, cut at [RawJsonView.maxShown].
class _JsonText extends StatelessWidget {
  const _JsonText({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cut = json.length > RawJsonView.maxShown;
    final shown = cut
        ? '${json.substring(0, RawJsonView.maxShown)}\n… ${formatNumber(json.length - RawJsonView.maxShown)} more '
              'characters (copy for all)'
        : json;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SelectableText(
        shown,
        style: theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurface).monospace,
      ),
    );
  }
}
