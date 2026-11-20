/// The sample data on the Write page: its card and, under it, the live result of every step.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'sample_data_card.dart';
import 'sample_data_controller.dart';
import 'sample_step_tile.dart';

/// The [SampleDataCard] and the list of the plan's steps ([SampleStepTile]s), which springs open when a
/// run starts and can be shown or hidden at any time.
class SampleDataSection extends StatefulWidget {
  /// Creates the section of [controller].
  const SampleDataSection({super.key, required this.controller});

  /// The sample data's state and calls.
  final SampleDataController controller;

  @override
  State<SampleDataSection> createState() => _SampleDataSectionState();
}

class _SampleDataSectionState extends State<SampleDataSection> {
  bool _showSteps = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(SampleDataSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  /// A run, also one started from the page's menu, opens the list so its progress shows step by step.
  void _onChange() {
    if (widget.controller.isRunning && !_showSteps) setState(() => _showSteps = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    const motion = ExpressiveMotion.spatialDefault;
    return ListenableBuilder(
      // The capabilities decide which steps run: Health Connect's features arrive after the app starts.
      listenable: Listenable.merge([controller, controller.capabilities]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SampleDataCard(
            controller: controller,
            showSteps: _showSteps,
            onToggleSteps: () => setState(() => _showSteps = !_showSteps),
          ),
          AnimatedSize(
            duration: motion.duration,
            curve: motion,
            alignment: Alignment.topCenter,
            child: _showSteps
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SegmentedList(
                      children: [
                        for (var i = 0; i < controller.steps.length; i++)
                          SampleStepTile(
                            step: controller.steps[i],
                            result: controller.resultOf(i),
                            skipReason: controller.skipReasonOf(i),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
