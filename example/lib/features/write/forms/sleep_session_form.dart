/// The Sleep session recipe: writes a night of sleep with its stages with `Health.writeSleepSession`.
///
/// The form shows every argument of the method: the start (the end follows from the stages), the stages
/// with their types and lengths, the title and notes, which only Health Connect stores, and the recording
/// method. On Android the night is one sleep session with its stages; on iOS, which has no sleep sessions,
/// it becomes in-bed samples and one sleep analysis sample per stage.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/widgets/form_fields/date_time_field.dart';

import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/platform_section.dart';
import 'form_kit/write_availability.dart';
import 'sleep/sleep_session_controller.dart';
import 'sleep/sleep_stage_editor.dart';

/// Writes a sleep session ([SleepSessionController]): by default a short sample night of light, deep,
/// REM and awake stages that ends now.
class SleepSessionForm extends StatefulWidget {
  /// Creates the form.
  const SleepSessionForm({super.key});

  @override
  State<SleepSessionForm> createState() => _SleepSessionFormState();
}

class _SleepSessionFormState extends WriteFormState<SleepSessionForm, SleepSessionController> {
  @override
  SleepSessionController createController(AppServices services) =>
      SleepSessionController(services.health, capabilities: services.capabilities);

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
                title: 'Start',
                parameter: 'startTime · endTime',
                caption: 'The session ends with its last stage: ${formatDateTime(c.end)}.',
                child: DateTimeField(label: 'Start', value: c.start, onChanged: c.setStart),
              ),
              FormSection(
                title: 'Stages',
                parameter: 'stages',
                caption: 'Stages run back to back from the start. iOS saves no sample for unknown or out-of-bed.',
                child: SleepStageEditor(controller: c),
              ),
              PlatformSection(
                title: 'Title and notes',
                parameter: 'title · notes',
                onlyOn: HealthPlatformType.googleHealthConnect,
                caption: 'Optional; stored with the session.',
                note: 'HealthKit has no sleep sessions.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    TextFormField(
                      controller: c.title,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextFormField(
                      controller: c.notes,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              RecordingMethodSection(options: c),
            ],
          ),
        ),
        GatedWriteButton(controller: c, label: 'Write sleep session', icon: Icons.bedtime, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}
