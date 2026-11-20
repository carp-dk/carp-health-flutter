/// The Setup page's platform section: which health platform the plugin uses here and whether it can be
/// used (`getHealthConnectSdkStatus`, `installHealthConnect` on Android; the iOS version on iOS), and
/// which of the platform's data types this device supports.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/shared/widgets/error_card.dart';

import '../controllers/platform_controller.dart';
import 'platform/platform_hero_card.dart';
import 'platform/type_support_card.dart';

/// The platform hero card, an `ErrorCard` when a check failed, and the data type support card. Rebuilds
/// when the controller or the app's capabilities change, also when another page refreshed them.
class PlatformSection extends StatelessWidget {
  /// Creates the section for [controller].
  const PlatformSection({super.key, required this.controller});

  /// The platform's state and actions.
  final PlatformController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, controller.capabilities]),
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        PlatformHeroCard(controller: controller),
        // A failed check leaves its flag false; the error says which call failed and why.
        if (controller.status case AsyncError(:final error)) ErrorCard(error: error, onRetry: controller.refresh),
        if (controller.install case AsyncError(:final error))
          ErrorCard(error: error, onRetry: controller.installHealthConnect),
        TypeSupportCard(controller: controller),
      ],
    ),
  );
}
