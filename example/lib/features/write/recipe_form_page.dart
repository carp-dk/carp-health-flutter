/// The page of one write recipe: its header and its form, which makes the plugin call.
library;

import 'package:flutter/material.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/design/design.dart';

import 'widgets/recipe_header.dart';
import 'write_recipe.dart';

/// Opens [recipe]'s [RecipeFormPage] over the current page.
Future<void> openRecipe(BuildContext context, WriteRecipe recipe) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => RecipeFormPage(recipe: recipe)));

/// A recipe's page: a large title, a [RecipeHeader] (main method, whether this device can make the write,
/// and the description behind an info button) and the recipe's form ([WriteRecipe.builder]).
///
/// The form is shown also where the recipe is not available, so its fields still document the method's
/// arguments; the forms of platform-specific methods replace their write button with the reason. The
/// page's `Scaffold` carries the snack bar each write reports its result in.
class RecipeFormPage extends StatelessWidget {
  /// Creates the page of [recipe].
  const RecipeFormPage({super.key, required this.recipe});

  /// The recipe shown.
  final WriteRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final capabilities = AppScope.of(context).capabilities;
    return ExpressivePage(
      title: recipe.title,
      slivers: [
        SliverToBoxAdapter(
          // Health Connect's features are checked after the app starts: the status follows them.
          child: ListenableBuilder(
            listenable: capabilities,
            builder: (context, _) => RecipeHeader(recipe: recipe, capabilities: capabilities),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 16),
          sliver: SliverToBoxAdapter(child: Builder(builder: recipe.builder)),
        ),
      ],
    );
  }
}
