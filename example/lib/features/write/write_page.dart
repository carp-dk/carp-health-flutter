/// Write: every write method of the plugin, quick sample data, recent writes and deletion.
///
/// * Sample data: a set of writes of many types, each with its result (`writeHealthData`,
///   `writeHealthDataUUID`, `writeWorkoutData`, `writeSleepSession`, ...).
/// * Recent writes: shown near the top as soon as anything is written in this session, tappable to
///   inspect (`getHealthDataByUUID`) or delete (`deleteByUUID` / `deleteByClientRecordId`).
/// * Write data: an expressive category-coloured card grid — one form per method family
///   ([WriteRecipes]), opened on [RecipeFormPage]. Platform-specific methods stay visible with a badge.
/// * Delete data: accessible from both the app bar and a compact destructive card ([DeletePage]).
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/app/app_scope.dart';
import 'package:health_example/core/health/platform_capabilities.dart';
import 'package:health_example/design/design.dart';
import 'package:health_example/shared/visuals/type_icon.dart';

import 'delete/delete_page.dart';
import 'recent/recent_writes_controller.dart';
import 'recent/recent_writes_list.dart';
import 'recipe_form_page.dart';
import 'sample_data/sample_data_controller.dart';
import 'sample_data/sample_data_section.dart';
import 'write_recipe.dart';
import 'write_recipes.dart';

/// The Write destination: quick sample data, recent writes, expressive write grid, and delete shortcut.
///
/// The page owns the sample data's and the recent writes' controllers; the app shell keeps the page
/// alive, so a sample run goes on while the user looks elsewhere.
class WritePage extends StatefulWidget {
  /// Creates the Write page.
  const WritePage({super.key});

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  late final AppServices _services;
  late final SampleDataController _sampleData;
  late final RecentWritesController _recent;

  @override
  void initState() {
    super.initState();
    // AppScope.of registers no dependency, so it may be called here.
    final services = _services = AppScope.of(context);
    _sampleData = SampleDataController(
      health: services.health,
      capabilities: services.capabilities,
      recentWrites: services.recentWrites,
    );
    _recent = RecentWritesController(
      health: services.health,
      capabilities: services.capabilities,
      recentWrites: services.recentWrites,
    );
  }

  @override
  void dispose() {
    _sampleData.dispose();
    _recent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = _services.capabilities;
    return ExpressivePage(
      title: 'Write',
      actions: [
        IconButton(
          tooltip: 'Delete data',
          onPressed: () => openDeletePage(context),
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(child: SampleDataSection(controller: _sampleData)),
        SliverToBoxAdapter(child: RecentWritesList(controller: _recent)),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: SectionHeader(title: 'Write data'),
          ),
        ),
        SliverToBoxAdapter(
          // The recipes' availability follows the Health Connect features, read after the app starts.
          child: ListenableBuilder(
            listenable: capabilities,
            builder: (context, _) => _RecipeGrid(capabilities: capabilities),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          sliver: SliverToBoxAdapter(child: _DeleteCard(onTap: () => openDeletePage(context))),
        ),
      ],
    );
  }
}

/// Responsive expressive grid of every [WriteRecipe]: 2 columns on phones, 3 on tablets, 4 on desktop.
class _RecipeGrid extends StatelessWidget {
  const _RecipeGrid({required this.capabilities});

  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final recipes = WriteRecipes.all;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780
            ? 4
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            for (var i = 0; i < recipes.length; i += columns)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    for (var col = 0; col < columns; col++)
                      Expanded(
                        child: i + col < recipes.length
                            ? _RecipeCard(recipe: recipes[i + col], capabilities: capabilities)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One write method card: its category-coloured shaped icon, title, platform badge and unavailability note.
class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.capabilities});

  final WriteRecipe recipe;
  final PlatformCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reason = recipe.unavailableReason(capabilities);
    final available = reason == null;
    final (categoryBg, categoryFg) = recipe.category.colorsIn(scheme);
    final badge = switch (recipe.onlyOn) {
      HealthPlatformType.appleHealth => const PlatformBadge.ios(),
      HealthPlatformType.googleHealthConnect => const PlatformBadge.android(),
      null => null,
    };
    return ExpressiveCard(
      variant: available ? ExpressiveCardVariant.filled : ExpressiveCardVariant.outlined,
      padding: const EdgeInsets.all(14),
      // The form also opens where the method is unavailable: its fields still document the arguments.
      onTap: () => openRecipe(context, recipe),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              ShapedIcon(
                icon: recipe.icon,
                shape: recipe.shape,
                size: 38,
                background: available ? categoryBg : scheme.surfaceContainerHighest,
                foreground: available ? categoryFg : scheme.outline,
              ),
              if (badge != null)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: FittedBox(fit: BoxFit.scaleDown, child: badge),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmallEmphasized.copyWith(
                  color: available ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
              if (reason != null)
                Text(
                  reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall!.copyWith(color: scheme.outline),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact destructive shortcut card to the Delete page.
class _DeleteCard extends StatelessWidget {
  const _DeleteCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        spacing: 14,
        children: [
          ShapedIcon(
            icon: Icons.delete_sweep_outlined,
            shape: ExpressiveShape.puffy,
            size: 40,
            background: scheme.errorContainer,
            foreground: scheme.onErrorContainer,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delete data', style: theme.textTheme.titleSmallEmphasized),
                Text(
                  'By type, time, or client id',
                  style: theme.textTheme.bodySmall!.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
