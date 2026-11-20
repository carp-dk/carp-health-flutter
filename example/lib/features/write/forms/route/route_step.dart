/// One plugin call of a workout route write, as the Workout route form lists them while they run.
library;

import 'package:flutter/foundation.dart';

/// Where a [RouteStep] is.
enum RouteStepStatus {
  /// Not called yet.
  pending,

  /// Called, waiting for the platform.
  running,

  /// Returned.
  done,

  /// Threw, or returned a failure.
  failed,
}

/// A call of [method] (such as `insertWorkoutRouteData`), its [status] and what it returned or why it
/// failed ([detail]).
@immutable
class RouteStep {
  /// Creates a step that calls [method].
  const RouteStep(this.method, {this.status = RouteStepStatus.pending, this.detail});

  /// The plugin method the step calls.
  final String method;

  /// How far the call is.
  final RouteStepStatus status;

  /// What the call returned, such as `true`, or the title of its error.
  final String? detail;

  /// This step with [status] and [detail].
  RouteStep to(RouteStepStatus status, [String? detail]) => RouteStep(method, status: status, detail: detail);

  @override
  bool operator ==(Object other) =>
      other is RouteStep && other.method == method && other.status == status && other.detail == detail;

  @override
  int get hashCode => Object.hash(method, status, detail);

  @override
  String toString() => 'RouteStep($method, ${status.name}, $detail)';
}
