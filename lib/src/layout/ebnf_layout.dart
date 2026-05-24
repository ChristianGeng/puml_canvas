import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class EbnfLayout implements DiagramLayout {
  static const _padding = 16.0;
  static const _innerPadding = 12.0;
  static const _lineHeight = 16.0;

  static const _bodyStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
    fontFamily: 'monospace',
  );

  static const _stroke = Color(0xFF374151);
  static const _fill = Color(0xFFF9FAFB);

  const EbnfLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! EbnfDiagram) {
      throw ArgumentError('EbnfLayout expects EbnfDiagram');
    }
    final lines = diagram.text.split('\n');
    var maxWidth = 0.0;
    for (final line in lines) {
      final size = measurer.measure(line.isEmpty ? ' ' : line, _bodyStyle);
      if (size.width > maxWidth) maxWidth = size.width;
    }
    final bodyHeight = lines.length * _lineHeight;
    final boxWidth = maxWidth + _innerPadding * 2;
    final boxHeight = bodyHeight + _innerPadding * 2;
    final totalWidth = boxWidth + _padding * 2;
    final totalHeight = boxHeight + _padding * 2;

    final shapes = <SceneShape>[
      SceneBox(
        rect: Rect.fromLTWH(_padding, _padding, boxWidth, boxHeight),
        textStyle: _bodyStyle,
        fill: _fill,
        stroke: _stroke,
      ),
    ];
    var y = _padding + _innerPadding;
    for (final line in lines) {
      shapes.add(SceneText(
        offset: Offset(_padding + _innerPadding, y),
        text: line,
        textStyle: _bodyStyle,
      ));
      y += _lineHeight;
    }

    return wrapWithDecorations(
      Scene(
        size: Size(totalWidth, totalHeight),
        shapes: shapes,
        background: diagram.decorations.skin.backgroundColor,
      ),
      diagram.decorations,
      measurer,
    );
  }
}
