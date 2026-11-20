/// The Menstruation flow recipe: writes a menstrual flow with `Health.writeMenstruationFlow`.
///
/// The form shows every argument of the method: the flow (the `MenstrualFlow`s the platform writes as
/// themselves), the time it was observed (`startTime` and `endTime`), whether it starts a cycle
/// (`isStartOfCycle`, which only HealthKit stores) and the recording method.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/shared/visuals/type_icon.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/choice_tiles.dart';
import 'form_kit/platform_section.dart';
import 'menstruation/menstrual_flows.dart';
import 'menstruation/menstruation_flow_controller.dart';

/// Writes a menstrual flow ([MenstruationFlowController]): a medium flow that starts a cycle, observed
/// now, as the old example wrote it.
class MenstruationFlowForm extends StatefulWidget {
  /// Creates the form.
  const MenstruationFlowForm({super.key});

  @override
  State<MenstruationFlowForm> createState() => _MenstruationFlowFormState();
}

class _MenstruationFlowFormState extends WriteFormState<MenstruationFlowForm, MenstruationFlowController> {
  @override
  MenstruationFlowController createController(AppServices services) =>
      MenstruationFlowController(services.health, capabilities: services.capabilities);

  @override
  Widget buildFields(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Flow',
                parameter: 'flow',
                caption: c.capabilities.isIOS
                    ? "Only light, medium and heavy match HealthKit's flow values."
                    : 'Health Connect has no "none" or "spotting" flow (an ArgumentError).',
                child: ChoiceTiles<MenstrualFlow>(
                  choices: [for (final flow in c.flows) flow.tile],
                  selected: c.flow,
                  // The chosen flow takes the shape that stands for the cycle across the app.
                  selectedShape: TypeCategory.cycle.shape,
                  minTileWidth: 132,
                  onSelected: (flow) => c.flow = flow,
                ),
              ),
              FormSection(
                title: 'Time',
                parameter: 'startTime · endTime',
                caption: 'A flow is a moment: this time is sent as both startTime and endTime.',
                child: DateTimeField(label: 'Observed at', value: c.time, onChanged: (time) => c.time = time),
              ),
              PlatformSection(
                title: 'Start of cycle',
                parameter: 'isStartOfCycle',
                onlyOn: HealthPlatformType.appleHealth,
                caption: 'HealthKit requires this flag, so writeHealthData refuses flows on iOS.',
                note: "Health Connect's flow records have no such flag.",
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts a cycle'),
                  secondary: const Icon(Icons.restart_alt),
                  value: c.startOfCycle,
                  onChanged: (value) => c.startOfCycle = value,
                ),
              ),
              RecordingMethodSection(options: c),
            ],
          ),
        ),
        WriteButton(label: 'Write menstruation flow', icon: c.flow.icon, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}
