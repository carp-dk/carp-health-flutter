/// The start and end of what a write form writes, as the `startTime` and `endTime` arguments of most write
/// methods take them.
library;

import 'package:flutter/foundation.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';

/// Adds a time span to a write form's controller: [start], [end] and [setTimes], which `TimeSpanFields`
/// edits.
///
/// The span is not checked here: an end before the start reaches the plugin, whose own check throws an
/// `ArgumentError` that the form shows, as part of what the example demonstrates.
mixin TimeSpanOption on WriteFormController {
  late DateTime _start;
  late DateTime _end;

  /// When the written data starts (`startTime`).
  DateTime get start => _start;

  /// When the written data ends (`endTime`).
  DateTime get end => _end;

  /// How long the span lasts; negative when it ends before it starts.
  Duration get duration => _end.difference(_start);

  /// Sets the first span: [length] long, ending at [end] (now, to the whole minute, by default). For the
  /// controller's constructor; it does not notify.
  @protected
  void initSpan(Duration length, {DateTime? end}) {
    _end = wholeMinute(end ?? DateTime.now());
    _start = _end.subtract(length);
  }

  /// Sets the span from [start] to [end].
  void setTimes(DateTime start, DateTime end) => update(() {
    _start = start;
    _end = end;
  });

  /// [time] without its seconds, as the date and time pickers show it.
  static DateTime wholeMinute(DateTime time) => DateTime(time.year, time.month, time.day, time.hour, time.minute);
}
