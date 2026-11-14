import 'package:flutter/painting.dart';

import '../text/font_family.dart';
import '../text/inline_markup.dart';

abstract class TextMeasurer {
  Size measure(String text, TextStyle style);
}

class FlutterTextMeasurer implements TextMeasurer {
  /// Font family used for text whose style names none.
  ///
  /// Null (the default) keeps the platform's default font. Pass the same
  /// value to `Renderer.fontFamily` so the painted text fits the boxes the
  /// layout sized for it.
  final String? fontFamily;

  const FlutterTextMeasurer({this.fontFamily});

  @override
  Size measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: parseInlineMarkup(text, withDefaultFontFamily(style, fontFamily)),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.size;
  }
}
