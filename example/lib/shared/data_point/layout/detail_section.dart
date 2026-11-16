/// The building blocks of the data point sheet's sections: a titled group of labelled fields in a
/// Material 3 Expressive segmented list.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';

/// A section of the data point sheet: a [SectionHeader] over a [SegmentedList] of [children], usually
/// [DetailField]s.
class DetailSection extends StatelessWidget {
  /// Creates a section titled [title] around [children].
  const DetailSection({super.key, required this.title, this.subtitle, required this.children});

  /// The section's name, such as "Swimming".
  final String title;

  /// A line under the title, such as which plugin field the section shows.
  final String? subtitle;

  /// The rows of the section.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        if (children.isNotEmpty) SegmentedList(children: children),
      ],
    );
  }
}

/// One labelled value in a [DetailSection]: the [label] small above the [value].
///
/// A [copyable] field (such as a UUID) copies its value to the clipboard when tapped. [trailing] puts
/// a widget, such as a status pill, at the end.
class DetailField extends StatelessWidget {
  /// Creates a field showing [value] under [label].
  const DetailField({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
    this.copyable = false,
    this.monospace = false,
  });

  /// What the value is, such as "Source".
  final String label;

  /// The value, as text.
  final String value;

  /// An icon before the field.
  final IconData? icon;

  /// A widget at the end of the field.
  final Widget? trailing;

  /// Whether tapping the field copies [value] to the clipboard.
  final bool copyable;

  /// Whether to show [value] in a monospace font, as for ids and codes.
  final bool monospace;

  /// The widest a [trailing] widget gets.
  static const double maxTrailingWidth = 160;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.bodyLarge!.copyWith(color: scheme.onSurface);
    return ListTile(
      leading: icon == null ? null : Icon(icon),
      title: Text(label, style: theme.textTheme.labelMedium!.copyWith(color: scheme.onSurfaceVariant)),
      subtitle: Text(value, style: monospace ? style.monospace : style),
      trailing: switch (trailing) {
        // ListTile refuses a trailing widget as wide as the tile, which a pill can be with large text:
        // capped, the pill shortens its label instead.
        final trailing? => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxTrailingWidth),
          child: trailing,
        ),
        null => copyable ? const Icon(Icons.copy, size: 18) : null,
      },
      onTap: copyable ? () => _copy(context) : null,
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger?.showSnackBar(SnackBar(content: Text('$label copied')));
  }
}
