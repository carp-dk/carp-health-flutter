/// The button that runs a write: it shows its own progress and never lets a failure escape.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/errors/error_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_dialog.dart';

/// A full-width filled button for a form's main action, such as "Write heart rate".
///
/// While [onPressed] runs, the button is disabled and shows an [ExpressiveLoadingIndicator], so a write
/// cannot be sent twice. [onPressed] normally reports its own result (see `reportWriteResult`); should
/// it throw anyway, the button names the error in a snack bar (with its details a tap away) instead of
/// letting it crash the app.
class WriteButton extends StatefulWidget {
  /// Creates a button that runs [onPressed].
  const WriteButton({super.key, required this.label, required this.onPressed, this.icon = Icons.save_alt});

  /// What the button does, such as "Write workout".
  final String label;

  /// The write; the button shows progress until the future completes.
  final Future<void> Function() onPressed;

  /// The icon before the label.
  final IconData icon;

  @override
  State<WriteButton> createState() => _WriteButtonState();
}

/// Runs the write and shows its progress until it completes.
class _WriteButtonState extends State<WriteButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      await widget.onPressed();
    } catch (error) {
      if (mounted) showErrorSnackBar(context, error, message: 'Write failed: ${ErrorInfo.from(error).title}');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const motion = ExpressiveMotion.spatialFast;
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
      onPressed: _running ? null : _run,
      icon: AnimatedSwitcher(
        duration: motion.duration,
        switchInCurve: motion,
        child: _running
            ? ExpressiveLoadingIndicator(
                key: const ValueKey('running'),
                size: 24,
                color: scheme.primary,
                semanticsLabel: 'Writing',
              )
            : Icon(widget.icon, key: const ValueKey('idle')),
      ),
      label: Text(_running ? 'Writing…' : widget.label),
    );
  }
}
