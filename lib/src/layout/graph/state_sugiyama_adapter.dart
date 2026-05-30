import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../../ast/diagram.dart';
import '../decoration_wrapper.dart';
import '../scene.dart';
import '../text_measurer.dart';
import 'coordinates.dart';
import 'graph.dart';
import 'sugiyama.dart';

const _padding = 24.0;
const _statePaddingX = 18.0;
const _statePaddingY = 10.0;
const _minStateWidth = 80.0;
const _minStateHeight = 36.0;
const _nodeSpacing = 40.0;
const _layerSpacing = 50.0;
const _pseudoRadius = 8.0;
const _historyRadius = 10.0;
const _clusterPadding = 16.0;
const _clusterTitleHeight = 22.0;
const _compositeBodyPad = _clusterPadding;
const _regionGap = 10.0;
const _stateDescriptionDividerPad = 4.0;
const _stateDescriptionBottomPad = 8.0;

const _stateFill = Color(0xFFFEFCE8);
const _stateStroke = Color(0xFF000000);
const _compositeFill = Color(0xFFFFFFFF);

const _stateStyle = TextStyle(color: Color(0xFF000000), fontSize: 12);
const _stateDescriptionStyle = TextStyle(
  color: Color(0xFF000000),
  fontSize: 11,
);
const _compositeHeaderStyle = TextStyle(
  color: Color(0xFF000000),
  fontSize: 12,
  fontWeight: FontWeight.w600,
);
const _historyPseudoStyle = TextStyle(
  color: Color(0xFFFFFFFF),
  fontSize: 10,
  fontWeight: FontWeight.w700,
);
const _transitionLabelStyle = TextStyle(
  color: Color(0xFF000000),
  fontSize: 10,
);

enum _PseudoKind {
  initial,
  finalState,
  historyShallow,
  historyDeep,
  choice,
  fork,
  join,
}

