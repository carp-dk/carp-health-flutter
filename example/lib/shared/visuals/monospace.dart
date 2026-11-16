/// The monospace text the app shows code names, ids, error codes and JSON in.
library;

import 'package:flutter/painting.dart';

/// A monospace variant of a [TextStyle] that works on both platforms.
extension MonospaceTextStyle on TextStyle {
  /// This style in a monospace font. Android maps the generic family `monospace` to its monospace
  /// font; iOS has no font of that name, so Menlo (and Courier after it) stand in.
  TextStyle get monospace => copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Menlo', 'Courier']);
}
