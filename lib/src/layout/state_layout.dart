import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
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
  static const _historyRadius = 10.0;
  static const _stateDescriptionDividerPad = 4.0;
  static const _stateDescriptionBottomPad = 8.0;
  static const _sdlFoldSize = 10.0;

  static const _stateFill = Color(0xFFFEFCE8);
  static const _stateStroke = Color(0xFF000000);
  static const _compositeFill = Color(0xFFFFFFFF);

  static const _stateStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
  );
  static const _stateDescriptionStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
  );
  static const _historyPseudoStyle = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 10,
    fontWeight: FontWeight.w700,
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

  _RegionResult _layoutRegion(
    List<StateDecl> states,
    List<StateTransition> transitions,
    TextMeasurer measurer,
    List<SceneShape> shapes,
    Offset origin, {
    bool inlineInitialPseudo = false,
  }) {
    final pseudoKinds = _classifyPseudoStates(transitions);
    final nodes = <String, _Node>{};

    // Resolve cross-container transitions: when a transition references a
    // name that's declared *nested* inside one of this region's top-level
    // states (rather than at top level itself), map that reference to the
    // enclosing top-level state. This lets `X --> Z` between siblings under
    // different composites render as an arrow between the composites' edges.
    String resolve(String ref) {
      if (ref == '[*]') return ref;
      final history = _normalizeHistoryRef(ref);
      if (history != ref) return history;
      for (final s in states) {
        if (s.name == ref) return ref;
      }
      for (final s in states) {
        if (_containsNestedName(s, ref)) return s.name;
      }
      return ref;
    }

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

    final resolvedTransitions = <StateTransition>[
      for (final t in transitions)
        StateTransition(
          from: resolve(t.from),
          to: resolve(t.to),
          label: t.label,
        ),
    ];

    final levels = _bfsLevels(orderedNames, resolvedTransitions);
    if (inlineInitialPseudo && levels.containsKey('[*]:initial')) {
      // V6: in a vertically-stacked concurrent region, hoist the leading
      // `[*]` initial pseudo down to the same row as its single successor
      // so it appears inline to the left of the first state instead of
      // occupying a separate top row. Only applies when `[*]:initial` is
      // alone at level 0 and points to exactly one target.
      final initLevel = levels['[*]:initial'];
      final outFromInit = resolvedTransitions
          .where((t) => _refToNodeKey(t.from, source: true) == '[*]:initial')
          .map((t) => _refToNodeKey(t.to, source: false))
          .toSet();
      if (initLevel == 0 && outFromInit.length == 1) {
        final target = outFromInit.first;
        final targetLevel = levels[target];
        if (targetLevel != null && targetLevel > 0) {
          levels['[*]:initial'] = targetLevel;
          // Ensure the pseudo dot is positioned to the LEFT of the target
          // by reordering the names so it precedes the target in row order.
          orderedNames.remove('[*]:initial');
          final tIdx = orderedNames.indexOf(target);
          if (tIdx >= 0) {
            orderedNames.insert(tIdx, '[*]:initial');
          } else {
            orderedNames.add('[*]:initial');
          }
        }
      }
    }
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

    final pairCounts = <String, int>{};
    for (final t in resolvedTransitions) {
      final fromKey = _refToNodeKey(t.from, source: true);
      final toKey = _refToNodeKey(t.to, source: false);
      final key = '$fromKey|$toKey';
      pairCounts[key] = (pairCounts[key] ?? 0) + 1;
    }
    // Track how many transitions we've already drawn that end at each
    // target. We use this index to vertically displace overlapping labels
    // so multiple arrows landing on the same endpoint (typically `[*]`)
    // don't collide.
    final endpointCounters = <String, int>{};
    final endpointTotals = <String, int>{};
    for (final t in resolvedTransitions) {
      final toKey = _refToNodeKey(t.to, source: false);
      endpointTotals[toKey] = (endpointTotals[toKey] ?? 0) + 1;
    }
    for (final t in resolvedTransitions) {
      final fromKey = _refToNodeKey(t.from, source: true);
      final toKey = _refToNodeKey(t.to, source: false);
      final a = nodes[fromKey];
      final b = nodes[toKey];
      if (a == null || b == null) continue;
      // Drop self-loops introduced by collapsing a cross-nested transition
      // whose endpoints both resolve to the same enclosing composite.
      if (fromKey == toKey) continue;
      final reverseKey = '$toKey|$fromKey';
      final hasReverse = (pairCounts[reverseKey] ?? 0) > 0;
      final endpointIndex = endpointCounters[toKey] ?? 0;
      endpointCounters[toKey] = endpointIndex + 1;
      final endpointTotal = endpointTotals[toKey] ?? 1;
      _emitTransition(
        shapes,
        t,
        a,
        b,
        measurer,
        bidirectional: hasReverse,
        endpointIndex: endpointIndex,
        endpointTotal: endpointTotal,
      );
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

  /// Collapse a qualified history reference `Name[H]`/`Name[H*]` to its bare
  /// pseudo form `[H]`/`[H*]`. The default layout draws a single history marker
  /// per kind and does not scope history to its owning composite, so the owner
  /// prefix is dropped here (the opt-in Sugiyama layout preserves it instead).
  String _normalizeHistoryRef(String ref) {
    if (ref == '[H]' || ref == '[H*]') return ref;
    if (ref.endsWith('[H*]')) return '[H*]';
    if (ref.endsWith('[H]')) return '[H]';
    return ref;
  }

  Map<String, _PseudoKind> _classifyPseudoStates(
      List<StateTransition> transitions) {
    final result = <String, _PseudoKind>{};
    for (final t in transitions) {
      final from = _normalizeHistoryRef(t.from);
      final to = _normalizeHistoryRef(t.to);
      if (from == '[*]') {
        result.putIfAbsent('[*]:initial', () => _PseudoKind.initial);
      }
      if (to == '[*]') {
        result.putIfAbsent('[*]:final', () => _PseudoKind.finalState);
      }
      if (from == '[H]' || to == '[H]') {
        result.putIfAbsent('[H]', () => _PseudoKind.historyShallow);
      }
      if (from == '[H*]' || to == '[H*]') {
        result.putIfAbsent('[H*]', () => _PseudoKind.historyDeep);
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
    if (ref == '[H]' || ref == '[H*]') return ref;
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
    final r = (kind == _PseudoKind.historyShallow ||
            kind == _PseudoKind.historyDeep)
        ? _historyRadius
        : _pseudoRadius;
    return _Node(
      kind: _NodeKind.pseudo,
      width: r * 2,
      height: r * 2,
      pseudoKind: kind,
    );
  }

  /// Sizes the bounding box for a stereotype-driven pseudo-state. Choice gets
  /// a diamond inscribed in a small square; fork/join get a wide-but-thin
  /// horizontal bar; start/end reuse the [*] pseudo dot/ring size so arrows
  /// align consistently across initial-style targets.
  _Node _stereotypePseudoNode(_PseudoKind kind) {
    switch (kind) {
      case _PseudoKind.choice:
        const size = 24.0;
        return _Node(
          kind: _NodeKind.pseudo,
          width: size,
          height: size,
          pseudoKind: kind,
        );
      case _PseudoKind.fork:
      case _PseudoKind.join:
        return _Node(
          kind: _NodeKind.pseudo,
          width: 60.0,
          height: 8.0,
          pseudoKind: kind,
        );
      case _PseudoKind.initial:
      case _PseudoKind.finalState:
      case _PseudoKind.historyShallow:
      case _PseudoKind.historyDeep:
        return _pseudoNode(kind);
    }
  }

  _Node _measureState(
      StateDecl decl, TextMeasurer measurer, List<SceneShape> outerShapes) {
    if (decl.concurrentRegions.isNotEmpty) {
      return _measureConcurrent(decl, measurer);
    }
    if (decl.nestedStates.isNotEmpty || decl.nestedTransitions.isNotEmpty) {
      return _measureComposite(decl, measurer);
    }
    // UML pseudo-states declared via stereotype (`state X <<start>>` etc.).
    // The name is dropped from the visual (PlantUML omits it) — the shape
    // alone carries the meaning. Shape sizes mirror the [*] initial/final
    // pseudo nodes for start/end so arrows align with sibling pseudos.
    final pseudo = _pseudoKindFromStereotype(decl.stereotype);
    if (pseudo != null) {
      return _stereotypePseudoNode(pseudo);
    }
    // SDL receive stereotype — render as a rectangular state-style box with
    // a small folded-corner notch in the top-left, matching PlantUML's SDL
    // "receive message" envelope shape.
    final stereoLower = decl.stereotype?.trim().toLowerCase();
    if (stereoLower == 'sdlreceive') {
      final titleSize = measurer.measure(decl.label, _stateStyle);
      final width = math.max(
        _minStateWidth,
        titleSize.width + _statePaddingX * 2 + _sdlFoldSize,
      );
      final height =
          math.max(_minStateHeight, titleSize.height + _statePaddingY * 2);
      return _Node(
        kind: _NodeKind.sdlReceive,
        width: width,
        height: height,
        label: decl.label,
        titleHeight: titleSize.height,
      );
    }
    final titleSize = measurer.measure(decl.label, _stateStyle);
    var contentWidth = titleSize.width;
    var descBlockHeight = 0.0;
    final descSizes = <Size>[];
    for (final d in decl.descriptions) {
      final s = measurer.measure(d, _stateDescriptionStyle);
      descSizes.add(s);
      if (s.width > contentWidth) contentWidth = s.width;
      descBlockHeight += s.height;
    }
    final width =
        math.max(_minStateWidth, contentWidth + _statePaddingX * 2);
    var height =
        math.max(_minStateHeight, titleSize.height + _statePaddingY * 2);
    if (decl.descriptions.isNotEmpty) {
      // Slot the divider and each description line beneath the title. The
      // padded title row provides vertical breathing room above the rule.
      height = _statePaddingY +
          titleSize.height +
          _stateDescriptionDividerPad * 2 +
          descBlockHeight +
          _stateDescriptionBottomPad;
    }
    return _Node(
      kind: _NodeKind.simple,
      width: width,
      height: height,
      label: decl.label,
      descriptions: decl.descriptions,
      descriptionSizes: descSizes,
      titleHeight: titleSize.height,
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
    var maxHeight = 0.0;
    var totalWidth = 0.0;
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
        inlineInitialPseudo: !decl.horizontalRegions,
      );
      regionShapes.add(shapes);
      regionSizes.add(result);
      if (result.width > maxWidth) maxWidth = result.width;
      if (result.height > maxHeight) maxHeight = result.height;
      totalWidth += result.width;
      totalHeight += result.height;
      if (i < decl.concurrentRegions.length - 1) {
        totalHeight += _regionGap * 2;
        totalWidth += _regionGap * 2;
      }
    }
    double width;
    double height;
    if (decl.horizontalRegions) {
      width = math.max(
        math.max(_minStateWidth, headerSize.width + _statePaddingX * 2),
        totalWidth + _compositeBodyPad * 2,
      );
      height = _compositeHeaderHeight + _compositeBodyPad * 2 + maxHeight;
    } else {
      width = math.max(
        math.max(_minStateWidth, headerSize.width + _statePaddingX * 2),
        maxWidth + _compositeBodyPad * 2,
      );
      height = _compositeHeaderHeight + _compositeBodyPad * 2 + totalHeight;
    }
    return _Node(
      kind: _NodeKind.concurrent,
      width: width,
      height: height,
      label: decl.label,
      regionShapes: regionShapes,
      regionSizes: regionSizes,
      horizontalRegions: decl.horizontalRegions,
    );
  }

  /// True when [name] appears as a nested state anywhere inside [decl]
  /// (recursively through nestedStates and concurrentRegions). Used to
  /// resolve cross-container transitions to their enclosing composite so
  /// the arrow draws between container edges instead of being dropped.
  bool _containsNestedName(StateDecl decl, String name) {
    for (final n in decl.nestedStates) {
      if (n.name == name) return true;
      if (_containsNestedName(n, name)) return true;
    }
    for (final region in decl.concurrentRegions) {
      for (final n in region) {
        if (n.name == name) return true;
        if (_containsNestedName(n, name)) return true;
      }
    }
    return false;
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
        if (node.pseudoKind == _PseudoKind.choice) {
          // Hollow diamond (UML choice pseudo-state): yellow-cream fill to
          // match sibling state boxes plus a black border so it reads as a
          // decision point on the diagram.
          final rect = Rect.fromLTWH(
              node.origin.dx, node.origin.dy, node.width, node.height);
          shapes.add(SceneDiamond(
            rect: rect,
            textStyle: _stateStyle,
            fill: _stateFill,
            stroke: _stateStroke,
          ));
          return;
        }
        if (node.pseudoKind == _PseudoKind.fork ||
            node.pseudoKind == _PseudoKind.join) {
          // Thick horizontal bar (UML fork/join synchronization marker).
          final rect = Rect.fromLTWH(
              node.origin.dx, node.origin.dy, node.width, node.height);
          shapes.add(SceneBox(
            rect: rect,
            textStyle: _stateStyle,
            fill: const Color(0xFF000000),
            stroke: const Color(0xFF000000),
          ));
          return;
        }
        if (node.pseudoKind == _PseudoKind.historyShallow ||
            node.pseudoKind == _PseudoKind.historyDeep) {
          // Render a small open circle with the letter H (or H*) inside.
          // The stroke matches the state outline so the marker reads as a
          // pseudo-state node rather than a filled dot.
          shapes.add(SceneCircle(
            center: center,
            radius: _historyRadius,
            fill: const Color(0xFF000000),
            stroke: const Color(0xFF000000),
            ring: false,
          ));
          final letter =
              node.pseudoKind == _PseudoKind.historyDeep ? 'H*' : 'H';
          final size = measurer.measure(letter, _historyPseudoStyle);
          shapes.add(SceneText(
            offset: Offset(
              center.dx - size.width / 2,
              center.dy - size.height / 2,
            ),
            text: letter,
            textStyle: _historyPseudoStyle,
          ));
        } else {
          shapes.add(SceneCircle(
            center: center,
            radius: _pseudoRadius,
            fill: const Color(0xFF000000),
            stroke: const Color(0xFF000000),
            ring: node.pseudoKind == _PseudoKind.finalState,
          ));
        }
      case _NodeKind.sdlReceive:
        final rect = Rect.fromLTWH(
            node.origin.dx, node.origin.dy, node.width, node.height);
        shapes.add(SceneBox(
          rect: rect,
          textStyle: _stateStyle,
          fill: _stateFill,
          stroke: _stateStroke,
        ));
        // Diagonal fold line cutting off the top-left corner — the SDL
        // receive-message envelope shape.
        shapes.add(SceneLine(
          from: Offset(rect.left, rect.top + _sdlFoldSize),
          to: Offset(rect.left + _sdlFoldSize, rect.top),
          head: null,
          stroke: _stateStroke,
        ));
        final titleSize = measurer.measure(node.label ?? '', _stateStyle);
        shapes.add(SceneText(
          offset: Offset(
            rect.left + _sdlFoldSize +
                (rect.width - _sdlFoldSize - titleSize.width) / 2,
            rect.center.dy - titleSize.height / 2,
          ),
          text: node.label ?? '',
          textStyle: _stateStyle,
        ));
      case _NodeKind.simple:
        final rect = Rect.fromLTWH(
            node.origin.dx, node.origin.dy, node.width, node.height);
        if (node.descriptions.isEmpty) {
          shapes.add(SceneRoundedBox(
            rect: rect,
            label: node.label,
            textStyle: _stateStyle,
            fill: _stateFill,
            stroke: _stateStroke,
            cornerRadius: 12.0,
          ));
        } else {
          // Draw the rounded background separately so we can paint a
          // horizontal divider plus left-aligned description lines under
          // the centered title.
          shapes.add(SceneRoundedBox(
            rect: rect,
            textStyle: _stateStyle,
            fill: _stateFill,
            stroke: _stateStroke,
            cornerRadius: 12.0,
          ));
          final titleSize = measurer.measure(node.label ?? '', _stateStyle);
          shapes.add(SceneText(
            offset: Offset(
              rect.center.dx - titleSize.width / 2,
              rect.top + _statePaddingY,
            ),
            text: node.label ?? '',
            textStyle: _stateStyle,
          ));
          final dividerY = rect.top +
              _statePaddingY +
              node.titleHeight +
              _stateDescriptionDividerPad;
          shapes.add(SceneLine(
            from: Offset(rect.left, dividerY),
            to: Offset(rect.right, dividerY),
            head: null,
            stroke: _stateStroke,
          ));
          var y = dividerY + _stateDescriptionDividerPad;
          for (var i = 0; i < node.descriptions.length; i++) {
            final desc = node.descriptions[i];
            final ds = node.descriptionSizes[i];
            shapes.add(SceneText(
              offset: Offset(rect.left + _statePaddingX, y),
              text: desc,
              textStyle: _stateDescriptionStyle,
            ));
            y += ds.height;
          }
        }
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
        if (node.horizontalRegions) {
          // Side-by-side regions separated by vertical dashed dividers.
          var x = rect.left + _compositeBodyPad;
          final bodyTop = rect.top + _compositeHeaderHeight + _compositeBodyPad;
          for (var i = 0; i < node.regionShapes!.length; i++) {
            final regionShapes = node.regionShapes![i];
            final regionSize = node.regionSizes![i];
            final base = Offset(x - _compositeBodyPad, bodyTop);
            for (final shape in regionShapes) {
              shapes.add(_translateShape(shape, base));
            }
            x += regionSize.width;
            if (i < node.regionShapes!.length - 1) {
              final dashX = x + _regionGap;
              shapes.add(SceneLine(
                from: Offset(dashX, rect.top + _compositeHeaderHeight + 4),
                to: Offset(dashX, rect.bottom - 4),
                dashed: true,
                head: null,
                stroke: _stateStroke,
              ));
              x += _regionGap * 2;
            }
          }
        } else {
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
      case SceneTriangle():
        return SceneTriangle(
          rect: shape.rect.shift(by),
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
    TextMeasurer measurer, {
    bool bidirectional = false,
    int endpointIndex = 0,
    int endpointTotal = 1,
  }) {
    final aRect = Rect.fromLTWH(a.origin.dx, a.origin.dy, a.width, a.height);
    final bRect = Rect.fromLTWH(b.origin.dx, b.origin.dy, b.width, b.height);
    var fromEdge = _edgePoint(aRect, bRect.center);
    var toEdge = _edgePoint(bRect, aRect.center);
    if (bidirectional) {
      const offset = 14.0;
      final dx = toEdge.dx - fromEdge.dx;
      final dy = toEdge.dy - fromEdge.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len > 0) {
        final px = -dy / len;
        final py = dx / len;
        fromEdge = Offset(
          fromEdge.dx + px * offset,
          fromEdge.dy + py * offset,
        );
        toEdge = Offset(
          toEdge.dx + px * offset,
          toEdge.dy + py * offset,
        );
      }
    }
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
      // When multiple transitions converge on the same target the midpoint
      // labels stack on top of each other. Shift each label vertically by a
      // line-height-sized increment, centered on the natural midpoint, so
      // sibling labels read as a stacked list rather than a smudge.
      var labelDy = 0.0;
      if (endpointTotal > 1) {
        final step = size.height + 2.0;
        final centerOffset = (endpointTotal - 1) / 2.0;
        labelDy = (endpointIndex - centerOffset) * step;
      }
      shapes.add(SceneText(
        offset: Offset(mid.dx + 4, mid.dy - size.height / 2 + labelDy),
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

enum _NodeKind { simple, composite, concurrent, pseudo, sdlReceive }

enum _PseudoKind {
  initial,
  finalState,
  historyShallow,
  historyDeep,
  choice,
  fork,
  join,
}

/// Returns the `_PseudoKind` for a [StateDecl.stereotype] when the value
/// names a UML pseudo-state that gets a special shape (start/end/choice/
/// fork/join). Returns null for arbitrary user stereotypes so those still
/// render as regular rounded state boxes.
_PseudoKind? _pseudoKindFromStereotype(String? stereotype) {
  if (stereotype == null) return null;
  switch (stereotype.trim().toLowerCase()) {
    case 'start':
      return _PseudoKind.initial;
    case 'end':
      return _PseudoKind.finalState;
    case 'choice':
      return _PseudoKind.choice;
    case 'fork':
      return _PseudoKind.fork;
    case 'join':
      return _PseudoKind.join;
    default:
      return null;
  }
}

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
  final bool horizontalRegions;
  final List<String> descriptions;
  final List<Size> descriptionSizes;
  final double titleHeight;
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
    this.horizontalRegions = false,
    this.descriptions = const [],
    this.descriptionSizes = const [],
    this.titleHeight = 0.0,
  });
}

class _RegionResult {
  final double width;
  final double height;
  const _RegionResult({required this.width, required this.height});
}