/// Sugiyama-backed `StateDiagram` -> `Scene` pipeline. OPT-IN: callers route
/// here through the `useSugiyamaForStates` feature flag; the default state
/// layout in `state_layout.dart` is unchanged.
Scene layoutStateDiagramWithSugiyama(
  StateDiagram diagram,
  TextMeasurer measurer,
) {
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

  final plan = _StatePlan.build(diagram);
  final root = _layoutScope(
    diagram.states,
    plan.transitionsForScope(''),
    measurer,
    scope: '',
    plan: plan,
  );
  if (root.shapes.isEmpty) {
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

  final shapes = <SceneShape>[
    for (final s in root.shapes) _shiftShape(s, const Offset(_padding, _padding)),
  ];
  final width = root.size.width + _padding * 2;
  final height = root.size.height + _padding * 2;
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

/// Global plan that assigns every transition (top-level or nested) to the
/// scope where it should be laid out — the lowest-common-ancestor (LCA)
/// container of its two endpoints. A transition declared inside one composite
/// that references a state in a sibling composite is therefore lifted up to
/// their common ancestor (often the root), so it routes between the two
/// composites' shells rather than dangling inside the wrong one.
class _StatePlan {
  /// Scope path (`''` root, else `A`, `A/B`, …) -> transitions to lay out
  /// there. The path matches the `scope` string threaded through `_layoutScope`
  /// (root composites prefix-free, nested composites slash-joined).
  final Map<String, List<StateTransition>> _byScope;

  const _StatePlan(this._byScope);

  List<StateTransition> transitionsForScope(String scope) =>
      _byScope[scope] ?? const [];

  static _StatePlan build(StateDiagram diagram) {
    // Container path per state name: the slash-joined scope of its enclosing
    // composite (`''` for a top-level state; `A` for a child of composite A;
    // `A/B` for a child of nested composite B inside A). Concurrent regions
    // are opaque (their interior transitions are handled by the region's own
    // sub-layout), so we do not descend into them here for path mapping.
    final containerOf = <String, String>{};
    void mapStates(List<StateDecl> decls, String scope) {
      for (final d in decls) {
        containerOf[d.name] = scope;
        if (d.concurrentRegions.isEmpty) {
          final childScope = scope.isEmpty ? d.name : '$scope/${d.name}';
          mapStates(d.nestedStates, childScope);
        }
      }
    }
    mapStates(diagram.states, '');

    final byScope = <String, List<StateTransition>>{};
    void assign(StateTransition t, String declScope) {
      final scope = _lcaScope(t, declScope, containerOf);
      byScope.putIfAbsent(scope, () => <StateTransition>[]).add(t);
    }

    void walk(List<StateDecl> decls, String scope) {
      for (final d in decls) {
        if (d.concurrentRegions.isNotEmpty) {
          // Concurrent regions lay out their own nested transitions; skip.
          continue;
        }
        final childScope = scope.isEmpty ? d.name : '$scope/${d.name}';
        for (final t in d.nestedTransitions) {
          assign(t, childScope);
        }
        walk(d.nestedStates, childScope);
      }
    }

    for (final t in diagram.transitions) {
      assign(t, '');
    }
    walk(diagram.states, '');

    return _StatePlan(byScope);
  }

  /// LCA scope for a transition: the longest common scope prefix of both
  /// endpoints' container paths. Pseudo endpoints (`[*]`/`[H]`/`[H*]`) are
  /// scope-local, so they anchor to the declaring scope rather than lifting.
  static String _lcaScope(
    StateTransition t,
    String declScope,
    Map<String, String> containerOf,
  ) {
    final fromPseudo = _isPseudoRef(t.from);
    final toPseudo = _isPseudoRef(t.to);
    if (fromPseudo && toPseudo) return declScope;
    // For a pseudo endpoint, treat its path as the declaring scope.
    final fromPath = fromPseudo
        ? _scopeSegments(declScope)
        : _endpointScope(t.from, declScope, containerOf);
    final toPath = toPseudo
        ? _scopeSegments(declScope)
        : _endpointScope(t.to, declScope, containerOf);
    final common = <String>[];
    for (var i = 0; i < fromPath.length && i < toPath.length; i++) {
      if (fromPath[i] == toPath[i]) {
        common.add(fromPath[i]);
      } else {
        break;
      }
    }
    return common.join('/');
  }

  /// Container scope segments for a real-state endpoint. Falls back to the
  /// declaring scope when the name is unknown (e.g. declared only via a
  /// transition).
  static List<String> _endpointScope(
    String ref,
    String declScope,
    Map<String, String> containerOf,
  ) {
    final c = containerOf[ref];
    if (c == null) return _scopeSegments(declScope);
    return _scopeSegments(c);
  }

  static List<String> _scopeSegments(String scope) =>
      scope.isEmpty ? const [] : scope.split('/');
}

bool _isPseudoRef(String ref) =>
    ref == '[*]' || ref == '[H]' || ref == '[H*]';

/// Result of laying out one scope (the root, or one composite's interior) in
/// LOCAL coordinates with origin (0,0).
class _ScopeResult {
  /// Scene shapes in local coordinates (shells before nodes before routes).
  final List<SceneShape> shapes;

  /// Bounding size of the laid-out content.
  final Size size;

  /// Absolute-local rect of every descendant state/leaf reachable from this
  /// scope (keyed by state name), used by an ancestor scope to punch a
  /// cross-container edge through to a nested leaf.
  final Map<String, Rect> descendantRects;

  const _ScopeResult({
    required this.shapes,
    required this.size,
    required this.descendantRects,
  });
}

/// Recursively lays out one scope: leaf states, stereotype pseudo states, and
/// concurrent composites become sized nodes; each TRUE composite is laid out
/// as its OWN sub-graph (origin 0,0) and embedded as a single sized node whose
/// body carries the translated interior sub-scene. Transitions are lifted to
/// this scope's direct children (LCA scoping); cross-container edges that
/// originally targeted a nested leaf are reconciled after placement so the
/// arrow punches through to that leaf's absolute position.
_ScopeResult _layoutScope(
  List<StateDecl> states,
  List<StateTransition> transitions,
  TextMeasurer measurer, {
  required String scope,
  required _StatePlan plan,
}) {
  final builder = _ScopeBuilder(measurer, scope, plan);
  builder.collect(states, transitions);
  final graph = builder.build();
  if (graph.nodes.isEmpty) {
    return const _ScopeResult(
      shapes: [],
      size: Size.zero,
      descendantRects: {},
    );
  }

  final result = runSugiyama(
    graph,
    coordinatesConfig: const CoordinatesConfig(
      nodeSpacing: _nodeSpacing,
      layerSpacing: _layerSpacing,
      clusterPadding: _clusterPadding,
      clusterTitleHeight: _clusterTitleHeight,
    ),
  );
  final coords = result.coordinates;

  // Mutable positions: horizontal (`left`/`right`) edges pull their dst into
  // the src's row and place it on the direction-implied side.
  final xByNode = Map<String, double>.from(coords.xByNode);
  final yByNode = Map<String, double>.from(coords.yByNode);
  _applyHorizontalPlacement(builder, xByNode, yByNode);

  final shapes = <SceneShape>[];
  final descendantRects = <String, Rect>{};

  // --- Nodes (and composite interiors) -------------------------------------
  // Composite shells/headers and their translated interiors are emitted as
  // part of the node pass so they paint before routes (preserving z-order).
  for (final node in graph.nodes) {
    final cx = xByNode[node.id];
    final cy = yByNode[node.id];
    if (cx == null || cy == null) continue;
    final center = Offset(cx, cy);
    final info = builder.infoById[node.id]!;
    final rect = Rect.fromCenter(
      center: center,
      width: info.width,
      height: info.height,
    );
    descendantRects[node.id] = rect;
    final composite = info.composite;
    if (composite != null) {
      // Embed the recursive interior: shell + header + descriptions + divider,
      // then translate the interior sub-scene into the body. Mirrors the
      // concurrent-composite embedding.
      _emitCompositeShell(shapes, info, rect, measurer);
      // Center the interior horizontally in the body; the body top sits below
      // the header/description inset.
      final innerX =
          rect.left + (rect.width - composite.interior.size.width) / 2;
      final innerBy = Offset(innerX, rect.top + info.bodyTop);
      for (final s in composite.interior.shapes) {
        shapes.add(_shiftShape(s, innerBy));
      }
      // Project descendant rects to this scope's coordinate space so an
      // ancestor edge can punch through to a deeply nested leaf.
      composite.interior.descendantRects.forEach((name, r) {
        descendantRects[name] = r.shift(innerBy);
      });
      continue;
    }
    _emitNode(shapes, info, center, measurer);
  }

  // --- Routes --------------------------------------------------------------
  for (final route in result.edgeRoutes.routes) {
    if (route.points.length < 2) continue;
    var pts = route.points.toList();
    final edgeInfo = builder.edgeInfoById[route.edgeId];
    if (edgeInfo == null) {
      _emitRoute(shapes, pts, null, measurer);
      continue;
    }
    // Source reconciliation.
    pts = _reconcileEnd(
      pts,
      head: false,
      targetName: edgeInfo.srcOriginal,
      directChildId: edgeInfo.src,
      descendantRects: descendantRects,
    );
    // Destination reconciliation.
    pts = _reconcileEnd(
      pts,
      head: true,
      targetName: edgeInfo.dstOriginal,
      directChildId: edgeInfo.dst,
      descendantRects: descendantRects,
    );
    if (pts.length < 2) continue;
    _emitRoute(shapes, pts, edgeInfo, measurer);
  }

  // --- Horizontal (left/right) routes --------------------------------------
  // Routed as a straight segment between the two endpoint rects, clipped to
  // each rect's boundary (punching through to a nested leaf when needed).
  for (final h in builder.horizontalEdges) {
    final srcRect = descendantRects[h.srcOriginal ?? h.src];
    final dstRect = descendantRects[h.dstOriginal ?? h.dst];
    if (srcRect == null || dstRect == null) continue;
    final start = _clipPointIntoRect(dstRect.center, srcRect.center, srcRect);
    final end = _clipPointIntoRect(srcRect.center, dstRect.center, dstRect);
    final pts = <Offset>[start, end];
    _emitRoute(
      shapes,
      pts,
      _EdgeInfo(label: h.label, src: h.src, dst: h.dst),
      measurer,
    );
  }

  // Horizontal placement may have pushed content past the original layout
  // bounds (or, for `left`, into negative x), so recompute the bounding box
  // over all shapes and normalize the origin to (0,0).
  if (builder.horizontalEdges.isEmpty) {
    return _ScopeResult(
      shapes: shapes,
      size: Size(coords.totalWidth, coords.totalHeight),
      descendantRects: descendantRects,
    );
  }
  final bounds = _shapesBounds(shapes);
  if (bounds == null) {
    return _ScopeResult(
      shapes: shapes,
      size: Size(coords.totalWidth, coords.totalHeight),
      descendantRects: descendantRects,
    );
  }
  final shift = Offset(-bounds.left, -bounds.top);
  final normShapes = <SceneShape>[
    for (final s in shapes) _shiftShape(s, shift),
  ];
  final normRects = <String, Rect>{
    for (final e in descendantRects.entries) e.key: e.value.shift(shift),
  };
  return _ScopeResult(
    shapes: normShapes,
    size: bounds.size,
    descendantRects: normRects,
  );
}

/// Axis-aligned bounding box over every shape's extent; null when [shapes] is
/// empty or contributes no finite geometry.
Rect? _shapesBounds(List<SceneShape> shapes) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  void include(Offset p) {
    if (p.dx < minX) minX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy > maxY) maxY = p.dy;
  }

  void includeRect(Rect r) {
    include(r.topLeft);
    include(r.bottomRight);
  }

  for (final s in shapes) {
    switch (s) {
      case SceneRoundedBox():
        includeRect(s.rect);
      case SceneBox():
        includeRect(s.rect);
      case SceneDiamond():
        includeRect(s.rect);
      case SceneCircle():
        includeRect(Rect.fromCircle(center: s.center, radius: s.radius));
      case SceneLine():
        include(s.from);
        include(s.to);
      case SceneText():
        include(s.offset);
      default:
        break;
    }
  }
  if (!minX.isFinite || !minY.isFinite) return null;
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Places each horizontal (`left`/`right`) edge's destination in the SAME row
/// as its source (dst.y := src.y) and directly adjacent on the implied side
/// (right => dst right of src; left => dst left of src), so the rendered arrow
/// is a short straight segment. Mutates [xByNode]/[yByNode] in place.
void _applyHorizontalPlacement(
  _ScopeBuilder builder,
  Map<String, double> xByNode,
  Map<String, double> yByNode,
) {
  for (final h in builder.horizontalEdges) {
    final sx = xByNode[h.src];
    final sy = yByNode[h.src];
    if (sx == null || sy == null) continue;
    final srcInfo = builder.infoById[h.src];
    final dstInfo = builder.infoById[h.dst];
    if (srcInfo == null || dstInfo == null) continue;
    final gap = srcInfo.width / 2 + _nodeSpacing + dstInfo.width / 2;
    yByNode[h.dst] = sy;
    xByNode[h.dst] = h.rightward ? sx + gap : sx - gap;
  }
}

/// Reconcile one end of a route. When [targetName] names a nested leaf reached
/// THROUGH a composite [directChildId], redirect the route's terminal point to
/// that leaf's absolute center (clipped to its rect) so the arrow punches into
/// the leaf. When [targetName] is null (the direct child IS the endpoint), trim
/// the route so it terminates on the direct child's boundary.
List<Offset> _reconcileEnd(
  List<Offset> pts, {
  required bool head,
  required String? targetName,
  required String directChildId,
  required Map<String, Rect> descendantRects,
}) {
  if (targetName == null || targetName == directChildId) {
    // The composite itself is the endpoint: terminate on its boundary.
    final box = descendantRects[directChildId];
    if (box == null) return pts;
    return head ? _clipTailToBoundary(pts, box) : _clipHeadToBoundary(pts, box);
  }
  // Punch through to the nested leaf's absolute rect.
  final leaf = descendantRects[targetName];
  if (leaf == null) {
    final box = descendantRects[directChildId];
    if (box == null) return pts;
    return head ? _clipTailToBoundary(pts, box) : _clipHeadToBoundary(pts, box);
  }
  final out = pts.toList();
  if (head) {
    final prev = out[out.length - 2];
    final target = _clipPointIntoRect(prev, leaf.center, leaf);
    out[out.length - 1] = target;
  } else {
    final next = out[1];
    final target = _clipPointIntoRect(next, leaf.center, leaf);
    out[0] = target;
  }
  return out;
}

/// Point on the boundary of [rect] along the segment from [from] toward
/// [rect.center]; falls back to the center if the segment doesn't cross.
Offset _clipPointIntoRect(Offset from, Offset center, Rect rect) {
  final hit = _segmentRectCrossing(from, center, rect);
  return hit ?? center;
}

/// Emits a composite shell: rounded box, centered header, divider, and any
/// description lines below the divider (inside the reserved top inset).
void _emitCompositeShell(
  List<SceneShape> shapes,
  _NodeInfo info,
  Rect rect,
  TextMeasurer measurer,
) {
  shapes.add(SceneRoundedBox(
    rect: rect,
    textStyle: _compositeHeaderStyle,
    fill: _compositeFill,
    stroke: _stateStroke,
    cornerRadius: 12.0,
  ));
  final label = info.label;
  if (label.isNotEmpty) {
    final headerSize = measurer.measure(label, _compositeHeaderStyle);
    shapes.add(SceneText(
      offset: Offset(
        rect.center.dx - headerSize.width / 2,
        rect.top + (_clusterTitleHeight - headerSize.height) / 2,
      ),
      text: label,
      textStyle: _compositeHeaderStyle,
    ));
  }
  shapes.add(SceneLine(
    from: Offset(rect.left, rect.top + _clusterTitleHeight),
    to: Offset(rect.right, rect.top + _clusterTitleHeight),
    head: null,
    stroke: _stateStroke,
  ));
  if (info.descriptions.isNotEmpty) {
    var y = rect.top + _clusterTitleHeight + _stateDescriptionDividerPad;
    for (var i = 0; i < info.descriptions.length; i++) {
      shapes.add(SceneText(
        offset: Offset(rect.left + _statePaddingX, y),
        text: info.descriptions[i],
        textStyle: _stateDescriptionStyle,
      ));
      y += info.descriptionSizes[i].height;
    }
  }
}

/// Trim the tail of [pts] so it ends on the boundary of [box] (the dst end was
/// redirected to a node inside the composite). Returns the prefix outside the
/// box plus the boundary crossing point.
List<Offset> _clipTailToBoundary(List<Offset> pts, Rect box) {
  for (var i = pts.length - 2; i >= 0; i--) {
    if (!_rectContains(box, pts[i])) {
      final hit = _segmentRectCrossing(pts[i], pts[i + 1], box);
      final head = pts.sublist(0, i + 1);
      head.add(hit ?? pts[i + 1]);
      return head;
    }
  }
  return pts;
}

/// Trim the head of [pts] so it starts on the boundary of [box] (the src end
/// was redirected to a node inside the composite).
List<Offset> _clipHeadToBoundary(List<Offset> pts, Rect box) {
  for (var i = 1; i < pts.length; i++) {
    if (!_rectContains(box, pts[i])) {
      final hit = _segmentRectCrossing(pts[i], pts[i - 1], box);
      final tail = <Offset>[hit ?? pts[i - 1]];
      tail.addAll(pts.sublist(i));
      return tail;
    }
  }
  return pts;
}

bool _rectContains(Rect r, Offset p) =>
    p.dx >= r.left && p.dx <= r.right && p.dy >= r.top && p.dy <= r.bottom;

/// The point where the segment from [outside] toward [inside] first meets the
/// boundary of [box], via Liang–Barsky. Null if the segment never crosses.
Offset? _segmentRectCrossing(Offset outside, Offset inside, Rect box) {
  final dx = inside.dx - outside.dx;
  final dy = inside.dy - outside.dy;
  var tEnter = 0.0;
  final p = [-dx, dx, -dy, dy];
  final q = [
    outside.dx - box.left,
    box.right - outside.dx,
    outside.dy - box.top,
    box.bottom - outside.dy,
  ];
  for (var i = 0; i < 4; i++) {
    if (p[i] == 0) {
      if (q[i] < 0) return null;
    } else {
      final t = q[i] / p[i];
      if (p[i] < 0) {
        if (t > tEnter) tEnter = t;
      }
    }
  }
  if (tEnter <= 0 || tEnter > 1) return null;
  return Offset(outside.dx + tEnter * dx, outside.dy + tEnter * dy);
}

class _NodeInfo {
  final String id;
  final double width;
  final double height;
  final String label;
  final _PseudoKind? pseudoKind;
  /// PlantUML `A : foo` description lines for this leaf/composite state.
  final List<String> descriptions;
  final List<Size> descriptionSizes;
  /// Title text height (measured with `_stateStyle`).
  final double titleHeight;
  /// Non-null when this node is a concurrent composite.
  final _ConcurrentLayout? concurrent;
  /// Non-null when this node is a TRUE (sequential) composite laid out
  /// recursively.
  final _CompositeLayout? composite;
  /// Y offset (from the node top) at which the body content begins — title
  /// row plus any description block.
  final double bodyTop;

  const _NodeInfo({
    required this.id,
    required this.width,
    required this.height,
    required this.label,
    this.pseudoKind,
    this.descriptions = const [],
    this.descriptionSizes = const [],
    this.titleHeight = 0.0,
    this.concurrent,
    this.composite,
    this.bodyTop = 0.0,
  });
}

/// Pre-laid concurrent-composite body: per-region sub-shapes and their offsets
/// (relative to the node top-left), plus region divider segments.
class _ConcurrentLayout {
  final List<List<SceneShape>> regionShapes;
  final List<Offset> regionOffsets;
  final List<({Offset from, Offset to})> dividers;
  final String label;

  const _ConcurrentLayout({
    required this.regionShapes,
    required this.regionOffsets,
    required this.dividers,
    required this.label,
  });
}

/// Pre-laid TRUE-composite interior: the recursive scope result for the
/// composite's nested states/transitions.
class _CompositeLayout {
  final _ScopeResult interior;
  const _CompositeLayout({required this.interior});
}

class _EdgeInfo {
  final String? label;
  /// The direct-child node id of the scope this edge's source/destination
  /// resolves to (a leaf, composite, or pseudo node).
  final String src;
  final String dst;
  /// When the source/destination originally named a nested leaf reached
  /// THROUGH a composite, this is that leaf's name so the route can be punched
  /// through after placement. Null when the direct child IS the endpoint.
  final String? srcOriginal;
  final String? dstOriginal;
  const _EdgeInfo({
    this.label,
    required this.src,
    required this.dst,
    this.srcOriginal,
    this.dstOriginal,
  });
}

/// A horizontal (`->` / `-left->` / `-right->`) transition routed by the
/// adapter after coordinates are assigned, rather than as a ranking edge.
class _HorizontalEdge {
  final String src;
  final String dst;
  final String? srcOriginal;
  final String? dstOriginal;
  final String? label;
  /// True for `right` (dst to the RIGHT of src); false for `left`.
  final bool rightward;
  const _HorizontalEdge({
    required this.src,
    required this.dst,
    this.srcOriginal,
    this.dstOriginal,
    this.label,
    required this.rightward,
  });
}

/// Builds the flat Sugiyama graph for ONE scope: leaf/pseudo/concurrent nodes
/// plus recursively-embedded composite nodes, with edges lifted to the scope's
/// direct children.
class _ScopeBuilder {
  final TextMeasurer measurer;

  /// Scope id used to make this scope's pseudo states distinct from siblings.
  final String scope;

  /// Global LCA plan, threaded to child composites for their sub-layouts.
  final _StatePlan plan;

  final Map<String, _NodeInfo> infoById = <String, _NodeInfo>{};
  final Map<String, _EdgeInfo> edgeInfoById = <String, _EdgeInfo>{};
  final List<GraphEdge> _edges = <GraphEdge>[];

  /// Horizontal (`left`/`right`) edges, routed after placement so they don't
  /// force a layer difference between their endpoints.
  final List<_HorizontalEdge> horizontalEdges = <_HorizontalEdge>[];

  /// Maps every descendant state name (at any depth) to the direct-child node
  /// id of this scope that encloses it. Direct children map to themselves.
  final Map<String, String> _directChildOf = <String, String>{};

  int _edgeSeq = 0;

  _ScopeBuilder(this.measurer, this.scope, this.plan);

  void collect(List<StateDecl> states, List<StateTransition> transitions) {
    for (final decl in states) {
      _addDirectChild(decl);
    }
    for (final t in transitions) {
      _addEdge(t);
    }
  }

  /// Add a direct child of this scope as a single sized node, recording the
  /// names of all descendants so transitions targeting a nested leaf can be
  /// lifted to this child.
  void _addDirectChild(StateDecl decl) {
    if (infoById.containsKey(decl.name)) return;
    final stereo = _pseudoKindFromStereotype(decl.stereotype);
    if (stereo != null) {
      _addStereotypePseudo(decl.name, stereo);
      _directChildOf[decl.name] = decl.name;
      return;
    }
    final hasNested =
        decl.nestedStates.isNotEmpty || decl.nestedTransitions.isNotEmpty;
    final hasConcurrent = decl.concurrentRegions.isNotEmpty;
    if (hasConcurrent) {
      _addConcurrentNode(decl);
      _recordDescendants(decl, decl.name);
      return;
    }
    if (hasNested) {
      _addCompositeNode(decl);
      _recordDescendants(decl, decl.name);
      return;
    }
    _addLeafNode(decl);
    _directChildOf[decl.name] = decl.name;
  }

  /// Record every descendant state name under [decl] as enclosed by the
  /// direct-child [childId].
  void _recordDescendants(StateDecl decl, String childId) {
    _directChildOf[decl.name] = childId;
    for (final c in decl.nestedStates) {
      _recordDescendants(c, childId);
    }
    for (final region in decl.concurrentRegions) {
      for (final c in region) {
        _recordDescendants(c, childId);
      }
    }
  }

  /// True composite: lay out its interior recursively and wrap as a sized node
  /// whose size = interior size + header/description inset + body padding.
  void _addCompositeNode(StateDecl decl) {
    final childScope = scope.isEmpty ? decl.name : '$scope/${decl.name}';
    final interior = _layoutScope(
      decl.nestedStates,
      plan.transitionsForScope(childScope),
      measurer,
      scope: childScope,
      plan: plan,
    );

    final headerSize = measurer.measure(decl.label, _compositeHeaderStyle);
    final descSizes = <Size>[];
    var descBlockHeight = 0.0;
    for (final d in decl.descriptions) {
      final s = measurer.measure(d, _stateDescriptionStyle);
      descSizes.add(s);
      descBlockHeight += s.height;
    }
    var bodyTop = _clusterTitleHeight;
    if (decl.descriptions.isNotEmpty) {
      bodyTop = _clusterTitleHeight +
          _stateDescriptionDividerPad +
          descBlockHeight +
          _stateDescriptionBottomPad;
    }
    bodyTop += _compositeBodyPad;

    final innerW = interior.size.width;
    final innerH = interior.size.height;
    final width = math.max(
      math.max(_minStateWidth, headerSize.width + _statePaddingX * 2),
      innerW + _compositeBodyPad * 2,
    );
    final height = bodyTop + innerH + _compositeBodyPad;

    infoById[decl.name] = _NodeInfo(
      id: decl.name,
      width: width,
      height: height,
      label: decl.label,
      descriptions: decl.descriptions,
      descriptionSizes: descSizes,
      titleHeight: headerSize.height,
      composite: _CompositeLayout(interior: interior),
      bodyTop: bodyTop,
    );
  }

  void _addEdge(StateTransition t) {
    final from = _resolveEndpoint(t.from, source: true);
    final to = _resolveEndpoint(t.to, source: false);
    if (from == null || to == null) return;
    if (from.directChild == to.directChild) return;
    final dir = t.direction ?? StateArrowDirection.down;
    // Horizontal edges are NON-RANKING: collect them for post-placement
    // routing so they don't force a layer difference.
    if (dir == StateArrowDirection.left || dir == StateArrowDirection.right) {
      horizontalEdges.add(_HorizontalEdge(
        src: from.directChild,
        dst: to.directChild,
        srcOriginal: from.nestedTarget,
        dstOriginal: to.nestedTarget,
        label: t.label,
        rightward: dir == StateArrowDirection.right,
      ));
      return;
    }
    final id = 'e${_edgeSeq++}';
    // `up` ranks the destination ABOVE the source: feed layering a reversed
    // edge (so dst lands in an earlier layer) while routing keeps the visible
    // arrowhead on the logical dst.
    final reversed = dir == StateArrowDirection.up;
    _edges.add(GraphEdge(
      id: id,
      src: from.directChild,
      dst: to.directChild,
      isReversed: reversed,
    ));
    edgeInfoById[id] = _EdgeInfo(
      label: t.label,
      src: from.directChild,
      dst: to.directChild,
      srcOriginal: from.nestedTarget,
      dstOriginal: to.nestedTarget,
    );
  }

  /// Resolve a transition endpoint [ref] to the direct-child node id of this
  /// scope, plus (when the ref names a nested leaf) the original target name.
  ({String directChild, String? nestedTarget})? _resolveEndpoint(
    String ref, {
    required bool source,
  }) {
    if (ref == '[*]' || ref == '[H]' || ref == '[H*]') {
      final id = _ensureScopedPseudo(ref, source: source);
      return (directChild: id, nestedTarget: null);
    }
    final direct = _directChildOf[ref];
    if (direct == null) {
      // Unknown reference (e.g. a state declared only via a transition with no
      // decl). Materialize it as a leaf so the edge still participates.
      if (!infoById.containsKey(ref)) {
        _addLeafNode(StateDecl(name: ref));
        _directChildOf[ref] = ref;
      }
      return (directChild: ref, nestedTarget: null);
    }
    final nestedTarget = direct == ref ? null : ref;
    return (directChild: direct, nestedTarget: nestedTarget);
  }

  /// Materialise a scope-local `[*]`/`[H]`/`[H*]` pseudo node once.
  String _ensureScopedPseudo(String ref, {required bool source}) {
    final _PseudoKind kind;
    final String base;
    switch (ref) {
      case '[*]':
        kind = source ? _PseudoKind.initial : _PseudoKind.finalState;
        base = source ? '[*]:initial' : '[*]:final';
      case '[H]':
        kind = _PseudoKind.historyShallow;
        base = '[H]';
      case '[H*]':
        kind = _PseudoKind.historyDeep;
        base = '[H*]';
      default:
        kind = _PseudoKind.initial;
        base = ref;
    }
    final id = scope.isEmpty ? base : '$base@$scope';
    if (!infoById.containsKey(id)) {
      final r = (kind == _PseudoKind.historyShallow ||
              kind == _PseudoKind.historyDeep)
          ? _historyRadius
          : _pseudoRadius;
      infoById[id] = _NodeInfo(
        id: id,
        width: r * 2,
        height: r * 2,
        label: '',
        pseudoKind: kind,
      );
      _directChildOf[id] = id;
    }
    return id;
  }

  Graph build() {
    final nodes = <GraphNode>[
      for (final info in infoById.values)
        GraphNode(
          id: info.id,
          width: info.width,
          height: info.height,
          label: info.label,
        ),
    ];
    return Graph(
      nodes: nodes,
      edges: List.unmodifiable(_edges),
    );
  }

  void _addLeafNode(StateDecl decl) {
    final titleSize = measurer.measure(decl.label, _stateStyle);
    final showDescriptions = decl.descriptions.isNotEmpty;
    var contentWidth = titleSize.width;
    var descBlockHeight = 0.0;
    final descSizes = <Size>[];
    if (showDescriptions) {
      for (final d in decl.descriptions) {
        final s = measurer.measure(d, _stateDescriptionStyle);
        descSizes.add(s);
        if (s.width > contentWidth) contentWidth = s.width;
        descBlockHeight += s.height;
      }
    }
    final width = math.max(_minStateWidth, contentWidth + _statePaddingX * 2);
    var height = math.max(_minStateHeight, titleSize.height + _statePaddingY * 2);
    if (showDescriptions) {
      height = _statePaddingY +
          titleSize.height +
          _stateDescriptionDividerPad * 2 +
          descBlockHeight +
          _stateDescriptionBottomPad;
    }
    infoById[decl.name] = _NodeInfo(
      id: decl.name,
      width: width,
      height: height,
      label: decl.label,
      descriptions: showDescriptions ? decl.descriptions : const [],
      descriptionSizes: showDescriptions ? descSizes : const [],
      titleHeight: titleSize.height,
    );
  }

  /// Concurrent composite: lays out each region as its own sub-graph, stacks
  /// them (vertically by default, horizontally for `||`) inside a single node.
  void _addConcurrentNode(StateDecl decl) {
    final headerSize = measurer.measure(decl.label, _compositeHeaderStyle);
    final horizontal = decl.horizontalRegions;

    final regionShapesList = <List<SceneShape>>[];
    final regionSizes = <Size>[];
    for (final region in decl.concurrentRegions) {
      final relevant = decl.nestedTransitions
          .where((t) =>
              _isInRegion(t.from, region) && _isInRegion(t.to, region))
          .toList(growable: false);
      // A region is an independent sub-diagram: build its own LCA plan so any
      // composites nested inside the region lay out recursively too.
      final regionPlan = _StatePlan.build(
        StateDiagram(states: region, transitions: relevant),
      );
      final laid = _layoutScope(
        region,
        regionPlan.transitionsForScope(''),
        measurer,
        scope: '',
        plan: regionPlan,
      );
      regionShapesList.add(laid.shapes);
      regionSizes.add(laid.size);
    }

    final n = regionSizes.length;
    final regionOffsets = <Offset>[];
    final dividers = <({Offset from, Offset to})>[];
    final bodyTop = _clusterTitleHeight + _compositeBodyPad;

    double width;
    double height;
    if (!horizontal) {
      var maxRegionWidth = 0.0;
      for (final s in regionSizes) {
        if (s.width > maxRegionWidth) maxRegionWidth = s.width;
      }
      width = math.max(
        math.max(_minStateWidth, headerSize.width + _statePaddingX * 2),
        maxRegionWidth + _compositeBodyPad * 2,
      );
      var sumHeights = 0.0;
      for (final s in regionSizes) {
        sumHeights += s.height;
      }
      height = _clusterTitleHeight +
          _compositeBodyPad * 2 +
          sumHeights +
          _regionGap * 2 * (n - 1);
      final innerWidth = width - _compositeBodyPad * 2;
      var y = bodyTop;
      for (var i = 0; i < n; i++) {
        regionOffsets.add(Offset(_compositeBodyPad, y));
        y += regionSizes[i].height;
        if (i < n - 1) {
          final dy = y + _regionGap;
          dividers.add((
            from: Offset(_compositeBodyPad, dy),
            to: Offset(_compositeBodyPad + innerWidth, dy),
          ));
          y += _regionGap * 2;
        }
      }
    } else {
      var maxRegionHeight = 0.0;
      for (final s in regionSizes) {
        if (s.height > maxRegionHeight) maxRegionHeight = s.height;
      }
      height = _clusterTitleHeight + _compositeBodyPad * 2 + maxRegionHeight;
      var sumWidths = 0.0;
      for (final s in regionSizes) {
        sumWidths += s.width;
      }
      width = math.max(
        math.max(_minStateWidth, headerSize.width + _statePaddingX * 2),
        sumWidths + _compositeBodyPad * 2 + _regionGap * 2 * (n - 1),
      );
      final innerHeight = height - bodyTop - _compositeBodyPad;
      var x = _compositeBodyPad;
      for (var i = 0; i < n; i++) {
        regionOffsets.add(Offset(x, bodyTop));
        x += regionSizes[i].width;
        if (i < n - 1) {
          final dx = x + _regionGap;
          dividers.add((
            from: Offset(dx, bodyTop),
            to: Offset(dx, bodyTop + innerHeight),
          ));
          x += _regionGap * 2;
        }
      }
    }

    infoById[decl.name] = _NodeInfo(
      id: decl.name,
      width: width,
      height: height,
      label: decl.label,
      titleHeight: headerSize.height,
      concurrent: _ConcurrentLayout(
        regionShapes: regionShapesList,
        regionOffsets: regionOffsets,
        dividers: dividers,
        label: decl.label,
      ),
    );
  }

  /// True when [ref] belongs to [region] (or is the `[*]` pseudo).
  bool _isInRegion(String ref, List<StateDecl> region) {
    if (ref == '[*]') return true;
    for (final s in region) {
      if (s.name == ref) return true;
    }
    return false;
  }

  void _addStereotypePseudo(String name, _PseudoKind kind) {
    switch (kind) {
      case _PseudoKind.choice:
        infoById[name] = _NodeInfo(
          id: name,
          width: 24,
          height: 24,
          label: '',
          pseudoKind: kind,
        );
        return;
      case _PseudoKind.fork:
      case _PseudoKind.join:
        infoById[name] = _NodeInfo(
          id: name,
          width: 60,
          height: 8,
          label: '',
          pseudoKind: kind,
        );
        return;
      case _PseudoKind.initial:
      case _PseudoKind.finalState:
      case _PseudoKind.historyShallow:
      case _PseudoKind.historyDeep:
        final r = (kind == _PseudoKind.historyShallow ||
                kind == _PseudoKind.historyDeep)
            ? _historyRadius
            : _pseudoRadius;
        infoById[name] = _NodeInfo(
          id: name,
          width: r * 2,
          height: r * 2,
          label: '',
          pseudoKind: kind,
        );
        return;
    }
  }
}

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

void _emitNode(
  List<SceneShape> shapes,
  _NodeInfo info,
  Offset center,
  TextMeasurer measurer,
) {
  final rect = Rect.fromCenter(
    center: center,
    width: info.width,
    height: info.height,
  );
  final concurrent = info.concurrent;
  if (concurrent != null) {
    final topLeft = rect.topLeft;
    shapes.add(SceneRoundedBox(
      rect: rect,
      textStyle: _compositeHeaderStyle,
      fill: _compositeFill,
      stroke: _stateStroke,
      cornerRadius: 12.0,
    ));
    if (concurrent.label.isNotEmpty) {
      final hs = measurer.measure(concurrent.label, _compositeHeaderStyle);
      shapes.add(SceneText(
        offset: Offset(
          rect.center.dx - hs.width / 2,
          rect.top + (_clusterTitleHeight - hs.height) / 2,
        ),
        text: concurrent.label,
        textStyle: _compositeHeaderStyle,
      ));
    }
    shapes.add(SceneLine(
      from: Offset(rect.left, rect.top + _clusterTitleHeight),
      to: Offset(rect.right, rect.top + _clusterTitleHeight),
      head: null,
      stroke: _stateStroke,
    ));
    for (var i = 0; i < concurrent.regionShapes.length; i++) {
      final by = topLeft + concurrent.regionOffsets[i];
      for (final s in concurrent.regionShapes[i]) {
        shapes.add(_shiftShape(s, by));
      }
    }
    for (final d in concurrent.dividers) {
      shapes.add(SceneLine(
        from: d.from + topLeft,
        to: d.to + topLeft,
        head: null,
        dashed: true,
        stroke: _stateStroke,
      ));
    }
    return;
  }
  final pseudo = info.pseudoKind;
  if (pseudo != null) {
    switch (pseudo) {
      case _PseudoKind.choice:
        shapes.add(SceneDiamond(
          rect: rect,
          textStyle: _stateStyle,
          fill: _stateFill,
          stroke: _stateStroke,
        ));
        return;
      case _PseudoKind.fork:
      case _PseudoKind.join:
        shapes.add(SceneBox(
          rect: rect,
          textStyle: _stateStyle,
          fill: const Color(0xFF000000),
          stroke: const Color(0xFF000000),
        ));
        return;
      case _PseudoKind.historyShallow:
      case _PseudoKind.historyDeep:
        shapes.add(SceneCircle(
          center: center,
          radius: _historyRadius,
          fill: const Color(0xFF000000),
          stroke: const Color(0xFF000000),
        ));
        final letter = pseudo == _PseudoKind.historyDeep ? 'H*' : 'H';
        final size = measurer.measure(letter, _historyPseudoStyle);
        shapes.add(SceneText(
          offset: Offset(
            center.dx - size.width / 2,
            center.dy - size.height / 2,
          ),
          text: letter,
          textStyle: _historyPseudoStyle,
        ));
        return;
      case _PseudoKind.initial:
      case _PseudoKind.finalState:
        shapes.add(SceneCircle(
          center: center,
          radius: _pseudoRadius,
          fill: const Color(0xFF000000),
          stroke: const Color(0xFF000000),
          ring: pseudo == _PseudoKind.finalState,
        ));
        return;
    }
  }
  if (info.descriptions.isEmpty) {
    shapes.add(SceneRoundedBox(
      rect: rect,
      label: info.label,
      textStyle: _stateStyle,
      fill: _stateFill,
      stroke: _stateStroke,
      cornerRadius: 12.0,
    ));
    return;
  }
  shapes.add(SceneRoundedBox(
    rect: rect,
    textStyle: _stateStyle,
    fill: _stateFill,
    stroke: _stateStroke,
    cornerRadius: 12.0,
  ));
  final titleSize = measurer.measure(info.label, _stateStyle);
  shapes.add(SceneText(
    offset: Offset(
      rect.center.dx - titleSize.width / 2,
      rect.top + _statePaddingY,
    ),
    text: info.label,
    textStyle: _stateStyle,
  ));
  final dividerY = rect.top +
      _statePaddingY +
      info.titleHeight +
      _stateDescriptionDividerPad;
  shapes.add(SceneLine(
    from: Offset(rect.left, dividerY),
    to: Offset(rect.right, dividerY),
    head: null,
    stroke: _stateStroke,
  ));
  var y = dividerY + _stateDescriptionDividerPad;
  for (var i = 0; i < info.descriptions.length; i++) {
    final ds = info.descriptionSizes[i];
    shapes.add(SceneText(
      offset: Offset(rect.left + _statePaddingX, y),
      text: info.descriptions[i],
      textStyle: _stateDescriptionStyle,
    ));
    y += ds.height;
  }
}

void _emitRoute(
  List<SceneShape> shapes,
  List<Offset> points,
  _EdgeInfo? edgeInfo,
  TextMeasurer measurer,
) {
  for (var i = 0; i + 1 < points.length; i++) {
    final isLast = i + 2 == points.length;
    shapes.add(SceneLine(
      from: points[i],
      to: points[i + 1],
      head: isLast ? ArrowHead.open : null,
      stroke: _stateStroke,
    ));
  }
  final label = edgeInfo?.label;
  if (label != null && label.isNotEmpty) {
    final midIdx = points.length ~/ 2;
    final a = points[midIdx - 1];
    final b = points[midIdx];
    final size = measurer.measure(label, _transitionLabelStyle);
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    shapes.add(SceneText(
      offset: Offset(mid.dx + 4, mid.dy - size.height / 2),
      text: label,
      textStyle: _transitionLabelStyle,
    ));
  }
}

/// Returns a copy of [shape] translated by [by]. Handles every shape type a
/// sub-layout can emit; unknown types are returned unshifted.
SceneShape _shiftShape(SceneShape shape, Offset by) {
  switch (shape) {
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
    case SceneText():
      return SceneText(
        offset: shape.offset + by,
        text: shape.text,
        textStyle: shape.textStyle,
        maxWidth: shape.maxWidth,
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
    case SceneCircle():
      return SceneCircle(
        center: shape.center + by,
        radius: shape.radius,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
        ring: shape.ring,
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
    case SceneBox():
      return SceneBox(
        rect: shape.rect.shift(by),
        label: shape.label,
        textStyle: shape.textStyle,
        fill: shape.fill,
        stroke: shape.stroke,
        strokeWidth: shape.strokeWidth,
      );
    default:
      return shape;
  }
}
