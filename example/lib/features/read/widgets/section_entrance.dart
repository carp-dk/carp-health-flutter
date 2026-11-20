/// The motion with which a section of the Read page appears when the button group switches to it.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

/// Shows [sliver] and fades it in whenever [section] changes, on the slow effects spring, so that
/// switching sections reads as one motion with the button group's segment springing to the new one.
///
/// Skipped when the platform asks for reduced motion. Only a fade, as a sliver cannot be moved or scaled
/// as a whole; the cards in the sections bring their own spring motion.
class SectionEntrance extends StatefulWidget {
  /// Creates the entrance of [sliver], the content of [section].
  const SectionEntrance({super.key, required this.section, required this.sliver});

  /// The section shown; a change fades the new [sliver] in.
  final Object section;

  /// The section's content.
  final Widget sliver;

  @override
  State<SectionEntrance> createState() => _SectionEntranceState();
}

class _SectionEntranceState extends State<SectionEntrance> with SingleTickerProviderStateMixin {
  // At rest (value 1) the section is fully shown, also on the first build.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.effectsSlow.duration,
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(parent: _entrance, curve: ExpressiveMotion.effectsSlow);

  @override
  void didUpdateWidget(SectionEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section && !ExpressiveMotion.isReduced(context)) {
      _entrance.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SliverFadeTransition(opacity: _opacity, sliver: widget.sliver);
}
