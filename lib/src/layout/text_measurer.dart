import 'package:flutter/painting.dart';

import '../text/inline_markup.dart';

abstract class TextMeasurer {
  Size measure(String text, TextStyle style);
}

class FlutterTextMeasurer implements TextMeasurer {
  const FlutterTextMeasurer();

  @override
  Size measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: parseInlineMarkup(text, style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.size;
  }
}
