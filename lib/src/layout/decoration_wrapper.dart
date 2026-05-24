import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'scene.dart';
import 'text_measurer.dart';

const double _padding = 16.0;
const double _titleGap = 8.0;
const double _headerGap = 6.0;
const double _footerGap = 6.0;
const double _captionGap = 6.0;
const double _legendGap = 8.0;
const double _legendPaddingX = 8.0;
const double _legendPaddingY = 6.0;

const TextStyle _titleStyle = TextStyle(
    color: Color(0xFF000000), fontSize: 16, fontWeight: FontWeight.bold);
const TextStyle _headerFooterStyle =
    TextStyle(color: Color(0xFF808080), fontSize: 10);
const TextStyle _captionStyle = TextStyle(
    color: Color(0xFF505050), fontSize: 11, fontStyle: FontStyle.italic);
const TextStyle _legendStyle =
    TextStyle(color: Color(0xFF000000), fontSize: 11);
const Color _legendFill = Color(0x11000000);
const Color _legendStroke = Color(0xFFB0B0B0);

Scene wrapWithDecorations(
    Scene innerScene, DiagramDecorations dec, TextMeasurer measurer) {
  final hasAny = dec.title != null ||
      dec.caption != null ||
      dec.header != null ||
      dec.footer != null ||
      dec.legend != null;
  if (!hasAny) {
    if (dec.skin.backgroundColor == null ||
        innerScene.background == dec.skin.backgroundColor) {
      return innerScene;
    }
    return Scene(
      size: innerScene.size,
      shapes: innerScene.shapes,
      background: dec.skin.backgroundColor ?? innerScene.background,
    );
  }

  final fontSize = dec.skin.defaultFontSize;
  final headerFooterStyle = fontSize == null
      ? _headerFooterStyle
      : _headerFooterStyle.copyWith(fontSize: fontSize);
  final captionStyle = fontSize == null
      ? _captionStyle
      : _captionStyle.copyWith(fontSize: fontSize);
  final legendStyle = fontSize == null
      ? _legendStyle
      : _legendStyle.copyWith(fontSize: fontSize);

  final headerSize = dec.header != null
      ? _measureMultiline(dec.header!.text, headerFooterStyle, measurer)
      : Size.zero;
  final titleSize = dec.title != null
      ? _measureMultiline(dec.title!, _titleStyle, measurer)
      : Size.zero;
  final captionSize = dec.caption != null
      ? _measureMultiline(dec.caption!, captionStyle, measurer)
      : Size.zero;
  final footerSize = dec.footer != null
      ? _measureMultiline(dec.footer!.text, headerFooterStyle, measurer)
      : Size.zero;
  final legendTextSize = dec.legend != null
      ? _measureMultiline(dec.legend!.text, legendStyle, measurer)
      : Size.zero;
  final legendBoxSize = dec.legend != null
      ? Size(legendTextSize.width + _legendPaddingX * 2,
          legendTextSize.height + _legendPaddingY * 2)
      : Size.zero;

  final topDecorationHeight =
      (dec.header != null ? headerSize.height + _headerGap : 0.0) +
          (dec.title != null ? titleSize.height + _titleGap : 0.0);
  final bottomDecorationHeight =
      (dec.legend != null ? legendBoxSize.height + _legendGap : 0.0) +
          (dec.caption != null ? captionSize.height + _captionGap : 0.0) +
          (dec.footer != null ? footerSize.height + _footerGap : 0.0);

  final decorationWidth = math.max(
    math.max(
      math.max(headerSize.width, footerSize.width),
      math.max(titleSize.width, captionSize.width),
    ),
    legendBoxSize.width,
  );

  final innerWidth = innerScene.size.width;
  final innerHeight = innerScene.size.height;
  final totalWidth =
      math.max(innerWidth, decorationWidth + _padding * 2);
  final innerOffsetX = 0.0;
  final shiftY = topDecorationHeight;
  final shiftedInnerBottom = shiftY + innerHeight;
  // The inner scene is assumed to include a trailing `_padding` margin. We
  // overlay bottom decorations on top of that margin so total height grows
  // only by the decoration heights themselves.
  final bottomBase = shiftedInnerBottom - _padding;
  final totalHeight = shiftedInnerBottom + bottomDecorationHeight;

  final shapes = <SceneShape>[];

  if (dec.header != null) {
    shapes.add(SceneText(
      offset: Offset(
        _alignX(totalWidth, headerSize.width, dec.header!.align),
        _padding,
      ),
      text: dec.header!.text,
      textStyle: headerFooterStyle,
    ));
  }
  if (dec.title != null) {
    final titleY = (dec.header != null
            ? _padding + headerSize.height + _headerGap
            : _padding);
    shapes.add(SceneText(
      offset: Offset(
        (totalWidth - titleSize.width) / 2,
        titleY,
      ),
      text: dec.title!,
      textStyle: _titleStyle,
    ));
  }

  for (final shape in innerScene.shapes) {
    shapes.add(_translate(shape, innerOffsetX, shiftY));
  }

  if (dec.legend != null) {
    final legendLeft =
        _alignX(totalWidth, legendBoxSize.width, dec.legend!.align);
    final legendTop = bottomBase + _legendGap;
    shapes.add(SceneBox(
      rect: Rect.fromLTWH(
          legendLeft, legendTop, legendBoxSize.width, legendBoxSize.height),
      fill: _legendFill,
      stroke: _legendStroke,
      textStyle: legendStyle,
    ));
    shapes.add(SceneText(
      offset: Offset(
        legendLeft + _legendPaddingX,
        legendTop + _legendPaddingY,
      ),
      text: dec.legend!.text,
      textStyle: legendStyle,
    ));
  }
  final afterLegendY = dec.legend != null
      ? bottomBase + _legendGap + legendBoxSize.height
      : bottomBase;
  if (dec.caption != null) {
    shapes.add(SceneText(
      offset: Offset(
        (totalWidth - captionSize.width) / 2,
        afterLegendY + _captionGap,
      ),
      text: dec.caption!,
      textStyle: captionStyle,
    ));
  }
  if (dec.footer != null) {
    final footerY = afterLegendY +
        (dec.caption != null ? captionSize.height + _captionGap : 0.0) +
        _footerGap;
    shapes.add(SceneText(
      offset: Offset(
        _alignX(totalWidth, footerSize.width, dec.footer!.align),
        footerY,
      ),
      text: dec.footer!.text,
      textStyle: headerFooterStyle,
    ));
  }

  return Scene(
    size: Size(totalWidth, totalHeight),
    shapes: shapes,
    background: dec.skin.backgroundColor ?? innerScene.background,
  );
}

