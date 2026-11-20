/// The top of the type picker: its title, a button that clears the selection, and the search bar.
library;

import 'package:flutter/material.dart';
import 'package:health_example/design/design.dart';

import 'type_picker_model.dart';

/// The type picker's [title] (at most two lines), "Clear N" while several types can be picked and some
/// are selected, and a search bar that sets [TypePickerModel.query] as the user types.
///
/// The picker pins it over the list of types, so it paints the sheet's own colour to hide the types
/// that scroll under it.
class TypePickerHeader extends StatelessWidget {
  /// Creates the header of a picker whose state is [model], searching with the text of [search].
  const TypePickerHeader({super.key, required this.title, required this.model, required this.search});

  /// The picker's title.
  final String title;

  /// The picker's state: the selection to clear and the query to set.
  final TypePickerModel model;

  /// The text of the search bar, which the clear-search button empties.
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = model.selected.length;
    return ColoredBox(
      color: theme.bottomSheetTheme.modalBackgroundColor ?? theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmallEmphasized,
                  ),
                ),
                if (model.multiple && count > 0) TextButton(onPressed: model.clear, child: Text('Clear $count')),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SearchBar(
                controller: search,
                hintText: 'Search ${model.available.length} types',
                leading: const Icon(Icons.search),
                trailing: [
                  if (model.query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        search.clear();
                        model.query = '';
                      },
                    ),
                ],
                onChanged: (text) => model.query = text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
