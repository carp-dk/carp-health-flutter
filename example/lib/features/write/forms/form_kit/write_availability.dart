/// Write methods that only some devices have: an iOS-only or Android-only method, or one that needs a
/// Health Connect feature. The form says why instead of offering a write that would fail.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/common/write_form_controller.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

/// Adds a platform gate to a write form's controller: [unavailableReason] says why this device cannot
/// make the write, and [checkAvailable] refuses a write started anyway.
///
/// The plugin itself throws for such calls (an `UnsupportedError` for `writeInsulinDelivery` on Android,
/// a `HealthException` with `HealthErrorCode.notSupported` for `writeActivityIntensity` without the
/// Health Connect feature), so the forms check first, as apps should.
mixin WriteAvailability on WriteFormController {
  /// The platform and its Health Connect features.
  PlatformCapabilities get capabilities;

  /// Why this device cannot make the write in one short line, or null when it can. Read again when
  /// [capabilities] change, as the Health Connect features are checked after the app starts.
  String? get unavailableReason;

  /// Throws an [UnsupportedError] with [unavailableReason] when this device cannot make the write.
  /// `performWrite` calls it first, so a write that bypasses the form's gate fails before the plugin.
  @protected
  void checkAvailable() {
    if (unavailableReason case final reason?) throw UnsupportedError(reason);
  }
}

/// The write button of a form whose write some devices cannot make: a [WriteButton] where
/// [WriteAvailability.unavailableReason] is null, else an [UnavailableNotice] that says why.
///
/// It rebuilds when the platform's capabilities change, for example when the Health Connect feature
/// checks finish after the form opened.
class GatedWriteButton extends StatelessWidget {
  /// Creates the button for [controller]'s write, which [onPressed] runs.
  const GatedWriteButton({
    super.key,
    required this.controller,
    required this.label,
    required this.onPressed,
    this.icon = Icons.save_alt,
  });

  /// The form's controller.
  final WriteAvailability controller;

  /// What the button does, such as "Write insulin delivery".
  final String label;

  /// The icon of the button.
  final IconData icon;

  /// Runs the write, such as `WriteFormState.write`.
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.capabilities,
      builder: (context, _) {
        final reason = controller.unavailableReason;
        const motion = ExpressiveMotion.spatialDefault;
        return AnimatedSwitcher(
          duration: motion.duration,
          switchInCurve: motion,
          child: reason == null
              ? WriteButton(key: const ValueKey('write'), label: label, icon: icon, onPressed: onPressed)
              : UnavailableNotice(key: ValueKey(reason), reason: reason),
        );
      },
    );
  }
}

/// Why a write method cannot be used on this device, in place of its write button: a shaped icon, a
/// title and the one-line [reason].
class UnavailableNotice extends StatelessWidget {
  /// Creates the notice for [reason].
  const UnavailableNotice({super.key, required this.reason});

  /// Why the write cannot be made here.
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      child: Row(
        spacing: 16,
        children: [
          ShapedIcon(
            icon: Icons.do_not_disturb_on_outlined,
            shape: ExpressiveShape.cookie4,
            size: 40,
            background: scheme.tertiaryContainer,
            foreground: scheme.onTertiaryContainer,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text('Not available here', style: theme.textTheme.titleSmallEmphasized),
                Text(reason, style: theme.textTheme.bodyMedium!.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
