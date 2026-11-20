/// The Insulin delivery recipe: writes the insulin units delivered, and why, with
/// `Health.writeInsulinDelivery` (iOS only).
///
/// The form shows every argument of the method: the units, the reason (`InsulinDeliveryReason`, basal or
/// bolus), and the start and end. On Android, where Health Connect has no insulin type and the plugin
/// throws an `UnsupportedError`, the form says so in place of its write button.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'common/form_section.dart';
import 'common/write_form_state.dart';
import 'common/write_outcome_view.dart';
import 'form_kit/time_span_fields.dart';
import 'form_kit/write_availability.dart';
import 'insulin/insulin_delivery_controller.dart';

/// Writes an insulin delivery ([InsulinDeliveryController]): a 5 IU bolus delivered now, as the old
/// example wrote it.
class InsulinDeliveryForm extends StatefulWidget {
  /// Creates the form.
  const InsulinDeliveryForm({super.key});

  @override
  State<InsulinDeliveryForm> createState() => _InsulinDeliveryFormState();
}

class _InsulinDeliveryFormState extends WriteFormState<InsulinDeliveryForm, InsulinDeliveryController> {
  @override
  InsulinDeliveryController createController(AppServices services) =>
      InsulinDeliveryController(services.health, capabilities: services.capabilities);

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
                title: 'Dose',
                parameter: 'units',
                caption: 'International units (IU), as HealthKit stores insulin.',
                child: NumberField(
                  label: 'Insulin',
                  controller: c.units,
                  unit: 'IU',
                  onChanged: (_) => c.unitsChanged(),
                ),
              ),
              FormSection(
                title: 'Reason',
                parameter: 'reason',
                caption: 'HealthKit requires it, so writeHealthData refuses insulin. NOT_SET throws an ArgumentError.',
                child: ConnectedButtonGroup<InsulinDeliveryReason>(
                  segments: const [
                    ButtonGroupSegment(value: InsulinDeliveryReason.BASAL, label: 'Basal', icon: Icons.timelapse),
                    ButtonGroupSegment(value: InsulinDeliveryReason.BOLUS, label: 'Bolus', icon: Icons.bolt),
                  ],
                  selected: c.reason,
                  onSelected: (reason) => c.reason = reason,
                ),
              ),
              FormSection(
                title: 'Time',
                parameter: 'startTime · endTime',
                caption: 'A bolus is usually instant, basal insulin a period. An end before the start throws.',
                child: TimeSpanFields(
                  start: c.start,
                  end: c.end,
                  onChanged: c.setTimes,
                  presets: const [Duration.zero, Duration(minutes: 30), Duration(hours: 1)],
                  allowInstant: true,
                ),
              ),
            ],
          ),
        ),
        GatedWriteButton(controller: c, label: 'Write insulin delivery', icon: Icons.vaccines, onPressed: write),
        WriteOutcomeView(controller: c, onRetry: write),
      ],
    );
  }
}
