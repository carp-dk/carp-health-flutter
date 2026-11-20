/// The form sections for a write's recording method and Health Connect client record id.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/features/write/forms/form_kit/form_note.dart';
import 'package:health_example/shared/visuals/recording_method_visuals.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import 'form_section.dart';
import 'record_options.dart';

/// The recording method of a write, as a connected button group of the methods the platform takes
/// ([RecordingMethodOption.recordingMethods]).
class RecordingMethodSection extends StatelessWidget {
  /// Creates the section for [options].
  const RecordingMethodSection({super.key, required this.options});

  /// The form's controller.
  final RecordingMethodOption options;

  @override
  Widget build(BuildContext context) {
    final method = options.recordingMethod;
    return FormSection(
      title: 'Recording method',
      parameter: 'recordingMethod',
      caption: options.capabilities.isIOS
          ? '${method.description} iOS takes manual or automatic only.'
          : method.description,
      child: ConnectedButtonGroup<RecordingMethod>(
        segments: [
          for (final choice in options.recordingMethods) ButtonGroupSegment(value: choice, label: choice.shortLabel),
        ],
        selected: method,
        onSelected: (choice) => options.recordingMethod = choice,
      ),
    );
  }
}

/// The client record id and version of a write (Health Connect): fields on Android, and on iOS a one-line
/// note that the plugin ignores them, marked "Android only" either way.
class ClientRecordIdSection extends StatelessWidget {
  /// Creates the section for [options].
  const ClientRecordIdSection({super.key, required this.options});

  /// The form's controller.
  final ClientRecordIdOption options;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Client record id',
      parameter: 'clientRecordId · clientRecordVersion',
      trailing: const PlatformBadge.android(),
      caption: options.supportsClientRecordId
          ? 'Optional. The same id with a higher version replaces the record; deleteByClientRecordId deletes it.'
          : 'HealthKit has no client record ids.',
      child: options.supportsClientRecordId
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: options.clientRecordId,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Id', hintText: 'reading-42'),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: NumberField(label: 'Version', controller: options.clientRecordVersion, isRequired: false),
                ),
              ],
            )
          : const FormNote(text: 'Ignored on iOS'),
    );
  }
}
