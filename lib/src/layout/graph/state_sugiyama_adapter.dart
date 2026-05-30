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

  const pad = Offset(_padding, _padding);
  final shapes = <SceneShape>[
    for (final s in root.shapes) _shiftShape(s, pad),
  ];
  // Global label de-overlap: per-scope placement already cleared LOCAL
  // collisions, but labels emitted in DIFFERENT scopes can collide after
  // composition (e.g. a composite's self-loop label and an inner leaf's
  // self-loop label landing at the same spot). Now that every label, obstacle,
  // and self-loop rect lives in one absolute coordinate space, resolve any
  // remaining overlaps and rewrite only the labels that actually move.
  _globalLabelDeoverlap(
    shapes,
    labels: <_LabelSpec>[for (final l in root.labels) l.shift(pad)],
    obstacles: <Rect>[for (final r in root.obstacleRects) r.shift(pad)],
    measurer,
  );
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
/// A transition assigned to a layout scope, carrying any history endpoint
/// resolution (its owner-scoped node id) computed from the DECLARING scope so
/// the resolution survives lifting to the LCA layout scope.
class _ScopedTransition {
  final StateTransition transition;
  /// Resolved history node id for `from`/`to` when that endpoint is a history
  /// ref owned by a known composite; null otherwise.
  final _HistoryResolution? fromHistory;
  final _HistoryResolution? toHistory;
  const _ScopedTransition(this.transition, this.fromHistory, this.toHistory);
}

class _StatePlan {
  /// Scope path (`''` root, else `A`, `A/B`, …) -> transitions to lay out
  /// there. The path matches the `scope` string threaded through `_layoutScope`
  /// (root composites prefix-free, nested composites slash-joined).
  final Map<String, List<_ScopedTransition>> _byScope;

  /// Scope path -> the history pseudo nodes that scope OWNS (i.e. must
  /// materialize inside its interior even when no in-scope edge references
  /// them). Keyed by the resolved history node id (`[H]@<scope>` etc.).
  final Map<String, Map<String, _PseudoKind>> _ownedHistory;

  /// Interior scope path of every composite by name (`A` for top-level `A`,
  /// `A/B` for nested `B`). Used to resolve a history pseudo's owner.
  final Map<String, String> _interiorScopeOf;

  const _StatePlan(this._byScope, this._ownedHistory, this._interiorScopeOf);

  List<_ScopedTransition> transitionsForScope(String scope) =>
      _byScope[scope] ?? const [];

  /// History nodes owned by [scope] (resolved id -> kind); empty when none.
  Map<String, _PseudoKind> ownedHistoryForScope(String scope) =>
      _ownedHistory[scope] ?? const {};

  /// Every history node id owned at or below [scopePrefix] (the interior scope
  /// of a direct-child composite), so an ancestor builder can map those ids to
  /// that child for cross-boundary punch-through.
  List<String> historyIdsUnder(String scopePrefix) {
    final out = <String>[];
    _ownedHistory.forEach((scope, ids) {
      if (scope == scopePrefix || scope.startsWith('$scopePrefix/')) {
        out.addAll(ids.keys);
      }
    });
    return out;
  }

  /// Interior scope path of composite [name], or null when [name] is not a
  /// known composite (undeclared, a leaf, or a concurrent composite).
  String? interiorScopeOf(String name) => _interiorScopeOf[name];

