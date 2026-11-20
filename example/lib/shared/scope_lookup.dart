/// Lookups of the app's services for the shared widgets that also work where the app does not provide
/// them, such as a widget test of one widget: they fall back to the platform Flutter targets.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';

/// The app's services when an `AppScope` is above [context], else null.
///
/// Unlike `AppScope.of`, it does not assert, so a shared widget can offer an extra (such as adding a
/// write to the recent writes) only where the services exist. Like `AppScope.of`, it registers no
/// dependency.
AppServices? maybeAppServices(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()?.services;

/// The health platform the app runs on: the platform of the app's `PlatformCapabilities` (which tests
/// can set), else Health Connect or Apple Health by the platform Flutter targets.
///
/// Shared widgets use it to explain platform differences, for example that HealthKit can only leave
/// out manual entries.
HealthPlatformType healthPlatformOf(BuildContext context) =>
    maybeAppServices(context)?.capabilities.platform ??
    (defaultTargetPlatform == TargetPlatform.iOS
        ? HealthPlatformType.appleHealth
        : HealthPlatformType.googleHealthConnect);
