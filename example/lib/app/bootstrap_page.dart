/// The splash screen shown while the app checks what the health platform offers.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'app_scope.dart';
import 'navigation/app_shell.dart';

/// Shows a splash with the expressive loading indicator while `PlatformCapabilities.refresh` asks the
/// plugin for the platform's status and features (`getHealthConnectSdkStatus` and the Health Connect
/// feature checks on Android), then springs into [child], the app shell.
///
/// The features need those answers to offer only the data types this device supports. The refresh never
/// throws (failures are kept as `PlatformCapabilities.lastError` for Setup to show); should it hang, the
/// app starts anyway after [timeout] rather than block on the splash.
class BootstrapPage extends StatefulWidget {
  /// Creates the splash that leads to [child].
  const BootstrapPage({super.key, this.child = const AppShell(), this.timeout = const Duration(seconds: 15)});

  /// What to show once the capabilities are known.
  final Widget child;

  /// The longest the splash waits for the capabilities.
  final Duration timeout;

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final capabilities = AppScope.of(context).capabilities;
    try {
      await capabilities.refresh().timeout(widget.timeout);
    } catch (error) {
      // Only the timeout gets here: refresh() keeps its own failures. Start without the answers; the
      // capabilities finish loading in the background and notify their listeners.
      debugPrint('Health example: platform checks still running after ${widget.timeout}: $error');
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    const motion = ExpressiveMotion.spatialSlow;
    return AnimatedSwitcher(
      duration: motion.duration,
      switchInCurve: motion,
      switchOutCurve: ExpressiveMotion.effectsDefault,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation.drive(ExpressiveMotion.clampToUnit),
        child: ScaleTransition(scale: animation.drive(Tween<double>(begin: 0.94, end: 1)), child: child),
      ),
      child: _ready ? KeyedSubtree(key: const ValueKey('app'), child: widget.child) : const _Splash(),
    );
  }
}

/// The splash itself: the contained loading indicator, the app's name and what is being checked.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final capabilities = AppScope.of(context).capabilities;
    // Off Android and iOS there is no health platform to check.
    final checking = capabilities.isAndroid || capabilities.isIOS
        ? 'Checking ${capabilities.platformName}…'
        : 'Starting…';
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExpressiveLoadingIndicator(size: 96, contained: true, semanticsLabel: 'Starting'),
            const SizedBox(height: 32),
            Text('Health example', style: theme.textTheme.headlineMediumEmphasized.copyWith(color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text(checking, style: theme.textTheme.bodyLarge!.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
