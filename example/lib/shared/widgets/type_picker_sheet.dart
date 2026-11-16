/// The sheet in which the user picks data types: searchable, grouped by category, with select-all per
/// category. Read, Insights, Setup and Delete pick the types they work on with it.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/design/design.dart';

import 'type_picker/type_category_group.dart';
import 'type_picker/type_picker_header.dart';
import 'type_picker/type_picker_model.dart';

/// Shows a [TypePickerSheet] offering [available] with [initial] selected, and returns the selection,
/// or null when the user closed the sheet without choosing.
///
/// With [multiple] (the default) the user checks any number of types and confirms with Done; otherwise
/// tapping a type picks it and closes the sheet.
Future<Set<HealthDataType>?> showTypePicker(
  BuildContext context, {
  required List<HealthDataType> available,
  Set<HealthDataType> initial = const {},
  bool multiple = true,
  String title = 'Choose data types',
}) => showModalBottomSheet<Set<HealthDataType>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => TypePickerSheet(available: available, initial: initial, multiple: multiple, title: title),
);

/// The content of the type picker: a [TypePickerHeader] (title, selection count and search bar) pinned
/// over the matching types by category ([TypeCategoryGroup]), and, for several types, Cancel and Done.
/// The state lives in a [TypePickerModel].
class TypePickerSheet extends StatefulWidget {
  /// Creates a picker offering [available], with [initial] selected.
  const TypePickerSheet({
    super.key,
    required this.available,
    this.initial = const {},
    this.multiple = true,
    this.title = 'Choose data types',
  });

  /// The types offered.
  final List<HealthDataType> available;

  /// The types selected when the sheet opens.
  final Set<HealthDataType> initial;

  /// Whether several types can be picked.
  final bool multiple;

  /// The sheet's title.
  final String title;

  @override
  State<TypePickerSheet> createState() => _TypePickerSheetState();
}

/// Owns the picker's [TypePickerModel] and the search field's controller.
class _TypePickerSheetState extends State<TypePickerSheet> {
  late final TypePickerModel _model = TypePickerModel(
    available: widget.available,
    initial: widget.initial,
    multiple: widget.multiple,
  );
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _model.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Toggles [type], or with a single choice picks it and closes the sheet.
  void _pick(HealthDataType type) {
    if (widget.multiple) {
      _model.toggle(type);
    } else {
      Navigator.pop(context, {type});
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // The search bar's keyboard pushes the sheet up rather than covering the list and the buttons. The
    // keyboard also covers the home indicator, so the sheet then needs no bottom safe area of its own.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: keyboard > 0,
        child: FractionallySizedBox(
          heightFactor: 0.9,
          child: ListenableBuilder(
            listenable: _model,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _content(context)),
                if (widget.multiple) _buttons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The header, pinned over the matching types that scroll under it, or an explanation when no type
  /// matches the search. Only the button bar stays outside the scrolling area, so large text cannot
  /// squeeze the list out of the sheet.
  Widget _content(BuildContext context) {
    final groups = _model.groups.entries.toList();
    // Without the button bar (a single choice), the list itself keeps clear of the home indicator.
    final bottomInset = widget.multiple ? 0.0 : MediaQuery.paddingOf(context).bottom;
    return CustomScrollView(
      slivers: [
        PinnedHeaderSliver(
          child: TypePickerHeader(title: widget.title, model: _model, search: _search),
        ),
        if (groups.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No data type matches "${_model.query}"',
              message: 'Search by name, such as "heart rate", or by code, such as HEART_RATE.',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
            sliver: SliverList.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) => TypeCategoryGroup(
                category: groups[index].key,
                types: groups[index].value,
                model: _model,
                onPick: _pick,
              ),
            ),
          ),
      ],
    );
  }

  /// Cancel, and Done with the number of types selected.
  Widget _buttons(BuildContext context) {
    final count = _model.selected.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          spacing: 8,
          children: [
            // Capped, so that large text cannot crowd Done out of the row.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => Navigator.pop(context, _model.selected.toSet()),
                icon: const Icon(Icons.check),
                label: Text(
                  count == 1 ? 'Done · 1 type' : 'Done · $count types',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