  static _StatePlan build(StateDiagram diagram) {
    // Container path per state name: the slash-joined scope of its enclosing
    // composite (`''` for a top-level state; `A` for a child of composite A;
    // `A/B` for a child of nested composite B inside A). Concurrent regions
    // are opaque (their interior transitions are handled by the region's own
    // sub-layout), so we do not descend into them here for path mapping.
    final containerOf = <String, String>{};
    // Interior scope per composite name: a true (sequential) composite's
    // interior scope is its container scope joined with its own name.
    final interiorScopeOf = <String, String>{};
    void mapStates(List<StateDecl> decls, String scope) {
      for (final d in decls) {
        containerOf[d.name] = scope;
        if (d.concurrentRegions.isEmpty) {
          final childScope = scope.isEmpty ? d.name : '$scope/${d.name}';
          final hasNested =
              d.nestedStates.isNotEmpty || d.nestedTransitions.isNotEmpty;
          if (hasNested) interiorScopeOf[d.name] = childScope;
          mapStates(d.nestedStates, childScope);
        }
      }
    }
    mapStates(diagram.states, '');

    final ownedHistory = <String, Map<String, _PseudoKind>>{};
    void recordHistory(_HistoryResolution? h) {
      if (h == null) return;
      ownedHistory
          .putIfAbsent(h.ownerScope, () => <String, _PseudoKind>{})[h.id] =
          h.kind;
    }

    final byScope = <String, List<_ScopedTransition>>{};
    void assign(StateTransition t, String declScope) {
      final fromH = _resolveHistory(t.from, declScope, interiorScopeOf);
      final toH = _resolveHistory(t.to, declScope, interiorScopeOf);
      recordHistory(fromH);
      recordHistory(toH);
      final scope = _lcaScope(t, declScope, containerOf, interiorScopeOf);
      byScope
          .putIfAbsent(scope, () => <_ScopedTransition>[])
          .add(_ScopedTransition(t, fromH, toH));
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

    return _StatePlan(byScope, ownedHistory, interiorScopeOf);
  }

  /// LCA scope for a transition: the longest common scope prefix of both
  /// endpoints' container paths. A `[*]` pseudo endpoint is scope-local, so it
  /// anchors to the declaring scope. A history endpoint (`[H]`/`[H*]` or
  /// `Name[H]`/`Name[H*]`) anchors to its OWNING composite's interior scope so
  /// the transition lifts to the LCA of its source and the history's owner.
  static String _lcaScope(
    StateTransition t,
    String declScope,
    Map<String, String> containerOf,
    Map<String, String> interiorScopeOf,
  ) {
    final fromPath = _endpointLcaPath(t.from, declScope, containerOf,
        interiorScopeOf);
    final toPath =
        _endpointLcaPath(t.to, declScope, containerOf, interiorScopeOf);
    if (fromPath == null && toPath == null) return declScope;
    final from = fromPath ?? _scopeSegments(declScope);
    final to = toPath ?? _scopeSegments(declScope);
    final common = <String>[];
    for (var i = 0; i < from.length && i < to.length; i++) {
      if (from[i] == to[i]) {
        common.add(from[i]);
      } else {
        break;
      }
    }
    return common.join('/');
  }

  /// Scope-segment path used for LCA against an endpoint, or null when the
  /// endpoint is scope-local (a `[*]` pseudo) and should not constrain the LCA.
  static List<String>? _endpointLcaPath(
    String ref,
    String declScope,
    Map<String, String> containerOf,
    Map<String, String> interiorScopeOf,
  ) {
    if (ref == '[*]') return null;
    final h = _resolveHistory(ref, declScope, interiorScopeOf);
    if (h != null) return _scopeSegments(h.ownerScope);
    return _endpointScope(ref, declScope, containerOf);
  }

  /// Resolve a history endpoint [ref] to its owning composite's interior scope,
  /// stable node id, and kind. A bare `[H]`/`[H*]` is owned by its declaring
  /// composite [declScope]; a qualified `Name[H]`/`Name[H*]` is owned by
  /// `Name`. Returns null when [ref] is not a history ref or its owner is not a
  /// known composite (the caller then falls back to existing behavior).
  static _HistoryResolution? _resolveHistory(
    String ref,
    String declScope,
    Map<String, String> interiorScopeOf,
  ) {
    final _PseudoKind kind;
    final String ownerScope;
    if (ref == '[H]' || ref == '[H*]') {
      kind = ref == '[H*]'
          ? _PseudoKind.historyDeep
          : _PseudoKind.historyShallow;
      // A bare in-block history is owned by the composite it is declared in.
      if (declScope.isEmpty) return null;
      ownerScope = declScope;
    } else if (ref.endsWith('[H]') || ref.endsWith('[H*]')) {
      final deep = ref.endsWith('[H*]');
      kind =
          deep ? _PseudoKind.historyDeep : _PseudoKind.historyShallow;
      final owner = ref.substring(0, ref.length - (deep ? 4 : 3));
      final scope = interiorScopeOf[owner];
      if (scope == null) return null;
      ownerScope = scope;
    } else {
      return null;
    }
    final base = kind == _PseudoKind.historyDeep ? '[H*]' : '[H]';
    return _HistoryResolution(
      kind: kind,
      ownerScope: ownerScope,
      id: '$base@$ownerScope',
    );
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

/// True for a bare (`[H]`/`[H*]`) or qualified (`Name[H]`/`Name[H*]`) history
/// reference.
bool _isHistoryRef(String ref) => ref.endsWith('[H]') || ref.endsWith('[H*]');

/// A history endpoint resolved to its owning composite's interior scope, a
/// stable per-owner node id, and shallow/deep kind.
class _HistoryResolution {
  final _PseudoKind kind;
  final String ownerScope;
  final String id;
  const _HistoryResolution({
    required this.kind,
    required this.ownerScope,
    required this.id,
  });
}

/// An edge/transition label emitted in some scope, recorded so a global pass
/// (run once after the whole scene is composed in absolute coords) can detect
/// and resolve cross-scope overlaps. [rect] is the label's CURRENT bounding box
/// in this scope's local coords; [segStart]/[segEnd] are the route mid-segment
/// (also local) used to choose perpendicular/along-edge nudge directions.
class _LabelSpec {
  final String text;
  final Rect rect;
  final Offset segStart;
  final Offset segEnd;
  const _LabelSpec({
    required this.text,
    required this.rect,
    required this.segStart,
    required this.segEnd,
  });

  _LabelSpec shift(Offset by) => _LabelSpec(
        text: text,
        rect: rect.shift(by),
        segStart: segStart + by,
        segEnd: segEnd + by,
      );
}

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

  /// Every edge label emitted in this scope (or lifted from a child), in local
  /// coords. Threaded up for the top-level global de-overlap pass.
  final List<_LabelSpec> labels;

  /// Every obstacle rect (node/leaf/pseudo boxes, composite shells) in this
  /// scope, in local coords. Threaded up so the global pass knows the full
  /// obstacle field across all scopes.
  final List<Rect> obstacleRects;

  /// Self-loop loopback bounding rects emitted in this scope (or lifted from a
  /// child), in local coords. Used to offset colliding self-loop arcs.
  final List<Rect> selfLoopRects;

  const _ScopeResult({
    required this.shapes,
    required this.size,
    required this.descendantRects,
    this.labels = const [],
    this.obstacleRects = const [],
    this.selfLoopRects = const [],
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
  List<_ScopedTransition> transitions,
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
    // Horizontal (`left`/`right`) edges are same-rank constraints: src and dst
    // share a layer so a common successor centers between them.
    sameRank: <(String, String)>{
      for (final h in builder.horizontalEdges) (h.src, h.dst),
    },
  );
  final coords = result.coordinates;

  // Mutable positions: the engine places horizontal endpoints on the SAME
  // layer (shared y); we only enforce the direction-implied left/right side.
  final xByNode = Map<String, double>.from(coords.xByNode);
  final yByNode = Map<String, double>.from(coords.yByNode);
  final movedNodes = _applyHorizontalPlacement(builder, xByNode);

  final shapes = <SceneShape>[];
  final descendantRects = <String, Rect>{};
  // Edge-label specs and self-loop loopback rects, accumulated from this scope
  // and lifted from child composites, all projected into this scope's coords.
  final labelSpecs = <_LabelSpec>[];
  final selfLoopRects = <Rect>[];

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
      // Lift the child's edge labels and self-loop rects into this scope so the
      // top-level global pass sees every label/loop in one coordinate space.
      for (final l in composite.interior.labels) {
        labelSpecs.add(l.shift(innerBy));
      }
      for (final r in composite.interior.selfLoopRects) {
        selfLoopRects.add(r.shift(innerBy));
      }
      continue;
    }
    _emitNode(shapes, info, center, measurer);
  }

  // `movedNodes` (returned by `_applyHorizontalPlacement`) holds any nodes
  // whose x was swapped to enforce the horizontal side. A pre-computed engine
  // route touching one of these is stale, so we re-route it straight below.

  // --- Routes --------------------------------------------------------------
  // Build the full set of routes-to-draw (ranking + horizontal) FIRST, so
  // parallel edges (≥2 sharing an unordered endpoint pair) can be fanned out
  // before emission. Each entry carries its final polyline, its label info,
  // and the two endpoint node ids used to detect parallels.
  final draws = <_DrawRoute>[];
  for (final route in result.edgeRoutes.routes) {
    if (route.points.length < 2) continue;
    var pts = route.points.toList();
    final edgeInfo = builder.edgeInfoById[route.edgeId];
    if (edgeInfo == null) {
      draws.add(_DrawRoute(points: pts, edgeInfo: null, a: null, b: null));
      continue;
    }
    // Self-loop: the engine already anchored the 5-point loopback on the
    // node's boundary. Reconciliation/horizontal re-routing assume two
    // distinct endpoints and would collapse the loop, so pass it through
    // unchanged (its label sits at the loop's outer segment).
    if (edgeInfo.src == edgeInfo.dst) {
      // Offset this loopback rightward if its arc rect would collide with a
      // self-loop already placed in the composed scene (e.g. a composite's own
      // loop sitting next to one of its children's loops, or a second loop on
      // the same node), so the arcs stay visually distinct.
      pts = _offsetSelfLoopIfColliding(pts, selfLoopRects);
      selfLoopRects.add(_selfLoopBounds(pts));
      draws.add(_DrawRoute(
        points: pts,
        edgeInfo: edgeInfo,
        a: edgeInfo.src,
        b: edgeInfo.dst,
      ));
      continue;
    }
    // A ranking edge incident to a horizontally-moved node has a stale route;
    // recompute it as a straight segment clipped to the (updated) endpoint
    // rects, mirroring the horizontal-edge routing below.
    if (movedNodes.contains(edgeInfo.src) ||
        movedNodes.contains(edgeInfo.dst)) {
      final srcRect = descendantRects[edgeInfo.srcOriginal ?? edgeInfo.src];
      final dstRect = descendantRects[edgeInfo.dstOriginal ?? edgeInfo.dst];
      if (srcRect != null && dstRect != null) {
        final start =
            _clipPointIntoRect(dstRect.center, srcRect.center, srcRect);
        final end = _clipPointIntoRect(srcRect.center, dstRect.center, dstRect);
        draws.add(_DrawRoute(
          points: [start, end],
          edgeInfo: edgeInfo,
          a: edgeInfo.src,
          b: edgeInfo.dst,
        ));
        continue;
      }
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
    draws.add(_DrawRoute(
      points: pts,
      edgeInfo: edgeInfo,
      a: edgeInfo.src,
      b: edgeInfo.dst,
    ));
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
    draws.add(_DrawRoute(
      points: <Offset>[start, end],
      edgeInfo: _EdgeInfo(label: h.label, src: h.src, dst: h.dst),
      a: h.src,
      b: h.dst,
    ));
  }

  // Fan out parallel edges (groups of ≥2 sharing an unordered endpoint pair)
  // so their polylines and labels no longer coincide, then emit everything.
  final fanned = _fanOutParallelDraws(draws, measurer);
  // Obstacle rects every label in this scope must avoid: each placed node
  // (leaf rect, composite shell, pseudo circle bounds) plus any nested-leaf
  // rect projected up from a child composite — all already in descendantRects.
  // A growing list of already-placed label rects is appended as we emit, so
  // later labels also dodge earlier ones.
  final obstacles = descendantRects.values.toList();
  final placedLabels = <Rect>[];
  for (final d in draws) {
    if (d.points.length < 2) continue;
    final spec = _emitRoute(
        shapes, d.points, d.edgeInfo, measurer, obstacles, placedLabels);
    if (spec != null) labelSpecs.add(spec);
  }

  // Horizontal placement or parallel-edge fan-out may have pushed content past
  // the original layout bounds (or into negative coordinates), so recompute the
  // bounding box over all shapes and normalize the origin to (0,0).
  if (builder.horizontalEdges.isEmpty && !fanned) {
    return _ScopeResult(
      shapes: shapes,
      size: Size(coords.totalWidth, coords.totalHeight),
      descendantRects: descendantRects,
      labels: labelSpecs,
      obstacleRects: descendantRects.values.toList(),
      selfLoopRects: selfLoopRects,
    );
  }
  final bounds = _shapesBounds(shapes);
  if (bounds == null) {
    return _ScopeResult(
      shapes: shapes,
      size: Size(coords.totalWidth, coords.totalHeight),
      descendantRects: descendantRects,
      labels: labelSpecs,
      obstacleRects: descendantRects.values.toList(),
      selfLoopRects: selfLoopRects,
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
    labels: <_LabelSpec>[for (final l in labelSpecs) l.shift(shift)],
    obstacleRects: <Rect>[for (final r in normRects.values) r],
    selfLoopRects: <Rect>[for (final r in selfLoopRects) r.shift(shift)],
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

/// Enforces the direction-implied left/right SIDE for each horizontal
/// (`left`/`right`) edge. The engine already ranks src and dst on the same
/// layer (shared y) via the same-rank constraint, but crossing reduction may
/// order them on either side. When the rendered side is wrong, swap the two
/// nodes' x coordinates: this preserves their shared midpoint (so any common
/// successor stays centered between them) while putting the dst on the implied
/// side. Mutates [xByNode] in place and returns the set of nodes whose x
/// actually changed (their engine routes are now stale and must be re-routed).
Set<String> _applyHorizontalPlacement(
  _ScopeBuilder builder,
  Map<String, double> xByNode,
) {
  final moved = <String>{};
  for (final h in builder.horizontalEdges) {
    final sx = xByNode[h.src];
    final dx = xByNode[h.dst];
    if (sx == null || dx == null) continue;
    final dstShouldBeRight = h.rightward;
    final dstIsRight = dx > sx;
    if (dstShouldBeRight != dstIsRight) {
      xByNode[h.src] = dx;
      xByNode[h.dst] = sx;
      moved.add(h.src);
      moved.add(h.dst);
    }
  }
  return moved;
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

  void collect(List<StateDecl> states, List<_ScopedTransition> transitions) {
    for (final decl in states) {
      _addDirectChild(decl);
    }
    // Materialize the history pseudo nodes this scope OWNS, so they are placed
    // inside even when only cross-boundary edges (from an ancestor scope)
    // reference them.
    plan.ownedHistoryForScope(scope).forEach((id, kind) {
      _ensureHistoryNode(id, kind);
    });
    for (final t in transitions) {
      _addEdge(t);
    }
  }

  /// Materialize a history pseudo node owned by THIS scope (id `[H]@<scope>` /
  /// `[H*]@<scope>`) as a placed member node once.
  void _ensureHistoryNode(String id, _PseudoKind kind) {
    if (infoById.containsKey(id)) return;
    infoById[id] = _NodeInfo(
      id: id,
      width: _historyRadius * 2,
      height: _historyRadius * 2,
      label: '',
      pseudoKind: kind,
    );
    _directChildOf[id] = id;
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
    // Map any history node owned by this child's subtree to the child so a
    // cross-boundary edge punches through to it.
    final interior = scope.isEmpty ? childId : '$scope/$childId';
    for (final id in plan.historyIdsUnder(interior)) {
      _directChildOf[id] = childId;
    }
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

  void _addEdge(_ScopedTransition st) {
    final t = st.transition;
    final from = _resolveEndpoint(t.from, source: true, history: st.fromHistory);
    final to = _resolveEndpoint(t.to, source: false, history: st.toHistory);
    if (from == null || to == null) return;
    // A TRUE self-loop resolves both endpoints to the SAME node (same direct
    // child AND same nested target). When the direct children match but the
    // nested targets differ, this is an edge INTERNAL to a composite seen from
    // an outer scope; it is routed in the composite's own inner scope, so drop
    // it here (unchanged behavior).
    final selfLoop = from.directChild == to.directChild &&
        from.nestedTarget == to.nestedTarget;
    if (from.directChild == to.directChild && !selfLoop) return;
    if (selfLoop) {
      // Self-loops have no meaningful direction: always a side loop-back arc.
      // Feed a self-edge (src == dst) so the engine emits the 5-point loopback.
      final id = 'e${_edgeSeq++}';
      _edges.add(GraphEdge(id: id, src: from.directChild, dst: from.directChild));
      edgeInfoById[id] = _EdgeInfo(
        label: t.label,
        src: from.directChild,
        dst: from.directChild,
        srcOriginal: from.nestedTarget,
        dstOriginal: to.nestedTarget,
      );
      return;
    }
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
  /// scope, plus (when the ref names a nested leaf or owner-scoped history node)
  /// the original target name. [history] is the precomputed owner resolution
  /// for a history endpoint, threaded from the declaring scope.
  ({String directChild, String? nestedTarget})? _resolveEndpoint(
    String ref, {
    required bool source,
    _HistoryResolution? history,
  }) {
    if (history != null) {
      // History pseudo owned by some composite. When owned by THIS scope it is
      // a direct child; when owned deeper, the direct child is the enclosing
      // composite and we punch through to the history node id.
      final direct = _directChildOf[history.id];
      if (direct != null) {
        final nestedTarget = direct == history.id ? null : history.id;
        return (directChild: direct, nestedTarget: nestedTarget);
      }
      // Owner scope is not reachable from this scope (e.g. the LCA sits above
      // an unrelated branch); fall back to a scope-local pseudo so the edge
      // still renders.
    }
    if (ref == '[*]' || ref == '[H]' || ref == '[H*]') {
      final id = _ensureScopedPseudo(ref, source: source);
      return (directChild: id, nestedTarget: null);
    }
    if (_isHistoryRef(ref)) {
      // Qualified history ref whose owner was not a known composite: degrade to
      // a scope-local bare history pseudo of the matching kind.
      final bare = ref.endsWith('[H*]') ? '[H*]' : '[H]';
      final id = _ensureScopedPseudo(bare, source: source);
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

/// A route queued for emission: its final polyline [points], the [edgeInfo]
/// that carries the label/direction, and the two endpoint node ids ([a], [b])
/// used to detect parallel edges. [a]/[b] are null for label-less engine
/// routes that have no edge info (they never participate in grouping).
class _DrawRoute {
  List<Offset> points;
  final _EdgeInfo? edgeInfo;
  final String? a;
  final String? b;
  _DrawRoute({
    required this.points,
    required this.edgeInfo,
    required this.a,
    required this.b,
  });
}

/// Minimum lateral separation between adjacent fanned routes.
const _parallelMinStep = 22.0;

/// Detects groups of routes that connect the SAME unordered node pair and bows
/// each group member sideways so the n polylines fan out symmetrically and
/// their labels (placed at the bowed midpoint) no longer overlap. Self-loops
/// (a==b) and routes without endpoint ids are skipped. Single-edge pairs are
/// left untouched so existing label positions don't shift. Mutates the
/// [draws] points in place.
bool _fanOutParallelDraws(List<_DrawRoute> draws, TextMeasurer measurer) {
  var fanned = false;
  final groups = <String, List<_DrawRoute>>{};
  for (final d in draws) {
    final a = d.a;
    final b = d.b;
    if (a == null || b == null || a == b) continue;
    final key = a.compareTo(b) <= 0 ? '$a $b' : '$b $a';
    groups.putIfAbsent(key, () => <_DrawRoute>[]).add(d);
  }
  for (final group in groups.values) {
    final n = group.length;
    if (n < 2) continue;
    fanned = true;
    // A group is vertical when its first member runs mostly top-to-bottom; the
    // label de-overlap axis follows from that (vertical fan separates labels in
    // X by label width; horizontal fan separates in Y by label height).
    final first = group.first.points;
    final vertical = (first.last.dy - first.first.dy).abs() >=
        (first.last.dx - first.first.dx).abs();
    // Step: large enough that adjacent labels clear each other along the
    // lateral axis, with a sensible minimum.
    var maxLabelExtent = 0.0;
    for (final d in group) {
      final label = d.edgeInfo?.label;
      if (label == null || label.isEmpty) continue;
      final s = measurer.measure(label, _transitionLabelStyle);
      final extent = vertical ? s.width : s.height;
      if (extent > maxLabelExtent) maxLabelExtent = extent;
    }
    final step = math.max(_parallelMinStep, maxLabelExtent + 8.0);
    for (var i = 0; i < n; i++) {
      final offset = (i - (n - 1) / 2) * step;
      if (offset == 0) continue;
      group[i].points = _bowPolyline(group[i].points, offset);
    }
  }
  return fanned;
}

/// Bows [pts] laterally by [offset] (signed). The lateral axis is chosen from
/// the dominant direction of the endpoints: a mostly-vertical edge is offset in
/// X, a mostly-horizontal edge in Y. The endpoints stay anchored; an offset
/// midpoint is inserted (and any existing interior points shifted) so the line
/// visibly separates and the label midpoint moves with it.
List<Offset> _bowPolyline(List<Offset> pts, double offset) {
  final start = pts.first;
  final end = pts.last;
  final dx = (end.dx - start.dx).abs();
  final dy = (end.dy - start.dy).abs();
  final vertical = dy >= dx;
  Offset bow(Offset p, double w) => vertical
      ? Offset(p.dx + offset * w, p.dy)
      : Offset(p.dx, p.dy + offset * w);
  final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  // Two-point routes gain a duplicated bowed apex (start -> apex -> apex -> end)
  // so `_emitRoute`'s label anchor — the segment between points[mid-1] and
  // points[mid] for the 4-point list (both the apex) — lands ON the offset
  // apex, giving each parallel route the full `offset` of label separation.
  if (pts.length == 2) {
    final apex = bow(mid, 1.0);
    return <Offset>[start, apex, apex, end];
  }
  // Multi-point routes: shift each interior point by a weight that tapers to 0
  // at the endpoints, keeping the terminals (and thus arrowheads) anchored.
  final out = <Offset>[start];
  for (var i = 1; i < pts.length - 1; i++) {
    final t = i / (pts.length - 1);
    final w = 1.0 - (2.0 * t - 1.0).abs();
    out.add(bow(pts[i], w));
  }
  out.add(end);
  return out;
}

/// Resolves cross-scope edge-label overlaps in one global pass over the
/// composed scene. Each [labels] spec is in absolute coords (matching the
/// `SceneText` already in [shapes]). Labels are processed in deterministic
/// emission order: a label that already clears every [obstacle] and every
/// previously-finalized label keeps its position (so locally-clean cases are
/// never perturbed); an overlapping one searches the same candidate set as
/// `_placeLabel` for a clear spot (or min-overlap fallback) and, when it moves,
/// the matching `SceneText` in [shapes] is rewritten in place. Only edge labels
/// recorded from `_emitRoute` are considered — node titles and state
/// descriptions are never touched.
void _globalLabelDeoverlap(
  List<SceneShape> shapes,
  TextMeasurer measurer, {
  required List<_LabelSpec> labels,
  required List<Rect> obstacles,
}) {
  final placed = <Rect>[];
  for (final spec in labels) {
    final size = spec.rect.size;
    if (_labelClears(spec.rect, obstacles, placed)) {
      placed.add(spec.rect);
      continue;
    }
    // Reuse the per-scope strategy, but anchor candidates at the label's CURRENT
    // top-left (not the `+4`/centered base) so a clean label that stays put maps
    // to a zero shift and a moved one is nudged from where it already sits.
    final newOffset = _placeLabelFrom(
      anchor: spec.rect.topLeft,
      size: size,
      segStart: spec.segStart,
      segEnd: spec.segEnd,
      obstacles: obstacles,
      placedLabels: placed,
    );
    final newRect = newOffset & size;
    placed.add(newRect);
    if ((newOffset - spec.rect.topLeft).distance > 1e-6) {
      _rewriteLabelText(shapes, spec.text, spec.rect.topLeft, newOffset);
    }
  }
}

/// Candidate search identical to `_placeLabel` but with the base rect anchored
/// at an explicit [anchor] top-left (used by the global pass, where labels are
/// already positioned and we nudge from their current spot). Returns the chosen
/// top-left offset.
Offset _placeLabelFrom({
  required Offset anchor,
  required Size size,
  required Offset segStart,
  required Offset segEnd,
  required List<Rect> obstacles,
  required List<Rect> placedLabels,
}) {
  Offset offsetFor(Offset shift) => anchor + shift;
  Rect rectFor(Offset shift) => offsetFor(shift) & size;

  final base = rectFor(Offset.zero);
  if (_labelClears(base, obstacles, placedLabels)) return anchor;

  var dx = segEnd.dx - segStart.dx;
  var dy = segEnd.dy - segStart.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1e-6) {
    dx = 0;
    dy = 1;
  } else {
    dx /= len;
    dy /= len;
  }
  final perp = Offset(-dy, dx);
  final along = Offset(dx, dy);

  final candidates = <Offset>[];
  for (var d = _labelStep; d <= _labelMaxOffset; d += _labelStep) {
    candidates.add(perp * d);
    candidates.add(perp * -d);
  }
  for (var d = _labelStep; d <= _labelMaxOffset; d += _labelStep) {
    candidates.add(along * d);
    candidates.add(along * -d);
  }

  var best = Offset.zero;
  var bestOverlap = _totalOverlap(base, obstacles, placedLabels);
  for (final shift in candidates) {
    final rect = rectFor(shift);
    if (_labelClears(rect, obstacles, placedLabels)) return offsetFor(shift);
    final overlap = _totalOverlap(rect, obstacles, placedLabels);
    if (overlap < bestOverlap) {
      bestOverlap = overlap;
      best = shift;
    }
  }
  return offsetFor(best);
}

/// Rewrites the single `SceneText` whose text equals [text] and whose offset is
/// (within epsilon) [from], moving it to [to]. Offsets disambiguate duplicate
/// label texts. No-op if no match is found.
void _rewriteLabelText(
  List<SceneShape> shapes,
  String text,
  Offset from,
  Offset to,
) {
  for (var i = 0; i < shapes.length; i++) {
    final s = shapes[i];
    if (s is SceneText &&
        s.text == text &&
        (s.offset - from).distance < 1e-6) {
      shapes[i] = SceneText(
        offset: to,
        text: s.text,
        textStyle: s.textStyle,
        maxWidth: s.maxWidth,
      );
      return;
    }
  }
}

/// Emits the route's line segments and, when present, its label as a
/// `SceneText` (placed via the per-scope `_placeLabel` so locally-clean labels
/// keep their historical position). Returns a `_LabelSpec` describing the
/// emitted label (its local rect + mid-segment) so a later global pass can
/// de-overlap it across scope boundaries; returns null for label-less routes.
_LabelSpec? _emitRoute(
  List<SceneShape> shapes,
  List<Offset> points,
  _EdgeInfo? edgeInfo,
  TextMeasurer measurer,
  List<Rect> obstacles,
  List<Rect> placedLabels,
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
    final offset = _placeLabel(
      mid: mid,
      size: size,
      segStart: a,
      segEnd: b,
      obstacles: obstacles,
      placedLabels: placedLabels,
    );
    final rect = offset & size;
    placedLabels.add(rect);
    shapes.add(SceneText(
      offset: offset,
      text: label,
      textStyle: _transitionLabelStyle,
    ));
    return _LabelSpec(text: label, rect: rect, segStart: a, segEnd: b);
  }
  return null;
}

/// Axis-aligned bounding rect of a self-loop's 5-point loopback polyline.
Rect _selfLoopBounds(List<Offset> pts) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final p in pts) {
    if (p.dx < minX) minX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Upward step used when stacking colliding self-loop arcs into a clear band.
const _selfLoopStep = 16.0;

/// Largest upward shift applied to separate colliding self-loop arcs.
const _selfLoopMaxShift = 160.0;

/// If [pts] (a 5-point right-side loopback) would overlap any [placed]
/// self-loop arc, raise the WHOLE loopback upward in fixed steps until its
/// bounding rect clears them (capped). Shifting the entire loop (anchor points
/// included) up its node's right edge moves it into a clear vertical band
/// rather than just widening it, which keeps the near edge from coinciding with
/// the obstacle loop. Returns the (possibly shifted) polyline.
List<Offset> _offsetSelfLoopIfColliding(List<Offset> pts, List<Rect> placed) {
  if (pts.length != 5 || placed.isEmpty) return pts;
  bool clears(List<Offset> p) {
    final r = _selfLoopBounds(p);
    for (final o in placed) {
      if (r.overlaps(o)) return false;
    }
    return true;
  }

  if (clears(pts)) return pts;
  for (var dy = _selfLoopStep; dy <= _selfLoopMaxShift; dy += _selfLoopStep) {
    final shifted = <Offset>[for (final p in pts) p.translate(0, -dy)];
    if (clears(shifted)) return shifted;
  }
  // No clear stack within the cap: use the max shift so the arcs are at least
  // maximally separated.
  return <Offset>[for (final p in pts) p.translate(0, -_selfLoopMaxShift)];
}

/// Largest perpendicular step tried before falling back to along-edge shifts.
const _labelMaxOffset = 60.0;

/// Increment between successive label-nudge candidates.
const _labelStep = 6.0;

/// Chooses a top-left offset for an edge label whose rect (size [size]) is
/// anchored at the route's mid-segment midpoint [mid] (segment [segStart] ->
/// [segEnd]). The base position matches historical behavior exactly: a `+4` x
/// nudge with the rect vertically centered on [mid]. When that base rect clears
/// every obstacle and already-placed label, it is returned unchanged so simple
/// edges keep their established positions. Otherwise candidates are tried in a
/// fixed, deterministic order — perpendicular to the local edge direction at
/// growing offsets (positive side first, then negative), then small shifts
/// along the edge — and the first fully-clear candidate wins; if none clears
/// within the cap, the candidate with minimum total overlap is returned.
Offset _placeLabel({
  required Offset mid,
  required Size size,
  required Offset segStart,
  required Offset segEnd,
  required List<Rect> obstacles,
  required List<Rect> placedLabels,
}) {
  // Base rect: top-left at (mid.dx + 4, mid.dy - height/2). Candidates are
  // expressed as a center shift from `base` so the `+4`/centering offset is
  // preserved in every candidate.
  Offset offsetFor(Offset shift) =>
      Offset(mid.dx + 4 + shift.dx, mid.dy - size.height / 2 + shift.dy);
  Rect rectFor(Offset shift) => offsetFor(shift) & size;

  final base = rectFor(Offset.zero);
  if (_labelClears(base, obstacles, placedLabels)) {
    return offsetFor(Offset.zero);
  }

  // Local edge direction; perpendicular is the primary nudge axis. Degenerate
  // (zero-length) segments fall back to a vertical edge / horizontal nudge.
  var dx = segEnd.dx - segStart.dx;
  var dy = segEnd.dy - segStart.dy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len < 1e-6) {
    dx = 0;
    dy = 1;
  } else {
    dx /= len;
    dy /= len;
  }
  final perp = Offset(-dy, dx);
  final along = Offset(dx, dy);

  final candidates = <Offset>[];
  // Perpendicular, both sides, growing magnitude (positive side first).
  for (var d = _labelStep; d <= _labelMaxOffset; d += _labelStep) {
    candidates.add(perp * d);
    candidates.add(perp * -d);
  }
  // Then small shifts along the edge (both directions).
  for (var d = _labelStep; d <= _labelMaxOffset; d += _labelStep) {
    candidates.add(along * d);
    candidates.add(along * -d);
  }

  var best = Offset.zero;
  var bestOverlap = _totalOverlap(base, obstacles, placedLabels);
  for (final shift in candidates) {
    final rect = rectFor(shift);
    if (_labelClears(rect, obstacles, placedLabels)) {
      return offsetFor(shift);
    }
    final overlap = _totalOverlap(rect, obstacles, placedLabels);
    if (overlap < bestOverlap) {
      bestOverlap = overlap;
      best = shift;
    }
  }
  return offsetFor(best);
}

/// True when [rect] overlaps none of the [obstacles] or [placedLabels].
bool _labelClears(Rect rect, List<Rect> obstacles, List<Rect> placedLabels) {
  for (final o in obstacles) {
    if (rect.overlaps(o)) return false;
  }
  for (final p in placedLabels) {
    if (rect.overlaps(p)) return false;
  }
  return true;
}

/// Sum of intersection areas between [rect] and every obstacle/placed label.
double _totalOverlap(
  Rect rect,
  List<Rect> obstacles,
  List<Rect> placedLabels,
) {
  double area(Rect a, Rect b) {
    final w = math.min(a.right, b.right) - math.max(a.left, b.left);
    final h = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
    if (w <= 0 || h <= 0) return 0;
    return w * h;
  }

  var total = 0.0;
  for (final o in obstacles) {
    total += area(rect, o);
  }
  for (final p in placedLabels) {
    total += area(rect, p);
  }
  return total;
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
