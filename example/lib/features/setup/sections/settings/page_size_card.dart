/// The page size of the plugin's reads, `Health.pageSize`, on a slider with presets.
library;

import 'package:flutter/material.dart';
import 'package:health_example/core/format/formatters.dart';
import 'package:health_example/core/settings/plugin_settings.dart';
import 'package:health_example/design/design.dart';

import '../../models/page_size_scale.dart';
import '../../widgets/card_heading.dart';

/// The current page size as a big number, a slider over [PageSizeScale.stops] (1 to 50,000 on a
/// logarithmic 1-2-5 scale) and the presets of [PluginSettings.pageSizePresets] as chips; what the size
/// changes on this platform ([isIOS]) sits behind the info button. Every change applies to
/// `Health.pageSize` at once, for reads started afterwards.
class PageSizeCard extends StatelessWidget {
  /// Creates the card that edits [settings].
  const PageSizeCard({super.key, required this.settings, required this.isIOS});

  /// The plugin's read settings.
  final PluginSettings settings;

  /// Whether the plugin reads HealthKit, where the size costs no quota, rather than Health Connect.
  final bool isIOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pageSize = settings.pageSize;
    final last = PageSizeScale.stops.length - 1;
    const motion = ExpressiveMotion.spatialFast;
    return ExpressiveCard(
      variant: ExpressiveCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardHeading(
            icon: ShapedIcon(
              icon: Icons.layers,
              shape: ExpressiveShape.cookie12,
              size: 44,
              background: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
            ),
            title: 'Page size',
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 8,
            children: [
              // The number springs in whenever it changes, so dragging the slider feels physical.
              AnimatedSwitcher(
                duration: motion.duration,
                switchInCurve: motion,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation.drive(Tween<double>(begin: 0.85, end: 1)),
                  alignment: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
                  child: FadeTransition(opacity: animation.drive(ExpressiveMotion.clampToUnit), child: child),
                ),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                child: Text(
                  formatNumber(pageSize),
                  key: ValueKey(pageSize),
                  style: theme.textTheme.displaySmallEmphasized.tabular,
                ),
              ),
              Flexible(child: Text('points / call', style: theme.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: PageSizeScale.indexOf(pageSize).toDouble(),
            max: last.toDouble(),
            divisions: last,
            label: PageSizeScale.compact(pageSize),
            semanticFormatterCallback: (position) => '${formatNumber(PageSizeScale.valueAt(position.round()))} points',
            onChanged: (position) => settings.pageSize = PageSizeScale.valueAt(position.round()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in PluginSettings.pageSizePresets)
                ChoiceChip(
                  // The colour shows the choice; without the check mark the four presets fit one phone row.
                  showCheckmark: false,
                  label: Text(PageSizeScale.presetLabel(preset)),
                  selected: preset == pageSize,
                  onSelected: (_) => settings.pageSize = preset,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
