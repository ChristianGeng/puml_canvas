import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class EbnfLayout implements DiagramLayout {
  static const _padding = 16.0;
  static const _ruleGap = 28.0;
  static const _labelGap = 6.0;
  static const _entryRadius = 4.0;
  static const _connectorWidth = 8.0;
  static const _altSideGap = 20.0;
  static const _altVerticalGap = 12.0;
  static const _repetitionLoopGap = 14.0;
  static const _terminalPadX = 8.0;
  static const _terminalPadY = 4.0;
  static const _nonTerminalPadX = 10.0;
  static const _nonTerminalPadY = 6.0;
  static const _emptyWidth = 40.0;
  static const _fallbackLineHeight = 16.0;

  static const _labelStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );
  static const _terminalStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
    fontFamily: 'monospace',
  );
  static const _nonTerminalStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
  );
  static const _commentStyle = TextStyle(
    color: Color(0xFF4B5563),
    fontSize: 12,
    fontStyle: FontStyle.italic,
  );
  static const _fallbackStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
    fontFamily: 'monospace',
  );

  static const _stroke = Color(0xFF111827);
  static const _terminalFill = Color(0xFFFFFFFF);
  static const _nonTerminalFill = Color(0xFFE5E7EB);
  static const _trackStroke = Color(0xFF111827);

  const EbnfLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! EbnfDiagram) {
      throw ArgumentError('EbnfLayout expects EbnfDiagram');
    }

    final shapes = <SceneShape>[];
    var cursorY = _padding;
    var contentWidth = 0.0;
    var emitted = false;

    for (final rule in diagram.rules) {
      final laid = _layoutRule(rule, measurer, _padding, cursorY);
      shapes.addAll(laid.shapes);
      cursorY += laid.size.height + _ruleGap;
      contentWidth = math.max(contentWidth, laid.size.width);
      emitted = true;
    }

    if (diagram.text.isNotEmpty) {
      final fallback = _layoutFallback(diagram.text, measurer, _padding, cursorY);
      shapes.addAll(fallback.shapes);
      cursorY += fallback.size.height + _ruleGap;
      contentWidth = math.max(contentWidth, fallback.size.width);
      emitted = true;
    }

    if (emitted) {
      cursorY -= _ruleGap;
    }

    final totalWidth = emitted ? contentWidth + _padding * 2 : 0.0;
    final totalHeight = emitted ? cursorY + _padding : 0.0;

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

  _LaidOut _layoutRule(
    EbnfRule rule,
    TextMeasurer measurer,
    double originX,
    double originY,
  ) {
    final shapes = <SceneShape>[];
    final labelSize = measurer.measure(rule.name, _labelStyle);
    shapes.add(SceneText(
      offset: Offset(originX, originY),
      text: rule.name,
      textStyle: _labelStyle,
    ));

    final trackTop = originY + labelSize.height + _labelGap;
    final exprLayout = _layoutExpr(rule.expression, measurer);
    final exprX = originX + _entryRadius * 2 + _connectorWidth;
    final exprY = trackTop;

    final centerY = exprY + exprLayout.centerY;
    final entryCenter = Offset(originX + _entryRadius, centerY);
    final exitCenter = Offset(
      exprX + exprLayout.width + _connectorWidth + _entryRadius,
      centerY,
    );

    shapes.add(SceneCircle(
      center: entryCenter,
      radius: _entryRadius,
      fill: _stroke,
      stroke: _stroke,
    ));
    shapes.add(SceneLine(
      from: Offset(entryCenter.dx + _entryRadius, centerY),
      to: Offset(exprX + exprLayout.entryX, centerY),
      head: null,
      stroke: _trackStroke,
    ));
    shapes.add(SceneLine(
      from: Offset(exprX + exprLayout.exitX, centerY),
      to: Offset(exitCenter.dx - _entryRadius, centerY),
      head: null,
      stroke: _trackStroke,
    ));
    shapes.add(SceneCircle(
      center: exitCenter,
      radius: _entryRadius,
      fill: _stroke,
      stroke: _stroke,
    ));
    exprLayout.emit(shapes, exprX, exprY);

    final totalWidth = math.max(
      labelSize.width,
      (exitCenter.dx + _entryRadius) - originX,
    );
    final totalHeight = (exprY + exprLayout.height) - originY;
    return _LaidOut(
      shapes: shapes,
      size: Size(totalWidth, totalHeight),
    );
  }

  _LaidOut _layoutFallback(
    String text,
    TextMeasurer measurer,
    double originX,
    double originY,
  ) {
    final lines = text.split('\n');
    final shapes = <SceneShape>[];
    var y = originY;
    var maxWidth = 0.0;
    for (final line in lines) {
      shapes.add(SceneText(
        offset: Offset(originX, y),
        text: line,
        textStyle: _fallbackStyle,
      ));
      final m = measurer.measure(line.isEmpty ? ' ' : line, _fallbackStyle);
      maxWidth = math.max(maxWidth, m.width);
      y += _fallbackLineHeight;
    }
    return _LaidOut(
      shapes: shapes,
      size: Size(maxWidth, y - originY),
    );
  }

  _ExprLayout _layoutExpr(EbnfExpr expr, TextMeasurer measurer) {
    switch (expr) {
      case EbnfTerminal():
        return _layoutTerminal(expr.value, measurer);
      case EbnfNonTerminal():
        return _layoutNonTerminal(expr.name, measurer);
      case EbnfSpecial():
        return _layoutSpecial(expr.text, measurer);
      case EbnfComment():
        return _layoutComment(expr.text, measurer);
      case EbnfGroup():
        return _layoutExpr(expr.inner, measurer);
      case EbnfSequence():
        return _layoutSequence(expr.items, measurer);
      case EbnfAlternation():
        return _layoutAlternation(expr.items, measurer);
      case EbnfOptional():
        return _layoutAlternation(
          [expr.inner, const EbnfEmpty()],
          measurer,
        );
      case EbnfRepetition():
        return _layoutRepetition(expr.inner, measurer);
      case EbnfEmpty():
        return _layoutEmpty();
    }
  }

  _ExprLayout _layoutTerminal(String value, TextMeasurer measurer) {
    final display = '"$value"';
    final textSize = measurer.measure(display, _terminalStyle);
    final width = textSize.width + _terminalPadX * 2;
    final height = textSize.height + _terminalPadY * 2;
    return _ExprLayout(
      width: width,
      height: height,
      centerY: height / 2,
      entryX: 0,
      exitX: width,
      items: [
        _BoxItem(
          x: 0,
          y: 0,
          width: width,
          height: height,
          label: display,
          style: _terminalStyle,
          fill: _terminalFill,
          rounded: false,
        ),
      ],
    );
  }

  _ExprLayout _layoutNonTerminal(String name, TextMeasurer measurer) {
    final textSize = measurer.measure(name, _nonTerminalStyle);
    final width = textSize.width + _nonTerminalPadX * 2;
    final height = textSize.height + _nonTerminalPadY * 2;
    return _ExprLayout(
      width: width,
      height: height,
      centerY: height / 2,
      entryX: 0,
      exitX: width,
      items: [
        _BoxItem(
          x: 0,
          y: 0,
          width: width,
          height: height,
          label: name,
          style: _nonTerminalStyle,
          fill: _nonTerminalFill,
          rounded: true,
        ),
      ],
    );
  }

  _ExprLayout _layoutSpecial(String text, TextMeasurer measurer) {
    return _layoutAnnotated('? $text ?', measurer);
  }

  _ExprLayout _layoutComment(String text, TextMeasurer measurer) {
    return _layoutAnnotated('(* $text *)', measurer);
  }

  _ExprLayout _layoutAnnotated(String display, TextMeasurer measurer) {
    final textSize = measurer.measure(display, _commentStyle);
    final width = textSize.width + _terminalPadX * 2;
    final height = textSize.height + _terminalPadY * 2;
    return _ExprLayout(
      width: width,
      height: height,
      centerY: height / 2,
      entryX: 0,
      exitX: width,
      items: [
        _BoxItem(
          x: 0,
          y: 0,
          width: width,
          height: height,
          label: display,
          style: _commentStyle,
          fill: _terminalFill,
          rounded: false,
        ),
      ],
    );
  }

  _ExprLayout _layoutEmpty() {
    final height = _terminalPadY * 2 + 14;
    final centerY = _terminalPadY + 7;
    return _ExprLayout(
      width: _emptyWidth,
      height: height,
      centerY: centerY,
      entryX: 0,
      exitX: _emptyWidth,
      items: [
        _LineItem(x1: 0, y1: centerY, x2: _emptyWidth, y2: centerY),
      ],
    );
  }

  _ExprLayout _layoutSequence(List<EbnfExpr> items, TextMeasurer measurer) {
    if (items.isEmpty) return _layoutEmpty();
    final children = items.map((c) => _layoutExpr(c, measurer)).toList();
    var maxAbove = 0.0;
    var maxBelow = 0.0;
    for (final c in children) {
      maxAbove = math.max(maxAbove, c.centerY);
      maxBelow = math.max(maxBelow, c.height - c.centerY);
    }
    final centerY = maxAbove;
    final totalHeight = maxAbove + maxBelow;

    final out = <_LayoutItem>[];
    var cursorX = 0.0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final dy = centerY - child.centerY;
      child.collectInto(out, cursorX, dy);
      if (i < children.length - 1) {
        out.add(_LineItem(
          x1: cursorX + child.exitX,
          y1: centerY,
          x2: cursorX + child.width + _connectorWidth,
          y2: centerY,
        ));
      }
      cursorX += child.width;
      if (i < children.length - 1) {
        cursorX += _connectorWidth;
      }
    }
    return _ExprLayout(
      width: cursorX,
      height: totalHeight,
      centerY: centerY,
      entryX: 0,
      exitX: cursorX,
      items: out,
    );
  }

  _ExprLayout _layoutAlternation(List<EbnfExpr> items, TextMeasurer measurer) {
    if (items.isEmpty) return _layoutEmpty();
    if (items.length == 1) return _layoutExpr(items.single, measurer);
    final children = items.map((c) => _layoutExpr(c, measurer)).toList();
    var maxWidth = 0.0;
    for (final c in children) {
      maxWidth = math.max(maxWidth, c.width);
    }
    final innerWidth = maxWidth;
    final totalWidth = innerWidth + _altSideGap * 2;

    final out = <_LayoutItem>[];
    var cursorY = 0.0;
    final branchCenters = <double>[];
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final branchStartX = _altSideGap + (innerWidth - child.width) / 2;
      child.collectInto(out, branchStartX, cursorY);
      final branchCenterY = cursorY + child.centerY;
      branchCenters.add(branchCenterY);
      out.add(_LineItem(
        x1: _altSideGap,
        y1: branchCenterY,
        x2: branchStartX + child.entryX,
        y2: branchCenterY,
      ));
      out.add(_LineItem(
        x1: branchStartX + child.exitX,
        y1: branchCenterY,
        x2: _altSideGap + innerWidth,
        y2: branchCenterY,
      ));
      cursorY += child.height;
      if (i < children.length - 1) {
        cursorY += _altVerticalGap;
      }
    }
    final mainCenterY = branchCenters.first;
    final lastCenterY = branchCenters.last;
    out.add(_LineItem(
      x1: 0,
      y1: mainCenterY,
      x2: _altSideGap,
      y2: mainCenterY,
    ));
    out.add(_LineItem(
      x1: _altSideGap + innerWidth,
      y1: mainCenterY,
      x2: totalWidth,
      y2: mainCenterY,
    ));
    out.add(_LineItem(
      x1: _altSideGap,
      y1: mainCenterY,
      x2: _altSideGap,
      y2: lastCenterY,
    ));
    out.add(_LineItem(
      x1: _altSideGap + innerWidth,
      y1: mainCenterY,
      x2: _altSideGap + innerWidth,
      y2: lastCenterY,
    ));
    return _ExprLayout(
      width: totalWidth,
      height: cursorY,
      centerY: mainCenterY,
      entryX: 0,
      exitX: totalWidth,
      items: out,
    );
  }

  _ExprLayout _layoutRepetition(EbnfExpr inner, TextMeasurer measurer) {
    final child = _layoutExpr(inner, measurer);
    final out = <_LayoutItem>[];
    final loopTop = _repetitionLoopGap;
    final childY = loopTop + _repetitionLoopGap;
    child.collectInto(out, _altSideGap, childY);
    final centerY = childY + child.centerY;
    final innerLeft = _altSideGap;
    final innerRight = _altSideGap + child.width;
    final totalWidth = innerRight + _altSideGap;
    out.add(_LineItem(
      x1: 0,
      y1: centerY,
      x2: innerLeft + child.entryX,
      y2: centerY,
    ));
    out.add(_LineItem(
      x1: innerLeft + child.exitX,
      y1: centerY,
      x2: totalWidth,
      y2: centerY,
    ));
    out.add(_LineItem(
      x1: innerLeft,
      y1: loopTop,
      x2: innerRight,
      y2: loopTop,
    ));
    out.add(_LineItem(
      x1: innerLeft,
      y1: loopTop,
      x2: innerLeft,
      y2: centerY,
    ));
    out.add(_LineItem(
      x1: innerRight,
      y1: loopTop,
      x2: innerRight,
      y2: centerY,
    ));
    final totalHeight = childY + child.height;
    return _ExprLayout(
      width: totalWidth,
      height: totalHeight,
      centerY: centerY,
      entryX: 0,
      exitX: totalWidth,
      items: out,
    );
  }
}

