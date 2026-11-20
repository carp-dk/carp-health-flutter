/// The Activity intensity recipe: writes a period of moderate or vigorous activity with
/// `Health.writeActivityIntensity` (Android only).
///
/// The form shows every argument of the method: the intensity level, the start and end, the recording
/// method and the client record id and version. The write needs a Health Connect with activity intensity
/// (`isActivityIntensityAvailable`); on iOS and on Android without it the form says why in place of its
/// write button.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/choice_tiles.dart';
import 'form_kit/time_span_fields.dart';
import 'form_kit/write_availability.dart';
import 'intensity/activity_intensity_controller.dart';
import 'intensity/intensity_levels.dart';

/// Writes a period of activity ([ActivityIntensityController]): 30 minutes of moderate activity that end
/// now, as the old example wrote it.
class ActivityIntensityForm extends StatefulWidget {
  /// Creates the form.
  const ActivityIntensityForm({super.key});

  @override
  State<ActivityIntensityForm> createState() => _ActivityIntensityFormState();
}

class _ActivityIntensityFormState extends WriteFormState<ActivityIntensityForm, ActivityIntensityController> {
  @override
  ActivityIntensityController createController(AppServices services) =>
      ActivityIntensityController(services.health, capabilities: services.capabilities);

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
                title: 'Intensity',
                parameter: 'intensityLevel',
                caption: 'Moderate is like brisk walking, vigorous like running. unknown throws an ArgumentError.',
                child: ChoiceTiles<ActivityIntensityLevel>(
                  choices: [for (final level in ActivityIntensityController.levels) level.tile],
                  selected: c.level,
                  selectedShape: HealthDataType.ACTIVITY_INTENSITY.category.shape,
                  onSelected: (level) => c.level = level,
                ),
              ),
              FormSection(
                title: 'Time',
                parameter: 'startTime · endTime',
                caption:
                    'Summed into intensity minutes (see Insights). An end before the start throws an ArgumentError.',
                child: TimeSpanFields(
                  start: c.start,
                  end: c.end,
                  onChanged: c.setTimes,
                  presets: const [Duration(minutes: 15), Duration(minutes: 30), Duration(hours: 1)],
                ),
              ),
              RecordingMethodSection(options: c),
              ClientRecordIdSection(options: c),
            ],
          ),
        ),
        GatedWriteButton(controller: c, label: 'Write activity intensity', icon: Icons.speed, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}
