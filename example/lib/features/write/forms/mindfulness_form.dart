/// The Mindfulness recipe: writes a mindfulness session, such as a meditation, with
/// `Health.writeMindfulnessSession`.
///
/// The form shows every argument of the method: the start and end, the session type
/// (`MindfulnessSessionType`), title and notes, which only Health Connect stores (iOS saves a HealthKit
/// mindful session without them), and the recording method. On Android the write needs a Health Connect
/// with mindfulness sessions (`isMindfulnessSessionAvailable`); without one the form says why instead of
/// offering the write.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/choice_tiles.dart';
import 'form_kit/platform_section.dart';
import 'form_kit/time_span_fields.dart';
import 'form_kit/write_availability.dart';
import 'mindfulness/mindfulness_controller.dart';
import 'mindfulness/mindfulness_session_types.dart';

/// Writes a mindfulness session ([MindfulnessController]): a 10-minute breathing session that ends now,
/// as in the README.
class MindfulnessForm extends StatefulWidget {
  /// Creates the form.
  const MindfulnessForm({super.key});

  @override
  State<MindfulnessForm> createState() => _MindfulnessFormState();
}

class _MindfulnessFormState extends WriteFormState<MindfulnessForm, MindfulnessController> {
  @override
  MindfulnessController createController(AppServices services) =>
      MindfulnessController(services.health, capabilities: services.capabilities);

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
              PlatformSection(
                title: 'Session type',
                parameter: 'sessionType',
                onlyOn: HealthPlatformType.googleHealthConnect,
                caption: 'Stored with the session; reads do not return it.',
                note: "HealthKit's mindful sessions have no type.",
                child: ChoiceTiles<MindfulnessSessionType>(
                  choices: [for (final type in MindfulnessSessionType.values) type.tile],
                  selected: c.sessionType,
                  // The chosen type takes the shape that stands for mindfulness across the app.
                  selectedShape: TypeCategory.mindfulness.shape,
                  onSelected: (type) => c.sessionType = type,
                ),
              ),
              FormSection(
                title: 'Time',
                parameter: 'startTime · endTime',
                caption: 'Must end after it starts (an ArgumentError otherwise); HealthKit takes up to 28 days.',
                child: TimeSpanFields(
                  start: c.start,
                  end: c.end,
                  onChanged: c.setTimes,
                  presets: const [Duration(minutes: 5), Duration(minutes: 10), Duration(minutes: 20)],
                ),
              ),
              PlatformSection(
                title: 'Title and notes',
                parameter: 'title · notes',
                onlyOn: HealthPlatformType.googleHealthConnect,
                caption: 'Optional. Stored with the session; reads do not return them.',
                note: "HealthKit's mindful sessions have no title or notes.",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    TextFormField(
                      controller: c.title,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Title', hintText: 'Morning practice'),
                    ),
                    TextFormField(
                      controller: c.notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
              RecordingMethodSection(options: c),
            ],
          ),
        ),
        GatedWriteButton(
          controller: c,
          label: 'Write mindfulness session',
          icon: Icons.self_improvement,
          onPressed: write,
        ),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}
