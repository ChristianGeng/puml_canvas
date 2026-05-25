import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import '../layout/scene.dart';
import '../text/inline_markup.dart';

class Renderer {
  static const _arrowHeadLength = 10.0;
  static const _arrowHeadAngle = 0.5;
  static const _dashOn = 6.0;
  static const _dashOff = 4.0;

  const Renderer();

  void render(Canvas canvas, Scene scene) {
    final bg = scene.background;
    if (bg != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, scene.size.width, scene.size.height),
        Paint()
          ..color = bg
          ..style = PaintingStyle.fill,
      );
    }
    for (final shape in scene.shapes) {
      switch (shape) {
        case SceneBox():
          _drawBox(canvas, shape);
        case SceneLine():
          _drawLine(canvas, shape);
        case SceneNote():
          _drawNote(canvas, shape);
        case SceneText():
          _drawText(canvas, shape);
        case SceneSymbol():
          _drawSymbol(canvas, shape);
        case SceneEllipse():
          _drawEllipse(canvas, shape);
        case SceneDiamond():
          _drawDiamond(canvas, shape);
        case SceneCircle():
          _drawCircle(canvas, shape);
        case SceneRoundedBox():
          _drawRoundedBox(canvas, shape);
        case SceneCrowFoot():
          _drawCrowFoot(canvas, shape);
      }
    }
  }

  void _drawCrowFoot(Canvas canvas, SceneCrowFoot c) {
    final paint = Paint()
      ..color = c.stroke
      ..strokeWidth = c.strokeWidth
      ..style = PaintingStyle.stroke;
    final p = c.position;
    final a = c.angle;
    final cosA = math.cos(a);
    final sinA = math.sin(a);
    final perpCos = math.cos(a + math.pi / 2);
    final perpSin = math.sin(a + math.pi / 2);
    const tickOffset = 8.0;
    const tickHalf = 5.0;
    const circleOffset = 14.0;
    const circleRadius = 3.5;
    const crowLength = 9.0;
    const crowSpread = 0.7;

    void drawPerpTick(double along) {
      final cx = p.dx + cosA * along;
      final cy = p.dy + sinA * along;
      canvas.drawLine(
        Offset(cx + perpCos * tickHalf, cy + perpSin * tickHalf),
        Offset(cx - perpCos * tickHalf, cy - perpSin * tickHalf),
        paint,
      );
    }

    void drawCircle(double along) {
      final cx = p.dx + cosA * along;
      final cy = p.dy + sinA * along;
      final fillPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), circleRadius, fillPaint);
      canvas.drawCircle(Offset(cx, cy), circleRadius, paint);
    }

    void drawCrow() {
      final tip1x = p.dx + math.cos(a + crowSpread) * crowLength;
      final tip1y = p.dy + math.sin(a + crowSpread) * crowLength;
      final tip2x = p.dx + math.cos(a - crowSpread) * crowLength;
      final tip2y = p.dy + math.sin(a - crowSpread) * crowLength;
      final tip3x = p.dx + cosA * crowLength;
      final tip3y = p.dy + sinA * crowLength;
      canvas.drawLine(p, Offset(tip1x, tip1y), paint);
      canvas.drawLine(p, Offset(tip2x, tip2y), paint);
      canvas.drawLine(p, Offset(tip3x, tip3y), paint);
    }

    switch (c.kind) {
      case CrowFoot.one:
        drawPerpTick(tickOffset);
      case CrowFoot.zeroOrOne:
        drawPerpTick(tickOffset);
        drawCircle(circleOffset);
      case CrowFoot.zeroOrMany:
        drawCircle(circleOffset);
        drawCrow();
      case CrowFoot.oneOrMany:
        drawPerpTick(tickOffset);
        drawCrow();
    }
  }

  void _drawDiamond(Canvas canvas, SceneDiamond d) {
    final r = d.rect;
    final path = Path()
      ..moveTo(r.center.dx, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.center.dx, r.bottom)
      ..lineTo(r.left, r.center.dy)
      ..close();
    if (d.fill.a > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = d.fill
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = d.stroke
        ..strokeWidth = d.strokeWidth
        ..style = PaintingStyle.stroke,
    );
    final label = d.label;
    if (label != null && label.isNotEmpty) {
      final painter = TextPainter(
        text: parseInlineMarkup(label, d.textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: r.width);
      painter.paint(
        canvas,
        Offset(
          r.center.dx - painter.width / 2,
          r.center.dy - painter.height / 2,
        ),
      );
    }
  }

  void _drawCircle(Canvas canvas, SceneCircle c) {
    if (c.ring) {
      canvas.drawCircle(
        c.center,
        c.radius,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        c.center,
        c.radius,
        Paint()
          ..color = c.stroke
          ..strokeWidth = c.strokeWidth
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
        c.center,
        c.radius * 0.55,
        Paint()
          ..color = c.fill
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawCircle(
        c.center,
        c.radius,
        Paint()
          ..color = c.fill
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        c.center,
        c.radius,
        Paint()
          ..color = c.stroke
          ..strokeWidth = c.strokeWidth
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawRoundedBox(Canvas canvas, SceneRoundedBox b) {
    final rrect = RRect.fromRectAndRadius(b.rect, Radius.circular(b.cornerRadius));
    if (b.fill.a > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = b.fill
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = b.stroke
        ..strokeWidth = b.strokeWidth
        ..style = PaintingStyle.stroke,
    );
    final label = b.label;
    if (label != null && label.isNotEmpty) {
      final painter = TextPainter(
        text: parseInlineMarkup(label, b.textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: b.rect.width);
      painter.paint(
        canvas,
        Offset(
          b.rect.center.dx - painter.width / 2,
          b.rect.center.dy - painter.height / 2,
        ),
      );
    }
  }

  void _drawSymbol(Canvas canvas, SceneSymbol symbol) {
    switch (symbol.kind) {
      case ParticipantKind.participant:
        _drawSymbolRect(canvas, symbol);
      case ParticipantKind.actor:
        _drawActor(canvas, symbol);
      case ParticipantKind.boundary:
        _drawBoundary(canvas, symbol);
      case ParticipantKind.control:
        _drawControl(canvas, symbol);
      case ParticipantKind.entity:
        _drawEntity(canvas, symbol);
      case ParticipantKind.database:
        _drawDatabase(canvas, symbol);
      case ParticipantKind.collections:
        _drawCollections(canvas, symbol);
      case ParticipantKind.queue:
        _drawQueue(canvas, symbol);
    }
  }

  Paint _fillPaint(SceneSymbol s) => Paint()
    ..color = s.fill
    ..style = PaintingStyle.fill;

  Paint _strokePaint(SceneSymbol s) => Paint()
    ..color = s.stroke
    ..strokeWidth = s.strokeWidth
    ..style = PaintingStyle.stroke;

  void _paintLabel(Canvas canvas, SceneSymbol s, Rect labelRect,
      {double maxWidth = double.infinity}) {
    final painter = TextPainter(
      text: parseInlineMarkup(s.label, s.labelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      Offset(
        labelRect.center.dx - painter.width / 2,
        labelRect.center.dy - painter.height / 2,
      ),
    );
  }

  void _drawSymbolRect(Canvas canvas, SceneSymbol s) {
    canvas.drawRect(s.rect, _fillPaint(s));
    canvas.drawRect(s.rect, _strokePaint(s));
    _paintLabel(canvas, s, s.rect);
  }

  void _drawActor(Canvas canvas, SceneSymbol s) {
    final r = s.rect;
    final labelHeight = _measureLabelHeight(s);
    final iconBottom = r.bottom - labelHeight;
    final iconTop = r.top + 2;
    final iconHeight = iconBottom - iconTop;
    final cx = r.center.dx;
    final headRadius = math.min(iconHeight * 0.18, r.width * 0.18);
    final headCenter = Offset(cx, iconTop + headRadius);

    final fill = _fillPaint(s);
    final stroke = _strokePaint(s);

    canvas.drawCircle(headCenter, headRadius, fill);
    canvas.drawCircle(headCenter, headRadius, stroke);

    final bodyTop = headCenter.dy + headRadius;
    final bodyBottom = iconTop + iconHeight * 0.75;
    canvas.drawLine(Offset(cx, bodyTop), Offset(cx, bodyBottom), stroke);

    final armY = bodyTop + (bodyBottom - bodyTop) * 0.25;
    final armSpan = math.min(iconHeight * 0.28, r.width * 0.4);
    canvas.drawLine(
        Offset(cx - armSpan, armY), Offset(cx + armSpan, armY), stroke);

    final legSpan = math.min(iconHeight * 0.28, r.width * 0.4);
    canvas.drawLine(Offset(cx, bodyBottom),
        Offset(cx - legSpan, iconBottom - 1), stroke);
    canvas.drawLine(Offset(cx, bodyBottom),
        Offset(cx + legSpan, iconBottom - 1), stroke);

    _paintLabel(
        canvas, s, Rect.fromLTRB(r.left, iconBottom, r.right, r.bottom),
        maxWidth: r.width);
  }

  void _drawBoundary(Canvas canvas, SceneSymbol s) {
    final r = s.rect;
    final labelHeight = _measureLabelHeight(s);
    final iconBottom = r.bottom - labelHeight;
    final iconTop = r.top + 2;
    final iconHeight = iconBottom - iconTop;
    final radius = math.min(iconHeight * 0.4, 10.0);
    final cx = r.center.dx;
    final cy = iconTop + iconHeight / 2;

    final fill = _fillPaint(s);
    final stroke = _strokePaint(s);

    final circleCenter = Offset(cx + radius / 2, cy);
    canvas.drawCircle(circleCenter, radius, fill);
    canvas.drawCircle(circleCenter, radius, stroke);

    final tickX = cx - radius;
    canvas.drawLine(Offset(tickX, cy - radius),
        Offset(tickX, cy + radius), stroke);
    canvas.drawLine(
        Offset(tickX, cy), Offset(circleCenter.dx - radius, cy), stroke);

    _paintLabel(
        canvas, s, Rect.fromLTRB(r.left, iconBottom, r.right, r.bottom),
        maxWidth: r.width);
  }

  void _drawControl(Canvas canvas, SceneSymbol s) {
    final r = s.rect;
    final labelHeight = _measureLabelHeight(s);
    final iconBottom = r.bottom - labelHeight;
    final iconTop = r.top + 2;
    final iconHeight = iconBottom - iconTop;
    final radius = math.min(iconHeight * 0.4, 10.0);
    final cx = r.center.dx;
    final cy = iconTop + iconHeight / 2 + 2;

    final fill = _fillPaint(s);
    final stroke = _strokePaint(s);

    canvas.drawCircle(Offset(cx, cy), radius, fill);
    canvas.drawCircle(Offset(cx, cy), radius, stroke);

    final tipX = cx;
    final tipY = cy - radius;
    canvas.drawLine(Offset(tipX - 3, tipY - 3), Offset(tipX, tipY), stroke);
    canvas.drawLine(Offset(tipX - 3, tipY + 3), Offset(tipX, tipY), stroke);

    _paintLabel(
        canvas, s, Rect.fromLTRB(r.left, iconBottom, r.right, r.bottom),
        maxWidth: r.width);
  }

  void _drawEntity(Canvas canvas, SceneSymbol s) {
    final r = s.rect;
    final labelHeight = _measureLabelHeight(s);
    final iconBottom = r.bottom - labelHeight;
    final iconTop = r.top + 2;
    final iconHeight = iconBottom - iconTop;
    final radius = math.min((iconHeight - 4) * 0.5, 10.0);
    final cx = r.center.dx;
    final cy = iconTop + radius;

    final fill = _fillPaint(s);
    final stroke = _strokePaint(s);

    canvas.drawCircle(Offset(cx, cy), radius, fill);
    canvas.drawCircle(Offset(cx, cy), radius, stroke);

    final underlineY = cy + radius + 2;
    canvas.drawLine(Offset(cx - radius, underlineY),
        Offset(cx + radius, underlineY), stroke);

    _paintLabel(
        canvas, s, Rect.fromLTRB(r.left, iconBottom, r.right, r.bottom),
        maxWidth: r.width);
  }

  void _drawDatabase(Canvas canvas, SceneSymbol s) {
    final r = s.rect;
    const capHeight = 12.0;
    final fill = _fillPaint(s);
    final stroke = _strokePaint(s);

    final body = Rect.fromLTRB(
        r.left, r.top + capHeight / 2, r.right, r.bottom - capHeight / 2);
    canvas.drawRect(body, fill);

    canvas.drawLine(Offset(body.left, body.top),
        Offset(body.left, body.bottom), stroke);
    canvas.drawLine(Offset(body.right, body.top),
        Offset(body.right, body.bottom), stroke);

    final topOval = Rect.fromLTRB(
        r.left, r.top, r.right, r.top + capHeight);
    final bottomOval = Rect.fromLTRB(
        r.left, r.bottom - capHeight, r.right, r.bottom);

    canvas.drawOval(bottomOval, fill);
    canvas.drawOval(bottomOval, stroke);
    canvas.drawOval(topOval, fill);
    canvas.drawOval(topOval, stroke);

    _paintLabel(canvas, s, body, maxWidth: r.width);
  }

  void _drawCollections(Canvas canvas, SceneSymbol s) {
    final r = s.rect;
    const offset = 6.0;
    final fill = _fillPaint(s);
    final stroke = _strokePaint(s);

    final back = Rect.fromLTRB(
        r.left + offset, r.top, r.right, r.bottom - offset);
    final front = Rect.fromLTRB(
        r.left, r.top + offset, r.right - offset, r.bottom);

    canvas.drawRect(back, fill);
    canvas.drawRect(back, stroke);
    canvas.drawRect(front, fill);
    canvas.drawRect(front, stroke);

    _paintLabel(canvas, s, front, maxWidth: front.width);
  }

  void _drawQueue(Canvas canvas, SceneSymbol s) {
    final r = s.rect;
    final capWidth = math.min(8.0, r.width / 4);
    final fill = _fillPaint(s);
    final stroke = _strokePaint(s);

    final body =
        Rect.fromLTRB(r.left + capWidth / 2, r.top, r.right - capWidth / 2, r.bottom);
    canvas.drawRect(body, fill);

    canvas.drawLine(Offset(body.left, body.top),
        Offset(body.right, body.top), stroke);
    canvas.drawLine(Offset(body.left, body.bottom),
        Offset(body.right, body.bottom), stroke);

    final leftCap = Rect.fromLTRB(
        r.left, r.top, r.left + capWidth, r.bottom);
    final rightCap = Rect.fromLTRB(
        r.right - capWidth, r.top, r.right, r.bottom);

    canvas.drawOval(leftCap, fill);
    canvas.drawOval(leftCap, stroke);
    canvas.drawOval(rightCap, fill);
    canvas.drawOval(rightCap, stroke);

    _paintLabel(canvas, s, body, maxWidth: body.width);
  }

  double _measureLabelHeight(SceneSymbol s) {
    final painter = TextPainter(
      text: parseInlineMarkup(s.label, s.labelStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: s.rect.width);
    return painter.height;
  }

  void _drawText(Canvas canvas, SceneText text) {
    final painter = TextPainter(
      text: parseInlineMarkup(text.text, text.textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: text.maxWidth);
    painter.paint(canvas, text.offset);
  }

  void _drawNote(Canvas canvas, SceneNote note) {
    final r = note.rect;
    final fold = note.foldSize.clamp(0.0, math.min(r.width, r.height) / 2);

    final path = Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.right - fold, r.top)
      ..lineTo(r.right, r.top + fold)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = note.fill
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = note.stroke
        ..strokeWidth = note.strokeWidth
        ..style = PaintingStyle.stroke,
    );

    final foldPath = Path()
      ..moveTo(r.right - fold, r.top)
      ..lineTo(r.right - fold, r.top + fold)
      ..lineTo(r.right, r.top + fold);
    canvas.drawPath(
      foldPath,
      Paint()
        ..color = note.stroke
        ..strokeWidth = note.strokeWidth
        ..style = PaintingStyle.stroke,
    );

    final painter = TextPainter(
      text: parseInlineMarkup(note.text, note.textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r.width);
    painter.paint(
      canvas,
      Offset(
        r.center.dx - painter.width / 2,
        r.center.dy - painter.height / 2,
      ),
    );
  }

  void _drawBox(Canvas canvas, SceneBox box) {
    if (box.fill.a > 0) {
      final fillPaint = Paint()
        ..color = box.fill
        ..style = PaintingStyle.fill;
      canvas.drawRect(box.rect, fillPaint);
    }
    final strokePaint = Paint()
      ..color = box.stroke
      ..strokeWidth = box.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRect(box.rect, strokePaint);

    final label = box.label;
    if (label != null && label.isNotEmpty) {
      final painter = TextPainter(
        text: parseInlineMarkup(label, box.textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final offset = Offset(
        box.rect.center.dx - painter.width / 2,
        box.rect.center.dy - painter.height / 2,
      );
      painter.paint(canvas, offset);
    }
  }

  void _drawEllipse(Canvas canvas, SceneEllipse ellipse) {
    if (ellipse.fill.a > 0) {
      final fillPaint = Paint()
        ..color = ellipse.fill
        ..style = PaintingStyle.fill;
      canvas.drawOval(ellipse.rect, fillPaint);
    }
    final strokePaint = Paint()
      ..color = ellipse.stroke
      ..strokeWidth = ellipse.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawOval(ellipse.rect, strokePaint);

    if (ellipse.label.isNotEmpty) {
      final painter = TextPainter(
        text: parseInlineMarkup(ellipse.label, ellipse.textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: ellipse.rect.width);
      painter.paint(
        canvas,
        Offset(
          ellipse.rect.center.dx - painter.width / 2,
          ellipse.rect.center.dy - painter.height / 2,
        ),
      );
    }
  }

  void _drawLine(Canvas canvas, SceneLine line) {
    final paint = Paint()
      ..color = line.stroke
      ..strokeWidth = line.strokeWidth
      ..style = PaintingStyle.stroke;

    if (line.dashed) {
      _drawDashedLine(canvas, line.from, line.to, paint);
    } else {
      canvas.drawLine(line.from, line.to, paint);
    }

    final head = line.head;
    if (head != null) {
      final tip = line.headAtFrom ? line.from : line.to;
      final tail = line.headAtFrom ? line.to : line.from;
      _drawHead(canvas, tail, tip, paint, head);
    }

    final label = line.label;
    final style = line.labelStyle;
    if (label != null && label.isNotEmpty && style != null) {
      final painter = TextPainter(
        text: parseInlineMarkup(label, style),
        textDirection: TextDirection.ltr,
      )..layout();
      final midX = (line.from.dx + line.to.dx) / 2;
      final y = math.min(line.from.dy, line.to.dy) - painter.height - 2;
      painter.paint(canvas, Offset(midX - painter.width / 2, y));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    var traveled = 0.0;
    var on = true;
    while (traveled < dist) {
      final segLen = on ? _dashOn : _dashOff;
      final next = math.min(traveled + segLen, dist);
      if (on) {
        canvas.drawLine(
          Offset(a.dx + ux * traveled, a.dy + uy * traveled),
          Offset(a.dx + ux * next, a.dy + uy * next),
          paint,
        );
      }
      traveled = next;
      on = !on;
    }
  }

  void _drawHead(
      Canvas canvas, Offset from, Offset to, Paint paint, ArrowHead head) {
    switch (head) {
      case ArrowHead.filled:
        _drawFilledTriangleHead(canvas, from, to, paint);
      case ArrowHead.open:
        _drawOpenVHead(canvas, from, to, paint);
      case ArrowHead.openCircle:
        _drawOpenCircleHead(canvas, to, paint);
      case ArrowHead.cross:
        _drawCrossHead(canvas, from, to, paint);
      case ArrowHead.triangle:
        _drawHollowTriangleHead(canvas, from, to, paint);
      case ArrowHead.filledDiamond:
        _drawDiamondHead(canvas, from, to, paint, filled: true);
      case ArrowHead.hollowDiamond:
        _drawDiamondHead(canvas, from, to, paint, filled: false);
      case ArrowHead.square:
        _drawSquareHead(canvas, from, to, paint);
      case ArrowHead.bracket:
        _drawBracketHead(canvas, from, to, paint);
      case ArrowHead.plus:
        _drawPlusHead(canvas, from, to, paint);
      case ArrowHead.caret:
        _drawCaretHead(canvas, from, to, paint);
    }
  }

  void _drawSquareHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const half = _arrowSquareSide / 2;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final cx = to.dx - half * math.cos(angle);
    final cy = to.dy - half * math.sin(angle);
    final perp = angle + math.pi / 2;
    final ax = half * math.cos(angle);
    final ay = half * math.sin(angle);
    final px = half * math.cos(perp);
    final py = half * math.sin(perp);
    final p1 = Offset(cx - ax - px, cy - ay - py);
    final p2 = Offset(cx + ax - px, cy + ay - py);
    final p3 = Offset(cx + ax + px, cy + ay + py);
    final p4 = Offset(cx - ax + px, cy - ay + py);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();
    final stroke = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, stroke);
  }

  void _drawBracketHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    // Bracket opens AWAY from the arrow direction: spine perpendicular to the
    // line at the tip, two short prongs extending back toward the tail.
    const halfTall = _arrowBracketTall / 2;
    const deep = _arrowBracketDeep;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final perp = angle + math.pi / 2;
    final spineTop = Offset(
      to.dx + halfTall * math.cos(perp),
      to.dy + halfTall * math.sin(perp),
    );
    final spineBot = Offset(
      to.dx - halfTall * math.cos(perp),
      to.dy - halfTall * math.sin(perp),
    );
    final prongTop = Offset(
      spineTop.dx - deep * math.cos(angle),
      spineTop.dy - deep * math.sin(angle),
    );
    final prongBot = Offset(
      spineBot.dx - deep * math.cos(angle),
      spineBot.dy - deep * math.sin(angle),
    );
    canvas.drawLine(spineTop, spineBot, paint);
    canvas.drawLine(spineTop, prongTop, paint);
    canvas.drawLine(spineBot, prongBot, paint);
  }

  void _drawPlusHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    const half = _arrowPlusLength / 2;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final perp = angle + math.pi / 2;
    final cx = to.dx - half * math.cos(angle);
    final cy = to.dy - half * math.sin(angle);
    final ax = half * math.cos(angle);
    final ay = half * math.sin(angle);
    final px = half * math.cos(perp);
    final py = half * math.sin(perp);
    canvas.drawLine(
      Offset(cx - ax, cy - ay),
      Offset(cx + ax, cy + ay),
      paint,
    );
    canvas.drawLine(
      Offset(cx - px, cy - py),
      Offset(cx + px, cy + py),
      paint,
    );
  }

  void _drawCaretHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    // Vertex sits at the tip; legs splay back along the arrow.
    const leg = _arrowCaretLeg;
    const halfAngle = _arrowCaretHalfAngle;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final back = angle + math.pi;
    final p1 = Offset(
      to.dx + leg * math.cos(back - halfAngle),
      to.dy + leg * math.sin(back - halfAngle),
    );
    final p2 = Offset(
      to.dx + leg * math.cos(back + halfAngle),
      to.dy + leg * math.sin(back + halfAngle),
    );
    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  void _drawHollowTriangleHead(
      Canvas canvas, Offset from, Offset to, Paint paint) {
    final length = _arrowHeadLength + 4;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final p1 = Offset(
      to.dx - length * math.cos(angle - _arrowHeadAngle),
      to.dy - length * math.sin(angle - _arrowHeadAngle),
    );
    final p2 = Offset(
      to.dx - length * math.cos(angle + _arrowHeadAngle),
      to.dy - length * math.sin(angle + _arrowHeadAngle),
    );
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    final fill = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
    final stroke = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, stroke);
  }

  void _drawDiamondHead(
      Canvas canvas, Offset from, Offset to, Paint paint,
      {required bool filled}) {
    final length = _arrowHeadLength + 2;
    final halfWidth = 5.0;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final tip = to;
    final baseCenter = Offset(
      to.dx - length * math.cos(angle),
      to.dy - length * math.sin(angle),
    );
    final tail = Offset(
      to.dx - 2 * length * math.cos(angle),
      to.dy - 2 * length * math.sin(angle),
    );
    final perp = angle + math.pi / 2;
    final p1 = Offset(
      baseCenter.dx + halfWidth * math.cos(perp),
      baseCenter.dy + halfWidth * math.sin(perp),
    );
    final p2 = Offset(
      baseCenter.dx - halfWidth * math.cos(perp),
      baseCenter.dy - halfWidth * math.sin(perp),
    );
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    final fillColor = filled ? paint.color : const Color(0xFFFFFFFF);
    final fill = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
    final stroke = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, stroke);
  }

  void _drawOpenVHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final p1 = Offset(
      to.dx - _arrowHeadLength * math.cos(angle - _arrowHeadAngle),
      to.dy - _arrowHeadLength * math.sin(angle - _arrowHeadAngle),
    );
    final p2 = Offset(
      to.dx - _arrowHeadLength * math.cos(angle + _arrowHeadAngle),
      to.dy - _arrowHeadLength * math.sin(angle + _arrowHeadAngle),
    );
    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  void _drawFilledTriangleHead(
      Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final p1 = Offset(
      to.dx - _arrowHeadLength * math.cos(angle - _arrowHeadAngle),
      to.dy - _arrowHeadLength * math.sin(angle - _arrowHeadAngle),
    );
    final p2 = Offset(
      to.dx - _arrowHeadLength * math.cos(angle + _arrowHeadAngle),
      to.dy - _arrowHeadLength * math.sin(angle + _arrowHeadAngle),
    );
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    final fill = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);
  }

  void _drawOpenCircleHead(Canvas canvas, Offset to, Paint paint) {
    final fill = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(to, _arrowCircleRadius, fill);
  }

  void _drawCrossHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const half = _arrowCrossLength / 2;
    final perp = angle + math.pi / 2;
    final dx = half * math.cos(angle);
    final dy = half * math.sin(angle);
    final px = half * math.cos(perp);
    final py = half * math.sin(perp);
    final a1 = Offset(to.dx - dx - px, to.dy - dy - py);
    final a2 = Offset(to.dx + dx + px, to.dy + dy + py);
    final b1 = Offset(to.dx - dx + px, to.dy - dy + py);
    final b2 = Offset(to.dx + dx - px, to.dy + dy - py);
    canvas.drawLine(a1, a2, paint);
    canvas.drawLine(b1, b2, paint);
  }

  static const _arrowCircleRadius = 4.0;
  static const _arrowCrossLength = 8.0;
  static const _arrowSquareSide = 8.0;
  static const _arrowBracketTall = 10.0;
  static const _arrowBracketDeep = 6.0;
  static const _arrowPlusLength = 10.0;
  static const _arrowCaretLeg = 8.0;
  static const _arrowCaretHalfAngle = math.pi / 6; // 60-degree opening
}
