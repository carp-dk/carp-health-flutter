/// The list of a sleep session's stages in the Sleep session form: each stage's type and length, and
/// buttons to add and remove stages.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/form_kit/duration_stepper.dart';

import 'sleep_session_controller.dart';

/// The stages of [controller]'s session in order, each with its start time, a type menu, a length
/// stepper and a remove button, and an "Add stage" menu under them.
class SleepStageEditor extends StatelessWidget {
  /// Creates the editor of [controller]'s stages.
  const SleepStageEditor({super.key, required this.controller});

  /// The session being edited.
  final SleepSessionController controller;

  @override
  Widget build(BuildContext context) {
    final stages = controller.stages;
    final starts = [for (final stage in controller.buildStages()) stage.startTime];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, stage) in stages.indexed)
          _StageRow(
            index: index,
            stage: stage,
            start: starts[index],
            canRemove: stages.length > 1,
            controller: controller,
          ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MenuAnchor(
            menuChildren: [
              for (final type in SleepSessionController.stageTypes)
                MenuItemButton(onPressed: () => controller.addStage(type), child: Text(type.label)),
            ],
            builder: (context, menu, _) => TextButton.icon(
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(Icons.add),
              label: const Text('Add stage'),
            ),
          ),
        ),
      ],
    );
  }
}

/// One stage: when it starts, its type (a dropdown), its length and a remove button.
class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.index,
    required this.stage,
    required this.start,
    required this.canRemove,
    required this.controller,
  });

  final int index;
  final SleepStageDraft stage;
  final DateTime start;
  final bool canRemove;
  final SleepSessionController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              SizedBox(width: 48, child: Text(formatTime(start), style: text.labelLarge!.tabular)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: DropdownButton<HealthDataType>(
                  value: stage.type,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  onChanged: (type) => type == null ? null : controller.setStageType(index, type),
                  items: [
                    for (final type in SleepSessionController.stageTypes)
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              DurationStepper(
                value: stage.duration,
                onChanged: (duration) => controller.setStageDuration(index, duration),
                step: SleepSessionController.stageStep,
                min: SleepSessionController.minStage,
                max: SleepSessionController.maxStage,
                label: 'stage ${index + 1}',
              ),
              IconButton(
                tooltip: 'Remove stage ${index + 1}',
                onPressed: canRemove ? () => controller.removeStageAt(index) : null,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
