import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class UseCaseLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _actorWidth = 80.0;
  static const _actorIconHeight = 50.0;
  static const _actorVGap = 24.0;
  static const _actorToUseCaseGap = 60.0;
  static const _useCasePaddingX = 18.0;
  static const _useCasePaddingY = 12.0;
  static const _useCaseMinWidth = 100.0;
  static const _useCaseMinHeight = 44.0;
  static const _useCaseHGap = 40.0;
  static const _useCaseVGap = 24.0;
  static const _boundaryPadding = 16.0;
  static const _boundaryLabelGap = 6.0;
  static const _boundaryGap = 24.0;

  static const _actorStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
  );
  static const _useCaseStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
  );
  static const _boundaryStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _relationLabelStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 10,
  );

  static const _actorFill = Color(0xFFFFFFFF);
  static const _actorStroke = Color(0xFF000000);
  static const _useCaseFill = Color(0xFFFFFFCC);
  static const _useCaseStroke = Color(0xFF000000);
  static const _boundaryFill = Color(0x00000000);
  static const _boundaryStroke = Color(0xFF606060);

  static const _noteFill = Color(0xFFFEF9C3);
  static const _noteStroke = Color(0xFF000000);
  static const _notePaddingX = 8.0;
  static const _notePaddingY = 6.0;
  static const _noteMinWidth = 60.0;
  static const _noteMinHeight = 24.0;
  static const _noteGap = 16.0;
  static const _noteStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
  );

  const UseCaseLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! UseCaseDiagram) {
      throw ArgumentError('UseCaseLayout expects UseCaseDiagram');
    }
    if (diagram.nodes.isEmpty) {
      return wrapWithDecorations(
        Scene(
          size: Size.zero,
          shapes: const [],
          background: diagram.decorations.skin.backgroundColor,
        ),
        diagram.decorations,
        measurer,
      );
    }

    final nodeByAlias = <String, UseCaseNode>{
      for (final n in diagram.nodes) n.alias: n,
    };

    final actors = <UseCaseNode>[];
    final freeUseCases = <UseCaseNode>[];
    final boundaryUseCases = <String, List<UseCaseNode>>{};
    final inBoundary = <String>{};
    for (final b in diagram.boundaries) {
      final list = <UseCaseNode>[];
      for (final alias in b.containedAliases) {
        final node = nodeByAlias[alias];
        if (node == null) continue;
        list.add(node);
        inBoundary.add(alias);
      }
      boundaryUseCases[_boundaryKey(b)] = list;
    }
    for (final n in diagram.nodes) {
      if (n.kind == UseCaseNodeKind.actor) {
        actors.add(n);
      } else if (!inBoundary.contains(n.alias)) {
        freeUseCases.add(n);
      }
    }

    final useCaseRects = <String, Rect>{};
    final actorRects = <String, Rect>{};

    final actorsX = _padding;
    var actorsY = _padding;
    for (final a in actors) {
      final labelSize = measurer.measure(a.label, _actorStyle);
      final h = _actorIconHeight + labelSize.height + 4;
      final w = math.max(_actorWidth, labelSize.width + 8);
      actorRects[a.alias] = Rect.fromLTWH(actorsX, actorsY, w, h);
      actorsY += h + _actorVGap;
    }
    final actorsBottom = actorsY - _actorVGap;
    final actorsRight = actors.isEmpty
        ? _padding
        : actorRects.values
                .map((r) => r.right)
                .fold<double>(0, math.max);

    final ucBlocksStartX = actorsRight + _actorToUseCaseGap;
    var blockY = _padding;
    var diagramRight = ucBlocksStartX;

    final boundaryRects = <int, Rect>{};
    for (var bi = 0; bi < diagram.boundaries.length; bi++) {
      final boundary = diagram.boundaries[bi];
      final ucs = boundaryUseCases[_boundaryKey(boundary)] ?? const [];
      if (ucs.isEmpty) continue;
      final labelSize = boundary.label == null
          ? Size.zero
          : measurer.measure(boundary.label!, _boundaryStyle);
      final layoutResult = _gridLayoutUseCases(
        ucs,
        measurer,
        originX: ucBlocksStartX + _boundaryPadding,
        originY: blockY +
            _boundaryPadding +
            (boundary.label != null
                ? labelSize.height + _boundaryLabelGap
                : 0),
      );
      for (final entry in layoutResult.rects.entries) {
        useCaseRects[entry.key] = entry.value;
      }
      final innerWidth = math.max(
        layoutResult.width,
        labelSize.width,
      );
      final boundaryRect = Rect.fromLTWH(
        ucBlocksStartX,
        blockY,
        innerWidth + _boundaryPadding * 2,
        layoutResult.height +
            _boundaryPadding * 2 +
            (boundary.label != null
                ? labelSize.height + _boundaryLabelGap
                : 0),
      );
      boundaryRects[bi] = boundaryRect;
      if (boundaryRect.right > diagramRight) diagramRight = boundaryRect.right;
      blockY = boundaryRect.bottom + _boundaryGap;
    }

    if (freeUseCases.isNotEmpty) {
      final layoutResult = _gridLayoutUseCases(
        freeUseCases,
        measurer,
        originX: ucBlocksStartX,
        originY: blockY,
      );
      for (final entry in layoutResult.rects.entries) {
        useCaseRects[entry.key] = entry.value;
      }
      if (ucBlocksStartX + layoutResult.width > diagramRight) {
        diagramRight = ucBlocksStartX + layoutResult.width;
      }
      blockY += layoutResult.height + _useCaseVGap;
    }

    // Lay out notes. Attached notes (`note right of X`) sit immediately
    // adjacent to their target on the chosen side; free-standing notes
    // (`note "..." as N`) are placed in a column to the right of the rest
    // of the diagram so the dotted connector lines can reach them cleanly.
    final noteRects = <String, Rect>{};
    final noteSizes = <String, Size>{};
    for (final n in diagram.notes) {
      noteSizes[n.alias] = _measureNote(n.text, measurer);
    }

    var notesRight = math.max(diagramRight, actorsRight);
    for (final n in diagram.notes) {
      if (n.position == null || n.attachedTo == null) continue;
      final targetRect =
          actorRects[n.attachedTo] ?? useCaseRects[n.attachedTo];
      if (targetRect == null) continue;
      final size = noteSizes[n.alias]!;
      double left;
      double top;
      switch (n.position!) {
        case NotePosition.leftOf:
          left = targetRect.left - _noteGap - size.width;
          top = targetRect.top + (targetRect.height - size.height) / 2;
          break;
        case NotePosition.rightOf:
          left = targetRect.right + _noteGap;
          top = targetRect.top + (targetRect.height - size.height) / 2;
          break;
        case NotePosition.over:
          left = targetRect.center.dx - size.width / 2;
          top = targetRect.top - _noteGap - size.height;
          break;
      }
      final rect = Rect.fromLTWH(left, top, size.width, size.height);
      noteRects[n.alias] = rect;
      if (rect.right > notesRight) notesRight = rect.right;
    }

    // Free-standing notes: stack them vertically in a column placed to the
    // right of the diagram. The column anchors at the actor padding so the
    // notes sit in a predictable spot regardless of the use-case layout.
    final freeNotesX = notesRight + _noteGap;
    var freeNotesY = _padding;
    for (final n in diagram.notes) {
      if (n.position != null || n.attachedTo != null) continue;
      final size = noteSizes[n.alias]!;
      final rect = Rect.fromLTWH(freeNotesX, freeNotesY, size.width, size.height);
      noteRects[n.alias] = rect;
      freeNotesY = rect.bottom + _noteGap;
      if (rect.right > notesRight) notesRight = rect.right;
    }

    final notesBottom = noteRects.values.fold<double>(
        0, (acc, r) => math.max(acc, r.bottom));

    final height =
        math.max(math.max(actorsBottom, blockY), notesBottom) + _padding;
    final width = math.max(notesRight, math.max(diagramRight, actorsRight)) +
        _padding;

    final shapes = <SceneShape>[];

    for (final entry in boundaryRects.entries) {
      final boundary = diagram.boundaries[entry.key];
      final rect = entry.value;
      shapes.add(SceneBox(
        rect: rect,
        fill: _boundaryFill,
        stroke: _boundaryStroke,
        textStyle: _boundaryStyle,
      ));
      if (boundary.label != null) {
        shapes.add(SceneText(
          offset: Offset(
            rect.left + _boundaryPadding,
            rect.top + _boundaryPadding / 2,
          ),
          text: boundary.label!,
          textStyle: _boundaryStyle,
        ));
      }
    }

    for (final a in actors) {
      final rect = actorRects[a.alias]!;
      shapes.add(SceneSymbol(
        rect: rect,
        label: a.label,
        labelStyle: _actorStyle,
        kind: ParticipantKind.actor,
        fill: _actorFill,
        stroke: _actorStroke,
      ));
    }

    for (final n in diagram.nodes) {
      if (n.kind != UseCaseNodeKind.useCase) continue;
      final rect = useCaseRects[n.alias];
      if (rect == null) continue;
      final spans = n.labelSpans;
      if (spans == null || spans.isEmpty) {
        shapes.add(SceneEllipse(
          rect: rect,
          label: n.label,
          textStyle: _useCaseStyle,
          fill: _useCaseFill,
          stroke: _useCaseStroke,
        ));
      } else {
        _emitSectionedUseCase(shapes, rect, spans, measurer);
      }
    }

    for (final r in diagram.relations) {
      final fromCenter = _centerOf(r.from, actorRects, useCaseRects);
      final toCenter = _centerOf(r.to, actorRects, useCaseRects);
      if (fromCenter == null || toCenter == null) continue;
      final fromPoint = _edgeOf(
        r.from,
        actorRects,
        useCaseRects,
        toCenter,
      );
      final toPoint = _edgeOf(
        r.to,
        actorRects,
        useCaseRects,
        fromCenter,
      );
      // Inline `#color;line.bold|dashed|dotted;text:color` modifiers (parsed
      // off `--> (target) #...`) override the arrow's default visuals. We
      // approximate `dotted` with the same dashed stroke as `dashed` because
      // SceneLine does not yet distinguish dot from dash patterns.
      final inline = r.inlineLineStyle;
      final dashed = inline == UseCaseLineStyle.dashed ||
          inline == UseCaseLineStyle.dotted ||
          (inline == null && r.lineStyle == LineStyle.dashed);
      final strokeWidth = inline == UseCaseLineStyle.bold ? 2.0 : 1.0;
      final stroke = r.lineColor ?? const Color(0xFF000000);
      final labelStyle = r.label == null
          ? null
          : (r.textColor == null
              ? _relationLabelStyle
              : _relationLabelStyle.copyWith(color: r.textColor));
      shapes.add(SceneLine(
        from: fromPoint,
        to: toPoint,
        dashed: dashed,
        head: r.head,
        headAtFrom: false,
        label: r.label,
        labelStyle: labelStyle,
        stroke: stroke,
        strokeWidth: strokeWidth,
      ));
    }

    // Note boxes (drawn on top of relation lines but under their text).
    for (final n in diagram.notes) {
      final rect = noteRects[n.alias];
      if (rect == null) continue;
      shapes.add(SceneNote(
        rect: rect,
        text: n.text,
        textStyle: _noteStyle,
        fill: _noteFill,
        stroke: _noteStroke,
      ));
    }

    // Dotted connector lines between free-standing notes and their
    // associated nodes / notes. PlantUML draws these without arrowheads.
    for (final c in diagram.noteConnections) {
      final from = _edgeOfAny(c.from, actorRects, useCaseRects, noteRects,
          _centerOfAny(c.to, actorRects, useCaseRects, noteRects));
      final to = _edgeOfAny(c.to, actorRects, useCaseRects, noteRects,
          _centerOfAny(c.from, actorRects, useCaseRects, noteRects));
      if (from == null || to == null) continue;
      shapes.add(SceneLine(
        from: from,
        to: to,
        dashed: true,
        head: null,
        stroke: const Color(0xFF000000),
        strokeWidth: 1.0,
      ));
    }

    return wrapWithDecorations(
      Scene(
        size: Size(width, height),
        shapes: shapes,
        background: diagram.decorations.skin.backgroundColor,
      ),
      diagram.decorations,
      measurer,
    );
  }

  String _boundaryKey(UseCaseBoundary b) =>
      '${b.label ?? ''}|${b.containedAliases.join(',')}';

  Offset? _centerOf(
    String alias,
    Map<String, Rect> actorRects,
    Map<String, Rect> useCaseRects,
  ) {
    return actorRects[alias]?.center ?? useCaseRects[alias]?.center;
  }

  /// Centre lookup that also considers note rectangles. Used when routing
  /// dotted connector lines between use-case nodes and free-standing notes.
  Offset? _centerOfAny(
    String alias,
    Map<String, Rect> actorRects,
    Map<String, Rect> useCaseRects,
    Map<String, Rect> noteRects,
  ) {
    return actorRects[alias]?.center ??
        useCaseRects[alias]?.center ??
        noteRects[alias]?.center;
  }

  /// Edge-point lookup that resolves a connection endpoint to either an
  /// actor symbol, a use-case ellipse, or a note rectangle. Falls back to
  /// the rectangle edge for unknown shapes.
  Offset? _edgeOfAny(
    String alias,
    Map<String, Rect> actorRects,
    Map<String, Rect> useCaseRects,
    Map<String, Rect> noteRects,
    Offset? toward,
  ) {
    if (toward == null) return null;
    final actorRect = actorRects[alias];
    if (actorRect != null) return _rectEdge(actorRect, toward);
    final ucRect = useCaseRects[alias];
    if (ucRect != null) return _ellipseEdge(ucRect, toward);
    final noteRect = noteRects[alias];
    if (noteRect != null) return _rectEdge(noteRect, toward);
    return null;
  }

  /// Returns the rendered footprint of a note rectangle for the given text.
  Size _measureNote(String text, TextMeasurer measurer) {
    final size = measurer.measure(text, _noteStyle);
    final w = math.max(_noteMinWidth, size.width + _notePaddingX * 2);
    final h = math.max(_noteMinHeight, size.height + _notePaddingY * 2);
    return Size(w, h);
  }

  Offset _edgeOf(
    String alias,
    Map<String, Rect> actorRects,
    Map<String, Rect> useCaseRects,
    Offset toward,
  ) {
    final actorRect = actorRects[alias];
    if (actorRect != null) {
      return _rectEdge(actorRect, toward);
    }
    final ucRect = useCaseRects[alias]!;
    return _ellipseEdge(ucRect, toward);
  }

  Offset _rectEdge(Rect rect, Offset toward) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final dx = toward.dx - cx;
    final dy = toward.dy - cy;
    if (dx == 0 && dy == 0) return rect.center;
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final tx = dx == 0 ? double.infinity : halfW / dx.abs();
    final ty = dy == 0 ? double.infinity : halfH / dy.abs();
    final t = math.min(tx, ty);
    return Offset(cx + dx * t, cy + dy * t);
  }

  Offset _ellipseEdge(Rect rect, Offset toward) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final dx = toward.dx - cx;
    final dy = toward.dy - cy;
    if (dx == 0 && dy == 0) return rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    if (rx == 0 || ry == 0) return rect.center;
    final t = 1.0 /
        math.sqrt((dx * dx) / (rx * rx) + (dy * dy) / (ry * ry));
    return Offset(cx + dx * t, cy + dy * t);
  }

  _GridLayoutResult _gridLayoutUseCases(
    List<UseCaseNode> ucs,
    TextMeasurer measurer, {
    required double originX,
    required double originY,
  }) {
    final cols = math.max(1, math.min(ucs.length, _gridCols(ucs.length)));
    final colWidths = List<double>.filled(cols, _useCaseMinWidth);
    final sizes = <String, Size>{};
    for (final uc in ucs) {
      final size = _measureUseCase(uc, measurer);
      sizes[uc.alias] = size;
    }
    for (var i = 0; i < ucs.length; i++) {
      final col = i % cols;
      final w = sizes[ucs[i].alias]!.width;
      if (w > colWidths[col]) colWidths[col] = w;
    }
    final rects = <String, Rect>{};
    var y = originY;
    var rowMaxBottom = originY;
    for (var i = 0; i < ucs.length; i++) {
      final col = i % cols;
      var x = originX;
      for (var c = 0; c < col; c++) {
        x += colWidths[c] + _useCaseHGap;
      }
      final size = sizes[ucs[i].alias]!;
      final w = colWidths[col];
      final h = size.height;
      final rect = Rect.fromLTWH(x, y, w, h);
      rects[ucs[i].alias] = rect;
      if (rect.bottom > rowMaxBottom) rowMaxBottom = rect.bottom;
      if (col == cols - 1 || i == ucs.length - 1) {
        y = rowMaxBottom + _useCaseVGap;
        rowMaxBottom = y;
      }
    }
    var totalWidth = 0.0;
    for (var c = 0; c < cols; c++) {
      totalWidth += colWidths[c];
      if (c < cols - 1) totalWidth += _useCaseHGap;
    }
    final totalHeight = (y - _useCaseVGap) - originY;
    return _GridLayoutResult(
      rects: rects,
      width: totalWidth,
      height: totalHeight,
    );
  }

  int _gridCols(int count) {
    if (count <= 3) return 1;
    if (count <= 8) return 2;
    return 3;
  }

  /// Paints a use-case ellipse whose label is split by `--`/`==`/`..text..`
  /// section markers. The ellipse itself is drawn with no embedded label,
  /// and each text segment + separator is stacked vertically inside the
  /// inscribed rectangle (≈ 70% of the ellipse's bounding box).
  void _emitSectionedUseCase(
    List<SceneShape> shapes,
    Rect rect,
    List<UseCaseLabelSpan> spans,
    TextMeasurer measurer,
  ) {
    shapes.add(SceneEllipse(
      rect: rect,
      label: '',
      textStyle: _useCaseStyle,
      fill: _useCaseFill,
      stroke: _useCaseStroke,
    ));
    // Inscribed rectangle inside the ellipse — text outside this rectangle
    // would clip against the curved edge.
    final innerHalfW = (rect.width / 2) * 0.92;
    final innerHalfH = (rect.height / 2) * 0.92;
    final innerLeft = rect.center.dx - innerHalfW;
    final innerRight = rect.center.dx + innerHalfW;
    final innerTop = rect.center.dy - innerHalfH;
    final innerBottom = rect.center.dy + innerHalfH;
    final innerWidth = innerRight - innerLeft;

    // Pre-measure each section so we can center the whole stack vertically.
    final sectionSizes = <Size>[];
    var totalH = 0.0;
    for (final s in spans) {
      switch (s) {
        case UseCaseLabelText(:final text):
          final size = measurer.measure(text, _useCaseStyle);
          sectionSizes.add(size);
          totalH += size.height;
        case UseCaseLabelSeparatorSpan(:final kind, :final text):
          if (kind == UseCaseLabelSeparator.labeled && text != null) {
            final size = measurer.measure(text, _useCaseStyle);
            final h = math.max(_separatorHeight, size.height) +
                _separatorPaddingV * 2;
            sectionSizes.add(Size(size.width, h));
            totalH += h;
          } else {
            const h = _separatorHeight + _separatorPaddingV * 2;
            sectionSizes.add(const Size(0, h));
            totalH += h;
          }
      }
    }

    final innerHeight = innerBottom - innerTop;
    var y = innerTop + math.max(0, (innerHeight - totalH) / 2);
    for (var idx = 0; idx < spans.length; idx++) {
      final s = spans[idx];
      final size = sectionSizes[idx];
      switch (s) {
        case UseCaseLabelText(:final text):
          shapes.add(SceneText(
            offset: Offset(
              rect.center.dx - size.width / 2,
              y,
            ),
            text: text,
            textStyle: _useCaseStyle,
            maxWidth: innerWidth,
          ));
          y += size.height;
        case UseCaseLabelSeparatorSpan(:final kind, :final text):
          final midY = y + size.height / 2;
          if (kind == UseCaseLabelSeparator.labeled && text != null) {
            // `..text..` -> thin line with centered text breaking the line.
            final labelSize = measurer.measure(text, _useCaseStyle);
            final labelHalf = labelSize.width / 2 + 4;
            shapes.add(SceneLine(
              from: Offset(innerLeft, midY),
              to: Offset(rect.center.dx - labelHalf, midY),
              dashed: false,
              head: null,
              stroke: _useCaseStroke,
              strokeWidth: 1.0,
            ));
            shapes.add(SceneLine(
              from: Offset(rect.center.dx + labelHalf, midY),
              to: Offset(innerRight, midY),
              dashed: false,
              head: null,
              stroke: _useCaseStroke,
              strokeWidth: 1.0,
            ));
            shapes.add(SceneText(
              offset: Offset(
                rect.center.dx - labelSize.width / 2,
                midY - labelSize.height / 2,
              ),
              text: text,
              textStyle: _useCaseStyle,
            ));
          } else if (kind == UseCaseLabelSeparator.thick) {
            shapes.add(SceneLine(
              from: Offset(innerLeft, midY),
              to: Offset(innerRight, midY),
              dashed: false,
              head: null,
              stroke: _useCaseStroke,
              strokeWidth: 2.5,
            ));
          } else {
            shapes.add(SceneLine(
              from: Offset(innerLeft, midY),
              to: Offset(innerRight, midY),
              dashed: false,
              head: null,
              stroke: _useCaseStroke,
              strokeWidth: 1.0,
            ));
          }
          y += size.height;
      }
    }
  }

  Size _measureUseCase(UseCaseNode uc, TextMeasurer measurer) {
    final spans = uc.labelSpans;
    if (spans != null && spans.isNotEmpty) {
      return _measureMultiSectionLabel(spans, measurer);
    }
    final labelSize = measurer.measure(uc.label, _useCaseStyle);
    final w = math.max(_useCaseMinWidth, labelSize.width + _useCasePaddingX * 2);
    final h =
        math.max(_useCaseMinHeight, labelSize.height + _useCasePaddingY * 2);
    return Size(w, h);
  }

  static const _separatorHeight = 8.0;
  static const _separatorPaddingV = 2.0;
  // Use case ellipses need extra horizontal padding when they hold a
  // sectioned label, otherwise the elliptical sides clip the section text.
  // We widen the overall shape so each text block fits inside the ellipse's
  // inscribed rectangle (≈ 70% of the width / height at the equator).
  static const _ellipsePaddingFactor = 1.35;

  Size _measureMultiSectionLabel(
      List<UseCaseLabelSpan> spans, TextMeasurer measurer) {
    var maxW = 0.0;
    var totalH = 0.0;
    for (final s in spans) {
      switch (s) {
        case UseCaseLabelText(:final text):
          final size = measurer.measure(text, _useCaseStyle);
          if (size.width > maxW) maxW = size.width;
          totalH += size.height;
        case UseCaseLabelSeparatorSpan(:final kind, :final text):
          if (kind == UseCaseLabelSeparator.labeled && text != null) {
            final size = measurer.measure(text, _useCaseStyle);
            if (size.width > maxW) maxW = size.width;
            totalH += math.max(_separatorHeight, size.height) +
                _separatorPaddingV * 2;
          } else {
            totalH += _separatorHeight + _separatorPaddingV * 2;
          }
      }
    }
    final w = math.max(_useCaseMinWidth,
        (maxW + _useCasePaddingX * 2) * _ellipsePaddingFactor);
    final h = math.max(_useCaseMinHeight,
        (totalH + _useCasePaddingY * 2) * _ellipsePaddingFactor);
    return Size(w, h);
  }
}

class _GridLayoutResult {
  final Map<String, Rect> rects;
  final double width;
  final double height;
  const _GridLayoutResult({
    required this.rects,
    required this.width,
    required this.height,
  });
}
