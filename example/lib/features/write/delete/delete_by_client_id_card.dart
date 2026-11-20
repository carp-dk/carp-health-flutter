/// The Delete page's form for `Health.deleteByClientRecordId` (Health Connect only).
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/async/async_value.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/widgets/error_card.dart';
import 'package:health_example/shared/widgets/form_fields.dart';

import '../forms/common/form_section.dart';
import 'delete_controller.dart';

/// The type, client record id and optional record id of a `deleteByClientRecordId` call, with chips for
/// this session's writes that used a client record id, the button that deletes, and what the call
/// returned. On iOS, which has no client record ids, one line says so, with the alternatives behind an
/// info button.
class DeleteByClientIdCard extends StatelessWidget {
  /// Creates the form of [controller].
  const DeleteByClientIdCard({super.key, required this.controller});

  /// The Delete page's state and calls.
  final DeleteController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.supportsClientRecordId) {
      return ExpressiveCard(
        variant: ExpressiveCardVariant.outlined,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          'Android only',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }
    final busy = c.clientIdResult.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        FormCard(
          child: FormGrid(
            children: [
              FormSection(
                title: 'Record',
                parameter: 'dataTypeKey · clientRecordId',
                caption:
                    'The id the app wrote the record with. A workout\'s distance and energy use <id>:distance '
                    'and <id>:calories.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    EnumDropdownField<HealthDataType>(
                      // A type picked from a chip resets the menu's selection.
                      key: ValueKey(c.clientIdType),
                      label: 'Data type',
                      value: c.clientIdType,
                      values: c.deletableTypes,
                      labelOf: (type) => type.label,
                      iconOf: (type) => type.icon,
                      onChanged: (type) => c.clientIdType = type,
                    ),
                    TextField(
                      controller: c.clientRecordId,
                      decoration: const InputDecoration(labelText: 'Client record id', prefixIcon: Icon(Icons.tag)),
                    ),
                  ],
                ),
              ),
              FormSection(
                title: 'Record id',
                parameter: 'recordId',
                caption: 'Optional: another record of the type, deleted in the same call.',
                child: TextField(
                  controller: c.recordId,
                  decoration: const InputDecoration(labelText: 'Record id (UUID)', prefixIcon: Icon(Icons.fingerprint)),
                ),
              ),
            ],
          ),
        ),
        if (c.clientIdWrites.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final write in c.clientIdWrites.take(6))
                ActionChip(
                  avatar: Icon(write.type.icon),
                  label: Text('${write.type.label} · ${write.clientRecordId}'),
                  onPressed: busy ? null : () => c.useWrite(write),
                ),
            ],
          ),
        _DeleteButton(
          busy: busy,
          onPressed: c.clientRecordId.text.trim().isEmpty ? null : () => _confirmAndDelete(context),
        ),
        _Result(controller: c),
      ],
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final c = controller;
    final scheme = Theme.of(context).colorScheme;
    final id = c.clientRecordId.text.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete this record?'),
        content: Text('${c.clientIdType.label} · $id'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await c.deleteByClientRecordId();
  }
}

/// The error-coloured delete button, with a loading indicator while the plugin deletes.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? ExpressiveLoadingIndicator(size: 24, color: scheme.error, semanticsLabel: 'Deleting')
          : const Icon(Icons.delete_outline),
      label: Text(busy ? 'Deleting…' : 'Delete record'),
    );
  }
}

/// What the last `deleteByClientRecordId` returned.
class _Result extends StatelessWidget {
  const _Result({required this.controller});

  final DeleteController controller;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (controller.clientIdResult) {
      AsyncIdle() || AsyncLoading() => const SizedBox(width: double.infinity),
      AsyncData(:final value) => _Outcome(deleted: value),
      AsyncError(:final error) => ErrorCard(error: error, onRetry: controller.deleteByClientRecordId),
    };
    const motion = ExpressiveMotion.spatialDefault;
    return AnimatedSize(duration: motion.duration, curve: motion, alignment: Alignment.topCenter, child: child);
  }
}

/// What `deleteByClientRecordId` returned ([deleted]): a status pill, with what it means behind an info
/// button.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.deleted});

  final bool deleted;

  @override
  Widget build(BuildContext context) {
    final label = deleted ? 'Deleted' : 'Not deleted';
    return Row(
      children: [
        StatusPill(label: label, tone: deleted ? StatusTone.success : StatusTone.warning),
        InfoButton(
          title: label,
          code: 'deleteByClientRecordId → $deleted',
          // Health Connect deletes by id without telling whether a record had it.
          message: deleted
              ? 'No record of the type has the id any more. Health Connect also returns true when none had it.'
              : 'Health Connect refused, for example for another app\'s record or without the write permission.',
        ),
      ],
    );
  }
}
