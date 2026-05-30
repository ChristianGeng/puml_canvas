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

  final builder = _StateGraphBuilder(measurer);
  builder.collect(diagram.states, diagram.transitions);
  final graph = builder.build();

  final shapes = <SceneShape>[];
  if (graph.nodes.isEmpty) {
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

  // Composite states with descriptions need extra vertical space at the top
  // of their cluster bbox (title + divider + desc lines + bottom pad). The
  // builder pre-measured this; surface it to the coordinate phase via the
  // per-cluster top-inset map.
  final clusterTopInsets = <String, double>{
    for (final draft in builder.clustersById.values)
      if (draft.topInset > 0) draft.id: draft.topInset,
  };
  final result = runSugiyama(
    graph,
    coordinatesConfig: CoordinatesConfig(
      nodeSpacing: _nodeSpacing,
      layerSpacing: _layerSpacing,
      clusterPadding: _clusterPadding,
      clusterTitleHeight: _clusterTitleHeight,
      clusterTopInsets: clusterTopInsets,
    ),
  );

  final coords = result.coordinates;

  shapes.addAll(_renderGraph(
    builder,
    graph,
    result,
    const Offset(_padding, _padding),
    measurer,
  ));

  final width = coords.totalWidth + _padding * 2;
  final height = coords.totalHeight + _padding * 2;
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

/// Renders a laid-out graph (cluster shells, nodes, routes) into scene shapes.
/// [origin] is added to every coordinate; the top level passes the outer
/// `_padding`, region sub-layouts pass `Offset.zero`.
List<SceneShape> _renderGraph(
  _StateGraphBuilder builder,
  Graph graph,
  SugiyamaResult result,
  Offset origin,
  TextMeasurer measurer,
) {
  final shapes = <SceneShape>[];
  final coords = result.coordinates;
  final routes = result.edgeRoutes;

  Offset translate(Offset p) => Offset(p.dx + origin.dx, p.dy + origin.dy);

  // Render composite-state shells first, outermost to innermost, so child
  // nodes and inner clusters paint on top. Depth is the number of parent
  // links to walk from the cluster up to a top-level container.
  final clusterDepth = <String, int>{};
  final clusterById = <String, GraphCluster>{
    for (final c in graph.clusters) c.id: c,
  };
  int depthOf(String id) {
    final cached = clusterDepth[id];
    if (cached != null) return cached;
    final c = clusterById[id];
    final parent = c?.parentClusterId;
    final d = parent == null ? 0 : depthOf(parent) + 1;
    clusterDepth[id] = d;
    return d;
  }
  for (final c in graph.clusters) {
    depthOf(c.id);
  }
  final orderedClusters = [...graph.clusters]
    ..sort((a, b) => depthOf(a.id).compareTo(depthOf(b.id)));
  for (final c in orderedClusters) {
    final box = coords.clusterBoxes[c.id];
    if (box == null) continue;
    final rect = box.shift(origin);
    shapes.add(SceneRoundedBox(
      rect: rect,
      textStyle: _compositeHeaderStyle,
      fill: _compositeFill,
      stroke: _stateStroke,
      cornerRadius: 12.0,
    ));
    final label = c.label ?? c.id;
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
    // Composite description lines: stacked left-aligned below the divider,
    // mirroring the leaf-state description block in `_emitNode`. The bbox
    // already reserves enough vertical space via the cluster top inset.
    final draft = builder.clustersById[c.id];
    if (draft != null && draft.descriptions.isNotEmpty) {
      var y = rect.top + _clusterTitleHeight + _stateDescriptionDividerPad;
      for (var i = 0; i < draft.descriptions.length; i++) {
        final desc = draft.descriptions[i];
        final ds = draft.descriptionSizes[i];
        shapes.add(SceneText(
          offset: Offset(rect.left + _statePaddingX, y),
          text: desc,
          textStyle: _stateDescriptionStyle,
        ));
        y += ds.height;
      }
    }
  }

  for (final node in graph.nodes) {
    final cx = coords.xByNode[node.id];
    final cy = coords.yByNode[node.id];
    if (cx == null || cy == null) continue;
    final center = translate(Offset(cx, cy));
    final info = builder.infoById[node.id]!;
    _emitNode(shapes, info, center, measurer);
  }

  for (final route in routes.routes) {
    if (route.points.length < 2) continue;
    var pts = route.points.map(translate).toList();
    final edgeInfo = builder.edgeInfoById[route.edgeId];
    // Cluster-incident edges were redirected to an inner representative node;
    // clip the polyline back to the referenced composite's boundary so the
    // arrow terminates on the shell rather than inside it.
    final srcBox = edgeInfo?.srcCluster == null
        ? null
        : coords.clusterBoxes[edgeInfo!.srcCluster];
    final dstBox = edgeInfo?.dstCluster == null
        ? null
        : coords.clusterBoxes[edgeInfo!.dstCluster];
    if (srcBox != null) pts = _clipHeadToBoundary(pts, srcBox.shift(origin));
    if (dstBox != null) pts = _clipTailToBoundary(pts, dstBox.shift(origin));
    if (pts.length < 2) continue;
    _emitRoute(shapes, pts, edgeInfo, measurer);
  }

  return shapes;
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

/// Lays out a region's states/transitions in LOCAL coordinates (origin 0,0,
/// no outer padding) and returns the shapes plus the bounding size.
({List<SceneShape> shapes, Size size}) _layoutLocal(
  List<StateDecl> states,
  List<StateTransition> transitions,
  TextMeasurer measurer,
) {
  final builder = _StateGraphBuilder(measurer);
  builder.collect(states, transitions);
  final graph = builder.build();
  if (graph.nodes.isEmpty) {
    return (shapes: const <SceneShape>[], size: Size.zero);
  }
  final clusterTopInsets = <String, double>{
    for (final draft in builder.clustersById.values)
      if (draft.topInset > 0) draft.id: draft.topInset,
  };
  final result = runSugiyama(
    graph,
    coordinatesConfig: CoordinatesConfig(
      nodeSpacing: _nodeSpacing,
      layerSpacing: _layerSpacing,
      clusterPadding: _clusterPadding,
      clusterTitleHeight: _clusterTitleHeight,
      clusterTopInsets: clusterTopInsets,
    ),
  );
  final shapes = _renderGraph(builder, graph, result, Offset.zero, measurer);
  final coords = result.coordinates;
  return (shapes: shapes, size: Size(coords.totalWidth, coords.totalHeight));
}

class _NodeInfo {
  final String id;
  final double width;
  final double height;
  final String label;
  final _PseudoKind? pseudoKind;
  final String? clusterId;
  /// True when this node is a concurrent composite (see [concurrent]).
  final bool isFlattenedComposite;
  /// PlantUML `A : foo` description lines for this leaf state. Empty for
  /// pseudo states and flattened composites.
  final List<String> descriptions;
  /// Pre-measured size for each entry in [descriptions], used by `_emitNode`
  /// to position description text without re-measuring.
  final List<Size> descriptionSizes;
  /// Title text height (measured with `_stateStyle`); the divider sits below
  /// the title at `top + _statePaddingY + titleHeight + divider pad`.
  final double titleHeight;
  /// Non-null when this node is a concurrent composite; carries the pre-laid
  /// region sub-shapes, their offsets, and the region divider lines.
  final _ConcurrentLayout? concurrent;

  const _NodeInfo({
    required this.id,
    required this.width,
    required this.height,
    required this.label,
    this.pseudoKind,
    this.clusterId,
    this.isFlattenedComposite = false,
    this.descriptions = const [],
    this.descriptionSizes = const [],
    this.titleHeight = 0.0,
    this.concurrent,
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

class _EdgeInfo {
  final String? label;
  /// Cluster id the edge's source/destination originally referenced when that
  /// endpoint was a composite. The edge is redirected to a representative
  /// member node for layout; the route is later clipped at this cluster's
  /// boundary so the arrow terminates on the composite shell.
  final String? srcCluster;
  final String? dstCluster;
  const _EdgeInfo({this.label, this.srcCluster, this.dstCluster});
}

class _StateGraphBuilder {
  final TextMeasurer measurer;

  // Preserves insertion order so the graph layout is deterministic.
  final Map<String, _NodeInfo> infoById = <String, _NodeInfo>{};
  final Map<String, _EdgeInfo> edgeInfoById = <String, _EdgeInfo>{};
  final List<GraphEdge> _edges = <GraphEdge>[];
  // Cluster id -> mutable definition under construction. Member ids are
  // appended as nested children are walked. Exposed (via [clustersById]) so
  // the renderer can look up extra per-cluster metadata (descriptions, title
  // height, top inset) that doesn't live on [GraphCluster].
  final Map<String, _ClusterDraft> _clusters = <String, _ClusterDraft>{};
  Map<String, _ClusterDraft> get clustersById => _clusters;
  // Tracks the parent cluster while recursing through nestedStates so each
  // child gets the right clusterId stamped on its _NodeInfo.
  final List<String> _clusterStack = <String>[];
  int _edgeSeq = 0;

  _StateGraphBuilder(this.measurer);

  void collect(List<StateDecl> states, List<StateTransition> transitions) {
    // Resolution helper: PlantUML treats state names as globally unique within
    // a diagram, so a DFS first-match is unambiguous in practice.
    String resolve(String ref) {
      if (ref == '[*]' || ref == '[H]' || ref == '[H*]') return ref;
      // Look up by name across the entire (potentially nested) tree.
      final found = _findStateByName(states, ref);
      return found ?? ref;
    }

    for (final decl in states) {
      _addStateNode(decl);
    }

    // Top-level transitions live in the root scope (scope == null); each
    // composite's nested transitions live in that composite's scope so their
    // [*]/[H]/[H*] pseudo states are distinct per-composite instances rather
    // than collapsing onto a single shared global node.
    for (final t in transitions) {
      _addEdge(t, resolve, null);
    }
    void walkNested(List<StateDecl> decls) {
      for (final d in decls) {
        // Pseudo scoping is intentionally root-level (null) for now: per-
        // composite [*]/[H] instances are only correct once composites lay out
        // recursively (each as its own sub-graph), otherwise their top-layer
        // initial drags the cluster bbox up and overlaps sibling composites.
        for (final t in d.nestedTransitions) {
          _addEdge(t, resolve, null);
        }
        walkNested(d.nestedStates);
        // Concurrent regions render via their own recursive sub-layouts in
        // `_addConcurrentNode`; their nested transitions are intentionally not
        // added to the outer graph (kept inside each region's sub-graph).
      }
    }
    walkNested(states);
  }

  void _addEdge(StateTransition t, String Function(String) resolve,
      String? scope) {
    var fromKey = _endpointKey(resolve(t.from), source: true, scope: scope);
    var toKey = _endpointKey(resolve(t.to), source: false, scope: scope);
    // An endpoint that names a composite (cluster) has no GraphNode. Redirect
    // it to a representative member node so the edge participates in layout;
    // the route is clipped back to the cluster boundary at render time.
    String? srcCluster;
    String? dstCluster;
    if (!infoById.containsKey(fromKey)) {
      if (!_clusters.containsKey(fromKey)) return;
      final rep = _clusterRepresentative(fromKey);
      if (rep == null) return;
      srcCluster = fromKey;
      fromKey = rep;
    }
    if (!infoById.containsKey(toKey)) {
      if (!_clusters.containsKey(toKey)) return;
      final rep = _clusterRepresentative(toKey);
      if (rep == null) return;
      dstCluster = toKey;
      toKey = rep;
    }
    if (fromKey == toKey) return;
    final id = 'e${_edgeSeq++}';
    _edges.add(GraphEdge(id: id, src: fromKey, dst: toKey));
    edgeInfoById[id] =
        _EdgeInfo(label: t.label, srcCluster: srcCluster, dstCluster: dstCluster);
  }

  /// Resolve a composite [clusterId] to a representative leaf node id, walking
  /// its members (descending into sub-clusters) so a cluster-incident edge has
  /// a real node to attach to for layering and routing.
  String? _clusterRepresentative(String clusterId) {
    final draft = _clusters[clusterId];
    if (draft == null) return null;
    for (final m in draft.memberIds) {
      final info = infoById[m];
      if (info != null && info.pseudoKind == null) return m;
      if (_clusters.containsKey(m)) {
        final r = _clusterRepresentative(m);
        if (r != null) return r;
      }
    }
    // Fall back to a pseudo member if the composite has no real-state child.
    for (final m in draft.memberIds) {
      if (infoById.containsKey(m)) return m;
    }
    return null;
  }

  /// Map a transition endpoint [ref] to a node id, materialising [*]/[H]/[H*]
  /// pseudo nodes scoped to the enclosing composite [scope] (null = root) so
  /// each composite owns its own initial/final/history instances.
  String _endpointKey(String ref,
      {required bool source, required String? scope}) {
    switch (ref) {
      case '[*]':
        final kind = source ? _PseudoKind.initial : _PseudoKind.finalState;
        final id =
            _scopedPseudoId(source ? '[*]:initial' : '[*]:final', scope);
        _ensurePseudo(id, kind, scope);
        return id;
      case '[H]':
        final id = _scopedPseudoId('[H]', scope);
        _ensurePseudo(id, _PseudoKind.historyShallow, scope);
        return id;
      case '[H*]':
        final id = _scopedPseudoId('[H*]', scope);
        _ensurePseudo(id, _PseudoKind.historyDeep, scope);
        return id;
      default:
        return ref;
    }
  }

  String _scopedPseudoId(String base, String? scope) =>
      scope == null ? base : '$base@$scope';

  /// Create a scoped pseudo node once, stamping it into [scope]'s cluster so
  /// the coordinate phase nests it inside the right composite bbox.
  void _ensurePseudo(String id, _PseudoKind kind, String? scope) {
    if (infoById.containsKey(id)) return;
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
      clusterId: scope,
    );
    if (scope != null) _clusters[scope]?.memberIds.add(id);
  }

  Graph build() {
    final nodes = <GraphNode>[
      for (final info in infoById.values)
        GraphNode(
          id: info.id,
          width: info.width,
          height: info.height,
          label: info.label,
          clusterId: info.clusterId,
        ),
    ];
    final clusters = <GraphCluster>[
      for (final draft in _clusters.values)
        GraphCluster(
          id: draft.id,
          label: draft.label,
          parentClusterId: draft.parentClusterId,
          memberIds: List.unmodifiable(draft.memberIds),
        ),
    ];
    return Graph(
      nodes: nodes,
      edges: List.unmodifiable(_edges),
      clusters: List.unmodifiable(clusters),
    );
  }

  void _addStateNode(StateDecl decl) {
    if (infoById.containsKey(decl.name)) return;
    if (_clusters.containsKey(decl.name)) return;
    final stereo = _pseudoKindFromStereotype(decl.stereotype);
    if (stereo != null) {
      _addStereotypePseudo(decl.name, stereo);
      return;
    }
    final hasNested =
        decl.nestedStates.isNotEmpty || decl.nestedTransitions.isNotEmpty;
    final hasConcurrent = decl.concurrentRegions.isNotEmpty;
    if (hasNested && !hasConcurrent) {
      // True composite: emit a GraphCluster and recurse into nested states.
      // The composite itself has no GraphNode; the bbox is derived from its
      // children + cluster padding by `assignCoordinates`.
      final parent = _clusterStack.isEmpty ? null : _clusterStack.last;
      // Pre-measure the title and any description lines so the bbox can
      // reserve enough vertical space at the top for them. Mirrors the leaf
      // description block: divider pad above and below, then stacked desc
      // lines, then a bottom pad before the first child node.
      final headerSize = measurer.measure(decl.label, _compositeHeaderStyle);
      final descSizes = <Size>[];
      var descBlockHeight = 0.0;
      for (final d in decl.descriptions) {
        final s = measurer.measure(d, _stateDescriptionStyle);
        descSizes.add(s);
        descBlockHeight += s.height;
      }
      // Default cluster top inset is just `_clusterTitleHeight` (handled by
      // CoordinatesConfig). When there are descriptions we extend it by the
      // divider gap + description block + bottom pad so the child nodes have
      // room to sit below the description rows.
      var topInset = 0.0;
      if (decl.descriptions.isNotEmpty) {
        topInset = _clusterTitleHeight +
            _stateDescriptionDividerPad +
            descBlockHeight +
            _stateDescriptionBottomPad;
      }
      final draft = _ClusterDraft(
        id: decl.name,
        label: decl.label,
        parentClusterId: parent,
        descriptions: decl.descriptions,
        descriptionSizes: descSizes,
        titleHeight: headerSize.height,
        topInset: topInset,
      );
      _clusters[decl.name] = draft;
      _clusterStack.add(decl.name);
      for (final child in decl.nestedStates) {
        _addStateNode(child);
        // After adding, attach the child as a member of this cluster.
        if (infoById.containsKey(child.name)) {
          draft.memberIds.add(child.name);
        } else if (_clusters.containsKey(child.name)) {
          draft.memberIds.add(child.name);
        }
      }
      _clusterStack.removeLast();
      return;
    }
    if (hasConcurrent) {
      _addConcurrentNode(decl);
      return;
    }
    // Leaf state.
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
    final width =
        math.max(_minStateWidth, contentWidth + _statePaddingX * 2);
    var height =
        math.max(_minStateHeight, titleSize.height + _statePaddingY * 2);
    if (showDescriptions) {
      // Mirrors `state_layout.dart`: padded title row, divider with pad on
      // each side, description block, bottom pad.
      height = _statePaddingY +
          titleSize.height +
          _stateDescriptionDividerPad * 2 +
          descBlockHeight +
          _stateDescriptionBottomPad;
    }
    final parentCluster = _clusterStack.isEmpty ? null : _clusterStack.last;
    infoById[decl.name] = _NodeInfo(
      id: decl.name,
      width: width,
      height: height,
      label: decl.label,
      clusterId: parentCluster,
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
      final laid = _layoutLocal(region, relevant, measurer);
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
      // Vertical stack: regions top-to-bottom, horizontal dashed dividers.
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
      // Horizontal stack: regions left-to-right, vertical dashed dividers.
      var maxRegionHeight = 0.0;
      for (final s in regionSizes) {
        if (s.height > maxRegionHeight) maxRegionHeight = s.height;
      }
      height = _clusterTitleHeight +
          _compositeBodyPad * 2 +
          maxRegionHeight;
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

    final parentCluster = _clusterStack.isEmpty ? null : _clusterStack.last;
    infoById[decl.name] = _NodeInfo(
      id: decl.name,
      width: width,
      height: height,
      label: decl.label,
      clusterId: parentCluster,
      isFlattenedComposite: true,
      titleHeight: headerSize.height,
      concurrent: _ConcurrentLayout(
        regionShapes: regionShapesList,
        regionOffsets: regionOffsets,
        dividers: dividers,
        label: decl.label,
      ),
    );
  }

  /// True when [ref] belongs to [region] (or is the `[*]` pseudo). Mirrors the
  /// legacy region-membership check in `state_layout.dart`.
  bool _isInRegion(String ref, List<StateDecl> region) {
    if (ref == '[*]') return true;
    for (final s in region) {
      if (s.name == ref) return true;
    }
    return false;
  }

  void _addPseudoNode(String id, _PseudoKind kind) {
    if (infoById.containsKey(id)) return;
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
  }

  void _addStereotypePseudo(String name, _PseudoKind kind) {
    final parentCluster = _clusterStack.isEmpty ? null : _clusterStack.last;
    switch (kind) {
      case _PseudoKind.choice:
        infoById[name] = _NodeInfo(
          id: name,
          width: 24,
          height: 24,
          label: '',
          pseudoKind: kind,
          clusterId: parentCluster,
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
          clusterId: parentCluster,
        );
        return;
      case _PseudoKind.initial:
      case _PseudoKind.finalState:
      case _PseudoKind.historyShallow:
      case _PseudoKind.historyDeep:
        _addPseudoNode(name, kind);
        return;
    }
  }

  /// DFS first-match lookup for a state name anywhere in the tree (top-level
  /// or nested through nestedStates/concurrentRegions). Returns the matched
  /// state's `name` (which is also its node id).
  String? _findStateByName(List<StateDecl> decls, String name) {
    for (final d in decls) {
      if (d.name == name) return d.name;
      final inNested = _findStateByName(d.nestedStates, name);
      if (inNested != null) return inNested;
      for (final region in d.concurrentRegions) {
        final inRegion = _findStateByName(region, name);
        if (inRegion != null) return inRegion;
      }
    }
    return null;
  }
}

/// Mutable builder helper for a [GraphCluster]: collects member ids during the
/// DFS so we can freeze them into an immutable cluster at build time.
class _ClusterDraft {
  final String id;
  final String? label;
  final String? parentClusterId;
  final List<String> memberIds = <String>[];
  /// PlantUML `Outer : foo` description lines attached to this composite
  /// state. Rendered below the cluster title + divider, inside the bbox's
  /// extra top inset (see [topInset]).
  final List<String> descriptions;
  /// Pre-measured size per entry in [descriptions], used to position text
  /// without re-measuring at render time.
  final List<Size> descriptionSizes;
  /// Title text height (measured with `_compositeHeaderStyle`); used to place
  /// the divider line just below the title row.
  final double titleHeight;
  /// Extra top inset (in addition to the title row) requested for this
  /// cluster's bbox — 0 when there are no descriptions; otherwise the height
  /// of the description block plus its dividers/pads. Passed to
  /// [CoordinatesConfig.clusterTopInsets].
  final double topInset;

  _ClusterDraft({
    required this.id,
    this.label,
    this.parentClusterId,
    this.descriptions = const [],
    this.descriptionSizes = const [],
    this.titleHeight = 0.0,
    this.topInset = 0.0,
  });
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
  // Description path: paint the shell without a label so we can place the
  // title, divider, and description lines explicitly. Matches the legacy
  // `_NodeKind.simple` description branch in `state_layout.dart`.
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
    final desc = info.descriptions[i];
    final ds = info.descriptionSizes[i];
    shapes.add(SceneText(
      offset: Offset(rect.left + _statePaddingX, y),
      text: desc,
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
/// region sub-layout can emit; unknown types are returned unshifted.
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
