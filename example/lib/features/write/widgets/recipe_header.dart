/// The top of a recipe's form page: its main plugin method and whether this device can make the write.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/monospace.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import '../write_recipe.dart';

/// [recipe]'s icon in its category's shape and colours, its main plugin method, and its status on the
/// device [capabilities] describes: available, or why not, with the `PlatformBadge` of a one-platform
/// recipe.
///
/// An `InfoButton` holds the rest: every method, the data types, on Android the Health Connect feature
/// check the recipe needs and what it returned, and the recipe's description.
class RecipeHeader extends StatelessWidget {
  /// Creates the header of [recipe].
  const RecipeHeader({super.key, required this.recipe, required this.capabilities});

  /// The recipe.
  final WriteRecipe recipe;

  /// The platform and its Health Connect features.
  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = recipe.category.colorsIn(scheme);
    final reason = recipe.unavailableReason(capabilities);
    final badge = _badge();
    return ExpressiveCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            spacing: 12,
            children: [
              ShapedIcon(
                icon: recipe.icon,
                shape: recipe.shape,
                size: 40,
                background: background,
                foreground: foreground,
              ),
              Expanded(
                child: Text(
                  recipe.methods.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge!.copyWith(color: scheme.primary).monospace,
                ),
              ),
              ?badge,
              InfoButton(title: recipe.title, code: _code(), message: recipe.description),
            ],
          ),
          if (reason != null) StatusPill(label: reason, tone: StatusTone.warning, icon: Icons.block),
        ],
      ),
    );
  }

  /// The badge of the one platform that has the recipe's methods.
  Widget? _badge() => switch (recipe.onlyOn) {
    HealthPlatformType.appleHealth => const PlatformBadge.ios(),
    HealthPlatformType.googleHealthConnect => const PlatformBadge.android(),
    null => null,
  };

  /// The info sheet's code: the methods, the types and, on Android, the feature check and its result.
  String _code() {
    final feature = recipe.feature;
    return [
      recipe.methods.join('\n'),
      if (recipe.types.isNotEmpty) recipe.types.map((type) => type.name).join(' · '),
      if (feature != null && capabilities.isAndroid) '${feature.check}: ${feature.availableIn(capabilities)}',
    ].join('\n\n');
  }
}
