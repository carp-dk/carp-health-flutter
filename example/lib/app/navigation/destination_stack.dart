/// The pages of the top-level destinations, kept alive while another one is shown.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'app_destination.dart';

/// Shows the page of [current] and keeps the page of every visited destination alive (in an
/// [IndexedStack]), so that switching back finds it as it was left: its controller, its results, its
/// scroll position.
///
/// A page is built the first time its destination is shown, so that its plugin calls only start when
/// the user goes there. Hidden pages are paused ([TickerMode]): their loading indicators and other
/// animations stop. Each page gets its own [PrimaryScrollController] from [scrollControllers], so pages
/// scroll independently and the shell can scroll one back to the top. Switching destinations fades the
/// new page in while it settles from a slight zoom (a fade-through on the expressive springs).
class DestinationStack extends StatefulWidget {
  /// Creates the stack of destination pages.
  const DestinationStack({
    super.key,
    required this.current,
    required this.pageBuilder,
    required this.scrollControllers,
  });

  /// The destination shown.
  final AppDestination current;

  /// Builds the page of a destination.
  final Widget Function(AppDestination destination) pageBuilder;

  /// The primary scroll controller of each destination's page.
  final Map<AppDestination, ScrollController> scrollControllers;

  @override
  State<DestinationStack> createState() => _DestinationStackState();
}

class _DestinationStackState extends State<DestinationStack> with SingleTickerProviderStateMixin {
  final Set<AppDestination> _visited = {};

  // Runs once per switch; at rest (value 1) the page is fully shown.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.spatialDefault.duration,
    value: 1,
  );

  // The fade uses the first 40 % (the effects spring's 200 ms), the zoom the whole spatial spring.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, 0.4, curve: ExpressiveMotion.effectsDefault),
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.96,
    end: 1,
  ).animate(CurvedAnimation(parent: _entrance, curve: ExpressiveMotion.spatialDefault));

  @override
  void didUpdateWidget(DestinationStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current && !ExpressiveMotion.isReduced(context)) {
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.current);
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: IndexedStack(
          index: widget.current.index,
          sizing: StackFit.expand,
          children: [
            for (final destination in AppDestination.values)
              TickerMode(
                enabled: destination == widget.current,
                child: _visited.contains(destination)
                    ? PrimaryScrollController(
                        controller: widget.scrollControllers[destination]!,
                        child: widget.pageBuilder(destination),
                      )
                    : const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
