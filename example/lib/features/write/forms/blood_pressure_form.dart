/// The form of the Blood pressure recipe: writes one reading with `Health.writeBloodPressure`.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'blood_pressure/blood_pressure_controller.dart';
import 'common/form_section.dart';
import 'common/record_options_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';

/// Writes a blood pressure reading: systolic and diastolic pressure, the time it was measured, how it
/// was recorded and, on Android, a client record id ([BloodPressureController]).
class BloodPressureForm extends StatefulWidget {
  /// Creates the form.
  const BloodPressureForm({super.key});

  @override
  State<BloodPressureForm> createState() => _BloodPressureFormState();
}

class _BloodPressureFormState extends WriteFormState<BloodPressureForm, BloodPressureController> {
  @override
  BloodPressureController createController(AppServices services) =>
      BloodPressureController(services.health, capabilities: services.capabilities);

  @override
  Widget buildFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Reading',
                parameter: 'systolic · diastolic',
                caption: 'Whole mmHg. Health Connect returns false outside 20-200 systolic and 10-180 diastolic.',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: NumberField(
                        label: 'Systolic',
                        controller: controller.systolic,
                        unit: 'mmHg',
                        decimal: false,
                      ),
                    ),
                    Expanded(
                      child: NumberField(
                        label: 'Diastolic',
                        controller: controller.diastolic,
                        unit: 'mmHg',
                        decimal: false,
                      ),
                    ),
                  ],
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
              ClientRecordIdSection(options: controller),
            ],
          ),
        ),
        WriteButton(label: 'Write blood pressure', icon: Icons.favorite_outline, onPressed: write),
        WriteOutcomeView(controller: controller, onRetry: write),
      ],
    );
  }
}
