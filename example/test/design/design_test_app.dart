/// Test harness for the design components: a widget on a page with the app's expressive theme.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_example/design/design.dart';

/// [child] centred on a page with the light expressive theme (or [theme]).
Widget designTestApp(Widget child, {ThemeData? theme, Widget? floatingActionButton}) => MaterialApp(
  theme: theme ?? ExpressiveTheme.light(),
  home: Scaffold(
    body: Center(child: child),
    floatingActionButton: floatingActionButton,
  ),
);

/// The shape of the nearest `Material` around the widget [finder] finds: the segment, card or button
/// that draws it.
ShapeBorder? materialShapeAround(Finder finder) =>
    (find.ancestor(of: finder, matching: find.byType(Material)).evaluate().first.widget as Material).shape;