class _LaidOut {
  final List<SceneShape> shapes;
  final Size size;
  const _LaidOut({required this.shapes, required this.size});
}

class _ExprLayout {
  final double width;
  final double height;
  final double centerY;
  final double entryX;
  final double exitX;
  final List<_LayoutItem> items;

  const _ExprLayout({
    required this.width,
    required this.height,
    required this.centerY,
    required this.entryX,
    required this.exitX,
    required this.items,
  });

  void collectInto(List<_LayoutItem> sink, double dx, double dy) {
    for (final item in items) {
      sink.add(item.translated(dx, dy));
    }
  }

  void emit(List<SceneShape> sink, double dx, double dy) {
    for (final item in items) {
      sink.add(item.translated(dx, dy).toScene());
    }
  }
}

abstract class _LayoutItem {
  _LayoutItem translated(double dx, double dy);
  SceneShape toScene();
}

class _BoxItem implements _LayoutItem {
  final double x;
  final double y;
  final double width;
  final double height;
  final String label;
  final TextStyle style;
  final Color fill;
  final bool rounded;

  const _BoxItem({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.label,
    required this.style,
    required this.fill,
    required this.rounded,
  });

  @override
  _BoxItem translated(double dx, double dy) {
    return _BoxItem(
      x: x + dx,
      y: y + dy,
      width: width,
      height: height,
      label: label,
      style: style,
      fill: fill,
      rounded: rounded,
    );
  }

  @override
  SceneShape toScene() {
    final rect = Rect.fromLTWH(x, y, width, height);
    if (rounded) {
      return SceneRoundedBox(
        rect: rect,
        label: label,
        textStyle: style,
        fill: fill,
        stroke: EbnfLayout._stroke,
        cornerRadius: height / 2,
      );
    }
    return SceneBox(
      rect: rect,
      label: label,
      textStyle: style,
      fill: fill,
      stroke: EbnfLayout._stroke,
    );
  }
}

class _LineItem implements _LayoutItem {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const _LineItem({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  @override
  _LineItem translated(double dx, double dy) {
    return _LineItem(
      x1: x1 + dx,
      y1: y1 + dy,
      x2: x2 + dx,
      y2: y2 + dy,
    );
  }

  @override
  SceneShape toScene() {
    return SceneLine(
      from: Offset(x1, y1),
      to: Offset(x2, y2),
      head: null,
      stroke: EbnfLayout._trackStroke,
    );
  }
}
