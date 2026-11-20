/// The form of the Blood oxygen recipe: writes one oxygen saturation with `Health.writeBloodOxygen`.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'blood_oxygen/blood_oxygen_controller.dart';
import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';

/// Writes an oxygen saturation in percent, with the time it was measured and how it was recorded
/// ([BloodOxygenController]). It shows which value goes to the plugin on this platform.
class BloodOxygenForm extends StatefulWidget {
  /// Creates the form.
  const BloodOxygenForm({super.key});

  @override
  State<BloodOxygenForm> createState() => _BloodOxygenFormState();
}

class _BloodOxygenFormState extends WriteFormState<BloodOxygenForm, BloodOxygenController> {
  @override
  BloodOxygenController createController(AppServices services) =>
      BloodOxygenController(services.health, capabilities: services.capabilities);

  @override
  Widget buildFields(BuildContext context) {
    final percent = NumberField.parse(controller.saturation.text);
    final argument = percent == null ? null : formatNumber(controller.saturationArgument(percent), maxDecimals: 4);
    final platform = controller.capabilities.isIOS ? 'HealthKit takes a fraction' : 'Health Connect takes a percentage';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Saturation',
                parameter: 'saturation',
                caption: argument == null ? '$platform.' : '$platform: saturation: $argument.',
                child: NumberField(
                  label: 'Oxygen saturation',
                  controller: controller.saturation,
                  unit: '%',
                  // Rebuilds the caption, which shows the argument the plugin gets.
                  onChanged: (_) => setState(() {}),
                ),
              ),
              FormSection(
                title: 'Measured at',
                parameter: 'startTime',
                caption: 'A moment: endTime defaults to startTime.',
                child: DateTimeField(
                  label: 'Time',
                  value: controller.measuredAt,
                  onChanged: (time) => controller.measuredAt = time,
                ),
              ),
              RecordingMethodSection(options: controller),
            ],
          ),
        ),
        WriteButton(label: 'Write blood oxygen', icon: Icons.air, onPressed: write),
        WriteOutcomeView(controller: controller, onRetry: write),
      ],
    );
  }
}
