import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
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

  const UseCaseLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! UseCaseDiagram) {
      throw ArgumentError('UseCaseLayout expects UseCaseDiagram');
    }
    if (diagram.nodes.isEmpty) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
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

    final height = math.max(actorsBottom, blockY) + _padding;
    final width = math.max(diagramRight, actorsRight) + _padding;

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
      shapes.add(SceneEllipse(
        rect: rect,
        label: n.label,
        textStyle: _useCaseStyle,
        fill: _useCaseFill,
        stroke: _useCaseStroke,
      ));
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
      shapes.add(SceneLine(
        from: fromPoint,
        to: toPoint,
        dashed: r.lineStyle == LineStyle.dashed,
        head: r.head,
        headAtFrom: false,
        label: r.label,
        labelStyle: r.label == null ? null : _relationLabelStyle,
        stroke: const Color(0xFF000000),
        strokeWidth: 1.0,
      ));
    }

    return Scene(
      size: Size(width, height),
      shapes: shapes,
      background: diagram.skin.backgroundColor,
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

  Size _measureUseCase(UseCaseNode uc, TextMeasurer measurer) {
    final labelSize = measurer.measure(uc.label, _useCaseStyle);
    final w = math.max(_useCaseMinWidth, labelSize.width + _useCasePaddingX * 2);
    final h =
        math.max(_useCaseMinHeight, labelSize.height + _useCasePaddingY * 2);
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
