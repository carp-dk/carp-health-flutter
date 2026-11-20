/// The icon of a data type or category, set in its category's expressive shape and colours, so that a
/// category looks the same in the type picker, the data point tiles and the data point sheet.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:health_example/core/health/health_type_info.dart';
import 'package:health_example/core/health/type_category.dart';
import 'package:health_example/design/design.dart';

/// The expressive shape and container colours that stand for a [TypeCategory].
extension TypeCategoryVisuals on TypeCategory {
  /// The shape behind the icons of this category and its types.
  ExpressiveShape get shape => switch (this) {
    TypeCategory.activity => ExpressiveShape.sunny,
    TypeCategory.body => ExpressiveShape.cookie4,
    TypeCategory.vitals => ExpressiveShape.cookie9,
    TypeCategory.sleep => ExpressiveShape.oval,
    TypeCategory.nutrition => ExpressiveShape.cookie12,
    TypeCategory.mindfulness => ExpressiveShape.flower,
    TypeCategory.cycle => ExpressiveShape.clover4,
    TypeCategory.workouts => ExpressiveShape.softBurst,
    TypeCategory.mobility => ExpressiveShape.pentagon,
    TypeCategory.hearing => ExpressiveShape.cookie6,
    TypeCategory.environment => ExpressiveShape.verySunny,
    TypeCategory.symptoms => ExpressiveShape.puffy,
    TypeCategory.characteristics => ExpressiveShape.cookie7,
    TypeCategory.other => ExpressiveShape.clover8,
  };

  /// The container colour of this category in [scheme] and the colour of icons on it: the same calm
  /// secondary container for every category, so the shapes, not colours, tell categories apart.
  (Color background, Color foreground) colorsIn(ColorScheme scheme) =>
      (scheme.secondaryContainer, scheme.onSecondaryContainer);
}

/// A [ShapedIcon] for a data type ([TypeIcon.new]) or for a whole category ([TypeIcon.category]), in
/// the category's shape and colours ([TypeCategoryVisuals]).
class TypeIcon extends StatelessWidget {
  /// The icon of [type] (`HealthDataTypeInfo.icon`) in the shape and colours of its category.
  TypeIcon({super.key, required HealthDataType type, this.size = 40}) : icon = type.icon, category = type.category;

  /// The icon of [category] itself, for category headers.
  TypeIcon.category({super.key, required this.category, this.size = 40}) : icon = category.icon;

  /// The icon in the middle of the shape.
  final IconData icon;

  /// The category whose shape and colours the icon takes.
  final TypeCategory category;

  /// The width and height of the shape.
  final double size;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = category.colorsIn(Theme.of(context).colorScheme);
    return ShapedIcon(icon: icon, shape: category.shape, size: size, background: background, foreground: foreground);
  }
}
