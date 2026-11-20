/// The Audiogram recipe: writes a hearing test with `Health.writeAudiogram` (iOS only).
///
/// The form shows every argument of the method: the tested frequencies with the hearing threshold of each
/// ear (`frequencies`, `leftEarSensitivities`, `rightEarSensitivities`), edited in a table and drawn as an
/// audiogram, the start and end, and the HealthKit metadata of the device. On Android, where Health
/// Connect has no hearing tests and the plugin throws an `UnsupportedError`, the form says so in place of
/// its write button.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';

import 'audiogram/audiogram_chart.dart';
import 'audiogram/audiogram_controller.dart';
import 'audiogram/audiogram_points.dart';
import 'audiogram/threshold_table.dart';
import 'common/form_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/time_span_fields.dart';
import 'form_kit/write_availability.dart';

/// Writes an audiogram ([AudiogramController]): a mild age-related hearing loss at six frequencies by
/// default, with presets for normal hearing and a noise notch.
class AudiogramForm extends StatefulWidget {
  /// Creates the form.
  const AudiogramForm({super.key});

  @override
  State<AudiogramForm> createState() => _AudiogramFormState();
}

class _AudiogramFormState extends WriteFormState<AudiogramForm, AudiogramController> {
  @override
  AudiogramController createController(AppServices services) =>
      AudiogramController(services.health, capabilities: services.capabilities);

  @override
  Widget buildFields(BuildContext context) {
    final c = controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormSection(
            title: 'Hearing thresholds',
            parameter: 'frequencies · leftEarSensitivities · rightEarSensitivities',
            caption:
                'One threshold per ear and frequency, in dB HL. HealthKit takes up to 30 ascending frequencies '
                '(0-30,000 Hz) and -20 to 160 dB HL; INVALID_ARGUMENT otherwise.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                ConnectedButtonGroup<AudiogramPreset?>(
                  segments: [
                    for (final preset in AudiogramPreset.values)
                      ButtonGroupSegment<AudiogramPreset?>(value: preset, label: preset.label),
                  ],
                  // No segment is selected once the thresholds were edited.
                  selected: c.preset,
                  onSelected: (preset) {
                    if (preset != null) c.applyPreset(preset);
                  },
                ),
                FormGrid(
                  children: [
                    AudiogramChart(points: c.points),
                    ThresholdTable(controller: c),
                  ],
                ),
              ],
            ),
          ),
        ),
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Time',
                parameter: 'startTime · endTime',
                caption: 'endTime defaults to startTime. HealthKit takes up to 4 days.',
                child: TimeSpanFields(
                  start: c.start,
                  end: c.end,
                  onChanged: c.setTimes,
                  presets: const [Duration.zero, Duration(minutes: 10), Duration(minutes: 20)],
                  allowInstant: true,
                ),
              ),
              FormSection(
                title: 'Device',
                parameter: 'metadata',
                caption: 'Optional HKDeviceName and HKExternalUUID; other keys are ignored.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    TextFormField(
                      controller: c.deviceName,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Device name', prefixIcon: Icon(Icons.headphones)),
                    ),
                    TextFormField(
                      controller: c.externalUuid,
                      decoration: const InputDecoration(labelText: 'External UUID', prefixIcon: Icon(Icons.tag)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GatedWriteButton(controller: c, label: 'Write audiogram', icon: Icons.hearing, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}