double _alignX(double totalWidth, double textWidth, TextAlign align) {
  switch (align) {
    case TextAlign.left:
    case TextAlign.start:
      return _padding;
    case TextAlign.right:
    case TextAlign.end:
      return totalWidth - _padding - textWidth;
    case TextAlign.center:
    case TextAlign.justify:
      return (totalWidth - textWidth) / 2;
  }
}

Size _measureMultiline(String text, TextStyle style, TextMeasurer measurer) {
  if (!text.contains('\n')) {
    return measurer.measure(text, style);
  }
  final lines = text.split('\n');
  var maxWidth = 0.0;
  var totalHeight = 0.0;
  for (final line in lines) {
    final size = measurer.measure(line.isEmpty ? ' ' : line, style);
    if (size.width > maxWidth) maxWidth = size.width;
    totalHeight += size.height;
  }
  return Size(maxWidth, totalHeight);
}

SceneShape _translate(SceneShape shape, double dx, double dy) {
  if (dx == 0 && dy == 0) return shape;
  switch (shape) {
    case SceneBox():
      return SceneBox(
        rect: shape.rect.shift(Offset(dx, dy)),
        label: shape.label,
        textStyle: shape.textStyle,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
      );
    case SceneNote():
      return SceneNote(
        rect: shape.rect.shift(Offset(dx, dy)),
        text: shape.text,
        textStyle: shape.textStyle,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
        foldSize: shape.foldSize,
      );
    case SceneText():
      return SceneText(
        offset: shape.offset.translate(dx, dy),
        text: shape.text,
        textStyle: shape.textStyle,
        maxWidth: shape.maxWidth,
      );
    case SceneSymbol():
      return SceneSymbol(
        rect: shape.rect.shift(Offset(dx, dy)),
        label: shape.label,
        labelStyle: shape.labelStyle,
        kind: shape.kind,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
      );
    case SceneEllipse():
      return SceneEllipse(
        rect: shape.rect.shift(Offset(dx, dy)),
        label: shape.label,
        textStyle: shape.textStyle,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
      );
    case SceneDiamond():
      return SceneDiamond(
        rect: shape.rect.shift(Offset(dx, dy)),
        label: shape.label,
        textStyle: shape.textStyle,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
      );
    case SceneCircle():
      return SceneCircle(
        center: shape.center.translate(dx, dy),
        radius: shape.radius,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
        ring: shape.ring,
      );
    case SceneRoundedBox():
      return SceneRoundedBox(
        rect: shape.rect.shift(Offset(dx, dy)),
        label: shape.label,
        textStyle: shape.textStyle,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
        cornerRadius: shape.cornerRadius,
      );
    case SceneCrowFoot():
      return SceneCrowFoot(
        position: shape.position.translate(dx, dy),
        angle: shape.angle,
        kind: shape.kind,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
      );
    case SceneLine():
      return SceneLine(
        from: shape.from.translate(dx, dy),
        to: shape.to.translate(dx, dy),
        dashed: shape.dashed,
        head: shape.head,
        headAtFrom: shape.headAtFrom,
        label: shape.label,
        labelStyle: shape.labelStyle,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
      );
  }
}
