import 'package:flutter/painting.dart';

/// Returns [style] with [fontFamily] filled in when [style] names no family.
/// A non-empty `fontFamilyFallback` counts as naming one: when `fontFamily`
/// is null, Flutter uses its first entry as the preferred font (see
/// [TextStyle.fontFamilyFallback]). An empty list counts as none.
///
/// The measurer and the renderer both call this, so a diagram is laid out
/// and painted with the same font. A family that a style already names (for
/// example `monospace` for `""text""`) wins over [fontFamily], and a
/// null [fontFamily] returns [style] unchanged.
TextStyle withDefaultFontFamily(TextStyle style, String? fontFamily) {
  if (fontFamily == null ||
      style.fontFamily != null ||
      (style.fontFamilyFallback?.isNotEmpty ?? false)) {
    return style;
  }
  return style.copyWith(fontFamily: fontFamily);
}
