/// The Sexual activity recipe: writes a sexual activity entry with `Health.writeSexualActivity`.
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
import 'sexual_activity/sexual_activity_controller.dart';

/// Writes a sexual activity entry ([SexualActivityController]): protection status, time, recording
/// method and, on Android, a client record id.
class SexualActivityForm extends StatefulWidget {
  /// Creates the form.
  const SexualActivityForm({super.key});

  @override
  State<SexualActivityForm> createState() => _SexualActivityFormState();
}

class _SexualActivityFormState extends WriteFormState<SexualActivityForm, SexualActivityController> {
  @override
  SexualActivityController createController(AppServices services) =>
      SexualActivityController(services.health, capabilities: services.capabilities);

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
                title: 'Protection',
                parameter: 'protectionUsed',
                child: ChoiceTiles<SexualActivityProtection>(
                  choices: [
                    for (final option in const [
                      SexualActivityProtection.protected,
                      SexualActivityProtection.unprotected,
                      SexualActivityProtection.unknown,
                    ])
                      option.tile,
                  ],
                  selected: c.protectionUsed,
                  selectedShape: TypeCategory.cycle.shape,
                  minTileWidth: 112,
                  onSelected: (value) => c.protectionUsed = value,
                ),
              ),
              FormSection(
                title: 'Time',
                parameter: 'startTime',
                child: DateTimeField(label: 'Recorded at', value: c.time, onChanged: (time) => c.time = time),
              ),
              RecordingMethodSection(options: c),
              ClientRecordIdSection(options: c),
            ],
          ),
        ),
        WriteButton(label: 'Write sexual activity', icon: c.protectionUsed.icon, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}
