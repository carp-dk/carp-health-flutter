/// Pull to refresh with the Material 3 Expressive loading indicator.
library;

import 'package:flutter/material.dart';

import '../theme/expressive_motion.dart';
import 'loading_indicator.dart';

/// Pull to refresh for the scrollable [child] that shows the contained [ExpressiveLoadingIndicator]
/// instead of the classic circular spinner.
///
/// Built on `RefreshIndicator.noSpinner`, which does the gesture handling: the indicator springs in once
/// the pull is far enough to refresh, stays while [onRefresh] runs and springs out when it completes.
class ExpressiveRefreshIndicator extends StatefulWidget {
  /// Creates pull to refresh around [child].
  const ExpressiveRefreshIndicator({super.key, required this.onRefresh, required this.child, this.edgeOffset = 0});

  /// Called when the user pulls far enough; the indicator stays until the future completes.
  final Future<void> Function() onRefresh;

  /// The scrollable content.
  final Widget child;

  /// How far below the top safe area the indicator appears (for content under a pinned header).
  final double edgeOffset;

  @override
  State<ExpressiveRefreshIndicator> createState() => _ExpressiveRefreshIndicatorState();
}

class _ExpressiveRefreshIndicatorState extends State<ExpressiveRefreshIndicator> {
  RefreshIndicatorStatus? _status;

  bool get _showing => switch (_status) {
    RefreshIndicatorStatus.armed || RefreshIndicatorStatus.snap || RefreshIndicatorStatus.refresh => true,
    _ => false,
  };

  void _onStatusChange(RefreshIndicatorStatus? status) {
    // The status also changes when a refresh completes after the page went away.
    if (mounted && status != _status) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + widget.edgeOffset + 24;
    return Stack(
      children: [
        RefreshIndicator.noSpinner(onRefresh: widget.onRefresh, onStatusChange: _onStatusChange, child: widget.child),
        Positioned(
          top: top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: ExpressiveMotion.spatialFast.duration,
                switchInCurve: ExpressiveMotion.spatialFast,
                switchOutCurve: ExpressiveMotion.effectsFast,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: _showing
                    ? const ExpressiveLoadingIndicator(
                        key: ValueKey('refreshing'),
                        contained: true,
                        semanticsLabel: 'Refreshing',
                      )
                    : const SizedBox.shrink(key: ValueKey('idle')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
