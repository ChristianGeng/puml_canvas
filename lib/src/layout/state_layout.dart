import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class StateLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _statePaddingX = 18.0;
  static const _statePaddingY = 10.0;
  static const _minStateWidth = 80.0;
  static const _minStateHeight = 36.0;
  static const _colGap = 50.0;
  static const _rowGap = 50.0;
  static const _compositeHeaderHeight = 22.0;
  static const _compositeBodyPad = 14.0;
  static const _regionGap = 10.0;
  static const _pseudoRadius = 8.0;

  static const _stateFill = Color(0xFFFEFCE8);
  static const _stateStroke = Color(0xFF000000);
  static const _compositeFill = Color(0xFFFFFFFF);

  static const _stateStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
  );
  static const _compositeHeaderStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _transitionLabelStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 10,
  );

  const StateLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! StateDiagram) {
      throw ArgumentError('StateLayout expects StateDiagram');
    }
    if (diagram.states.isEmpty && diagram.transitions.isEmpty) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    final shapes = <SceneShape>[];
    final result = _layoutRegion(
      diagram.states,
      diagram.transitions,
      measurer,
      shapes,
      Offset(_padding, _padding),
    );

    final width = result.width + _padding * 2;
    final height = result.height + _padding * 2;
    return Scene(
      size: Size(width, height),
      shapes: shapes,
      background: diagram.skin.backgroundColor,
    );
  }

  _RegionResult _layoutRegion(
    List<StateDecl> states,
    List<StateTransition> transitions,
    TextMeasurer measurer,
    List<SceneShape> shapes,
    Offset origin,
  ) {
    final pseudoKinds = _classifyPseudoStates(transitions);
    final nodes = <String, _Node>{};

    final orderedNames = <String>[];
    for (final s in states) {
      if (!nodes.containsKey(s.name)) {
        nodes[s.name] = _measureState(s, measurer, shapes);
        orderedNames.add(s.name);
      }
    }
    for (final entry in pseudoKinds.entries) {
      final key = entry.key;
      if (!nodes.containsKey(key)) {
        nodes[key] = _pseudoNode(entry.value);
        orderedNames.add(key);
      }
    }

    final levels = _bfsLevels(orderedNames, transitions);
    final positioned = _positionByLevel(
      orderedNames,
      nodes,
      levels,
    );

    for (final name in orderedNames) {
      final node = nodes[name]!;
      final pos = positioned[name]!;
      node.origin = Offset(origin.dx + pos.dx, origin.dy + pos.dy);
      _emitNode(node, shapes, measurer);
    }

    for (final t in transitions) {
      final a = nodes[t.from];
      final b = nodes[t.to];
      if (a == null || b == null) continue;
      _emitTransition(shapes, t, a, b, measurer);
    }

    var width = 0.0;
    var height = 0.0;
    for (final name in orderedNames) {
      final node = nodes[name]!;
      final right = (node.origin.dx - origin.dx) + node.width;
      final bottom = (node.origin.dy - origin.dy) + node.height;
      if (right > width) width = right;
      if (bottom > height) height = bottom;
    }
    return _RegionResult(width: width, height: height);
  }

  Map<String, _PseudoKind> _classifyPseudoStates(
      List<StateTransition> transitions) {
    final result = <String, _PseudoKind>{};
    for (final t in transitions) {
      if (t.from == '[*]') {
        result.putIfAbsent('[*]:initial', () => _PseudoKind.initial);
      }
      if (t.to == '[*]') {
        result.putIfAbsent('[*]:final', () => _PseudoKind.finalState);
      }
    }
    return result;
  }

  Map<String, int> _bfsLevels(
      List<String> names, List<StateTransition> transitions) {
    final inDegree = <String, int>{for (final n in names) n: 0};
    final out = <String, List<String>>{for (final n in names) n: <String>[]};
    for (final t in transitions) {
      final from = _refToNodeKey(t.from, source: true);
      final to = _refToNodeKey(t.to, source: false);
      if (!inDegree.containsKey(from) || !inDegree.containsKey(to)) continue;
      if (from == to) continue;
      out[from]!.add(to);
      inDegree[to] = (inDegree[to] ?? 0) + 1;
    }
    final level = <String, int>{};
    final queue = <String>[];
    for (final n in names) {
      if ((inDegree[n] ?? 0) == 0) {
        level[n] = 0;
        queue.add(n);
      }
    }
    if (queue.isEmpty && names.isNotEmpty) {
      level[names.first] = 0;
      queue.add(names.first);
    }
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      final lv = level[cur]!;
      for (final n in out[cur]!) {
        if (!level.containsKey(n)) {
          level[n] = lv + 1;
          queue.add(n);
        }
      }
    }
    for (final n in names) {
      level.putIfAbsent(n, () => 0);
    }
    return level;
  }

  String _refToNodeKey(String ref, {required bool source}) {
    if (ref == '[*]') {
      return source ? '[*]:initial' : '[*]:final';
    }
    return ref;
  }

  Map<String, Offset> _positionByLevel(
    List<String> names,
    Map<String, _Node> nodes,
    Map<String, int> levels,
  ) {
    final byLevel = <int, List<String>>{};
    for (final n in names) {
      final lv = levels[n]!;
      byLevel.putIfAbsent(lv, () => <String>[]).add(n);
    }
    final sorted = byLevel.keys.toList()..sort();
    final positions = <String, Offset>{};
    var y = 0.0;
    var totalWidth = 0.0;
    final rowExtents = <int, double>{};
    for (final lv in sorted) {
      final row = byLevel[lv]!;
      var rowWidth = 0.0;
      for (final n in row) {
        rowWidth += nodes[n]!.width;
      }
      rowWidth += _colGap * math.max(0, row.length - 1);
      rowExtents[lv] = rowWidth;
      if (rowWidth > totalWidth) totalWidth = rowWidth;
    }
    for (final lv in sorted) {
      final row = byLevel[lv]!;
      final rowWidth = rowExtents[lv]!;
      var x = (totalWidth - rowWidth) / 2;
      var rowHeight = 0.0;
      for (final n in row) {
        positions[n] = Offset(x, y);
        x += nodes[n]!.width + _colGap;
        if (nodes[n]!.height > rowHeight) rowHeight = nodes[n]!.height;
      }
      y += rowHeight + _rowGap;
    }
    return positions;
  }

  _Node _pseudoNode(_PseudoKind kind) {
    return _Node(
      kind: _NodeKind.pseudo,
      width: _pseudoRadius * 2,
      height: _pseudoRadius * 2,
      pseudoKind: kind,
    );
  }

  _Node _measureState(
      StateDecl decl, TextMeasurer measurer, List<SceneShape> outerShapes) {
    if (decl.concurrentRegions.isNotEmpty) {
      return _measureConcurrent(decl, measurer);
    }
    if (decl.nestedStates.isNotEmpty || decl.nestedTransitions.isNotEmpty) {
      return _measureComposite(decl, measurer);
    }
    final size = measurer.measure(decl.label, _stateStyle);
    final width =
        math.max(_minStateWidth, size.width + _statePaddingX * 2);
    final height =
        math.max(_minStateHeight, size.height + _statePaddingY * 2);
    return _Node(
      kind: _NodeKind.simple,
      width: width,
      height: height,
      label: decl.label,
    );
  }

  _Node _measureComposite(StateDecl decl, TextMeasurer measurer) {
    final inner = <SceneShape>[];
    final result = _layoutRegion(
      decl.nestedStates,
      decl.nestedTransitions,
      measurer,
      inner,
      Offset(_compositeBodyPad, _compositeHeaderHeight + _compositeBodyPad),
    );
    final headerSize = measurer.measure(decl.label, _compositeHeaderStyle);
    final width = math.max(
      math.max(_minStateWidth, headerSize.width + _statePaddingX * 2),
      result.width + _compositeBodyPad * 2,
    );
    final height = _compositeHeaderHeight +
        _compositeBodyPad * 2 +
        result.height;
    return _Node(
      kind: _NodeKind.composite,
      width: width,
      height: height,
      label: decl.label,
      childShapes: inner,
      childOffset: Offset.zero,
    );
  }

  _Node _measureConcurrent(StateDecl decl, TextMeasurer measurer) {
    final headerSize = measurer.measure(decl.label, _compositeHeaderStyle);
    final regionShapes = <List<SceneShape>>[];
    final regionSizes = <_RegionResult>[];
    var maxWidth = 0.0;
    var totalHeight = 0.0;
    for (var i = 0; i < decl.concurrentRegions.length; i++) {
      final region = decl.concurrentRegions[i];
      final relevantTransitions = decl.nestedTransitions
          .where((t) =>
              _isInRegion(t.from, region) && _isInRegion(t.to, region))
          .toList();
      final shapes = <SceneShape>[];
      final result = _layoutRegion(
        region,
        relevantTransitions,
        measurer,
        shapes,
        Offset(_compositeBodyPad, 0),
      );
      regionShapes.add(shapes);
      regionSizes.add(result);
      if (result.width > maxWidth) maxWidth = result.width;
      totalHeight += result.height;
      if (i < decl.concurrentRegions.length - 1) {
        totalHeight += _regionGap * 2;
      }
    }
    final width = math.max(
      math.max(_minStateWidth, headerSize.width + _statePaddingX * 2),
      maxWidth + _compositeBodyPad * 2,
    );
    final height = _compositeHeaderHeight +
        _compositeBodyPad * 2 +
        totalHeight;
    return _Node(
      kind: _NodeKind.concurrent,
      width: width,
      height: height,
      label: decl.label,
      regionShapes: regionShapes,
      regionSizes: regionSizes,
    );
  }

  bool _isInRegion(String ref, List<StateDecl> region) {
    if (ref == '[*]') return true;
    for (final s in region) {
      if (s.name == ref) return true;
    }
    return false;
  }

  void _emitNode(_Node node, List<SceneShape> shapes, TextMeasurer measurer) {
    switch (node.kind) {
      case _NodeKind.pseudo:
        final center = Offset(
          node.origin.dx + node.width / 2,
          node.origin.dy + node.height / 2,
        );
        shapes.add(SceneCircle(
          center: center,
          radius: _pseudoRadius,
          fill: const Color(0xFF000000),
          stroke: const Color(0xFF000000),
          ring: node.pseudoKind == _PseudoKind.finalState,
        ));
      case _NodeKind.simple:
        final rect = Rect.fromLTWH(
            node.origin.dx, node.origin.dy, node.width, node.height);
        shapes.add(SceneRoundedBox(
          rect: rect,
          label: node.label,
          textStyle: _stateStyle,
          fill: _stateFill,
          stroke: _stateStroke,
          cornerRadius: 12.0,
        ));
      case _NodeKind.composite:
        final rect = Rect.fromLTWH(
            node.origin.dx, node.origin.dy, node.width, node.height);
        shapes.add(SceneRoundedBox(
          rect: rect,
          textStyle: _compositeHeaderStyle,
          fill: _compositeFill,
          stroke: _stateStroke,
          cornerRadius: 12.0,
        ));
        final headerSize =
            measurer.measure(node.label ?? '', _compositeHeaderStyle);
        shapes.add(SceneText(
          offset: Offset(
            rect.center.dx - headerSize.width / 2,
            rect.top + 4,
          ),
          text: node.label ?? '',
          textStyle: _compositeHeaderStyle,
        ));
        shapes.add(SceneLine(
          from: Offset(rect.left, rect.top + _compositeHeaderHeight),
          to: Offset(rect.right, rect.top + _compositeHeaderHeight),
          head: null,
          stroke: _stateStroke,
        ));
        for (final shape in node.childShapes!) {
          shapes.add(_translateShape(shape, node.origin));
        }
      case _NodeKind.concurrent:
        final rect = Rect.fromLTWH(
            node.origin.dx, node.origin.dy, node.width, node.height);
        shapes.add(SceneRoundedBox(
          rect: rect,
          textStyle: _compositeHeaderStyle,
          fill: _compositeFill,
          stroke: _stateStroke,
          cornerRadius: 12.0,
        ));
        final headerSize =
            measurer.measure(node.label ?? '', _compositeHeaderStyle);
        shapes.add(SceneText(
          offset: Offset(
            rect.center.dx - headerSize.width / 2,
            rect.top + 4,
          ),
          text: node.label ?? '',
          textStyle: _compositeHeaderStyle,
        ));
        shapes.add(SceneLine(
          from: Offset(rect.left, rect.top + _compositeHeaderHeight),
          to: Offset(rect.right, rect.top + _compositeHeaderHeight),
          head: null,
          stroke: _stateStroke,
        ));
        var y = rect.top + _compositeHeaderHeight + _compositeBodyPad;
        for (var i = 0; i < node.regionShapes!.length; i++) {
          final regionShapes = node.regionShapes![i];
          final regionSize = node.regionSizes![i];
          final base = Offset(node.origin.dx, y);
          for (final shape in regionShapes) {
            shapes.add(_translateShape(shape, base));
          }
          y += regionSize.height;
          if (i < node.regionShapes!.length - 1) {
            final dashY = y + _regionGap;
            shapes.add(SceneLine(
              from: Offset(rect.left + 4, dashY),
              to: Offset(rect.right - 4, dashY),
              dashed: true,
              head: null,
              stroke: _stateStroke,
            ));
            y += _regionGap * 2;
          }
        }
    }
  }

  SceneShape _translateShape(SceneShape shape, Offset by) {
    switch (shape) {
      case SceneBox():
        return SceneBox(
          rect: shape.rect.shift(by),
          label: shape.label,
          textStyle: shape.textStyle,
          fill: shape.fill,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
        );
      case SceneNote():
        return SceneNote(
          rect: shape.rect.shift(by),
          text: shape.text,
          textStyle: shape.textStyle,
          fill: shape.fill,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
          foldSize: shape.foldSize,
        );
      case SceneText():
        return SceneText(
          offset: shape.offset + by,
          text: shape.text,
          textStyle: shape.textStyle,
          maxWidth: shape.maxWidth,
        );
      case SceneSymbol():
        return SceneSymbol(
          rect: shape.rect.shift(by),
          label: shape.label,
          labelStyle: shape.labelStyle,
          kind: shape.kind,
          fill: shape.fill,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
        );
      case SceneEllipse():
        return SceneEllipse(
          rect: shape.rect.shift(by),
          label: shape.label,
          textStyle: shape.textStyle,
          fill: shape.fill,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
        );
      case SceneDiamond():
        return SceneDiamond(
          rect: shape.rect.shift(by),
          label: shape.label,
          textStyle: shape.textStyle,
          fill: shape.fill,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
        );
      case SceneCircle():
        return SceneCircle(
          center: shape.center + by,
          radius: shape.radius,
          fill: shape.fill,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
          ring: shape.ring,
        );
      case SceneRoundedBox():
        return SceneRoundedBox(
          rect: shape.rect.shift(by),
          label: shape.label,
          textStyle: shape.textStyle,
          fill: shape.fill,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
          cornerRadius: shape.cornerRadius,
        );
      case SceneLine():
        return SceneLine(
          from: shape.from + by,
          to: shape.to + by,
          dashed: shape.dashed,
          head: shape.head,
          headAtFrom: shape.headAtFrom,
          label: shape.label,
          labelStyle: shape.labelStyle,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
        );
      case SceneCrowFoot():
        return SceneCrowFoot(
          position: shape.position + by,
          angle: shape.angle,
          kind: shape.kind,
          stroke: shape.stroke,
          strokeWidth: shape.strokeWidth,
        );
    }
  }

  void _emitTransition(
    List<SceneShape> shapes,
    StateTransition t,
    _Node a,
    _Node b,
    TextMeasurer measurer,
  ) {
    final aRect = Rect.fromLTWH(a.origin.dx, a.origin.dy, a.width, a.height);
    final bRect = Rect.fromLTWH(b.origin.dx, b.origin.dy, b.width, b.height);
    final fromEdge = _edgePoint(aRect, bRect.center);
    final toEdge = _edgePoint(bRect, aRect.center);
    shapes.add(SceneLine(
      from: fromEdge,
      to: toEdge,
      dashed: false,
      head: ArrowHead.open,
      stroke: _stateStroke,
    ));
    final label = t.label;
    if (label != null && label.isNotEmpty) {
      final size = measurer.measure(label, _transitionLabelStyle);
      final mid = Offset(
        (fromEdge.dx + toEdge.dx) / 2,
        (fromEdge.dy + toEdge.dy) / 2,
      );
      shapes.add(SceneText(
        offset: Offset(mid.dx + 4, mid.dy - size.height / 2),
        text: label,
        textStyle: _transitionLabelStyle,
      ));
    }
  }

  Offset _edgePoint(Rect rect, Offset toward) {
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
}

enum _NodeKind { simple, composite, concurrent, pseudo }

enum _PseudoKind { initial, finalState }

class _Node {
  final _NodeKind kind;
  final double width;
  final double height;
  final String? label;
  final _PseudoKind? pseudoKind;
  final List<SceneShape>? childShapes;
  final Offset? childOffset;
  final List<List<SceneShape>>? regionShapes;
  final List<_RegionResult>? regionSizes;
  Offset origin = Offset.zero;

  _Node({
    required this.kind,
    required this.width,
    required this.height,
    this.label,
    this.pseudoKind,
    this.childShapes,
    this.childOffset,
    this.regionShapes,
    this.regionSizes,
  });
}

class _RegionResult {
  final double width;
  final double height;
  const _RegionResult({required this.width, required this.height});
}
