/// Edge routing for the Sugiyama framework (Phase 4). Uses Flutter's [Offset]
/// to match sibling layout files in `lib/src/layout/`.
library;

import 'package:flutter/painting.dart';

import 'coordinates.dart';
import 'dummy_nodes.dart';
import 'graph.dart';

/// Tunables for [routeEdges].
class EdgeRoutingConfig {
  /// Vertical offset (in pixels) inside each layer above/below the node center
  /// where edge endpoints attach. Null = use half the node's own height.
  final double? attachmentInset;

  /// Horizontal extent of the self-loop loopback rectangle.
  final double selfLoopWidth;

  /// Vertical extent of the self-loop loopback rectangle.
  final double selfLoopHeight;

  const EdgeRoutingConfig({
    this.attachmentInset,
    this.selfLoopWidth = 30,
    this.selfLoopHeight = 20,
  });
}

/// A polyline route for one original edge.
class EdgeRoute {
  /// The original edge id from the input [Graph].
  final String edgeId;

  /// Polyline points in draw order, src -> dst in logical direction.
  final List<Offset> points;

  /// True iff the underlying [GraphEdge] had isReversed = true after cycle
  /// removal.
  final bool isReversed;

  const EdgeRoute({
    required this.edgeId,
    required this.points,
    required this.isReversed,
  });
}

/// All edge routes for a laid-out graph.
class EdgeRoutes {
  final Coordinates input;
  final List<EdgeRoute> routes;
  const EdgeRoutes({required this.input, required this.routes});
}

/// Compute polyline routes for every ORIGINAL edge in [input]'s underlying
/// graph. Dummy edges are skipped; long edges are stitched back together via
/// their dummy chain. The [originalDag] argument is the cycle-removed Graph
/// (before dummy insertion) so long-edge isReversed info is recoverable.
EdgeRoutes routeEdges(
  Coordinates input, {
  Graph? originalDag,
  EdgeRoutingConfig config = const EdgeRoutingConfig(),
}) {
  final ordered = input.input;
  final proper = ordered.input;
  final augmented = proper.graph;
  final nodeById = augmented.nodeById;
  final xByNode = input.xByNode;
  final yByNode = input.yByNode;
  final clusterBoxes = input.clusterBoxes;

  // Cluster ancestry — uses the original DAG when supplied (it carries the
  // canonical clustering); otherwise falls back to the post-dummy graph.
  final clusterGraph = originalDag ?? augmented;
  final clusterParent = <String, String?>{
    for (final c in clusterGraph.clusters) c.id: c.parentClusterId,
  };
  final realNodeById = clusterGraph.nodeById;
  List<String> ancestorsOf(String nodeId) {
    final n = realNodeById[nodeId];
    if (n == null) return const [];
    final out = <String>[];
    var cur = n.clusterId;
    while (cur != null) {
      out.add(cur);
      cur = clusterParent[cur];
    }
    return out;
  }

  // Reconstruct, for each original long edge, the ordered list of dummy ids
  // (sorted ascending by layer). The dummy-id naming scheme is
  // `__dummy_${origEdgeId}_${layer}`, but we don't parse the suffix: instead
  // we group by original edge and then sort by the layer assignment.
  final chainsByEdge = <String, List<String>>{};
  proper.dummyOriginalEdge.forEach((dummyId, edgeId) {
    chainsByEdge.putIfAbsent(edgeId, () => <String>[]).add(dummyId);
  });
  final layerOf = proper.layering.nodeLayer;
  for (final list in chainsByEdge.values) {
    list.sort((a, b) => (layerOf[a] ?? 0).compareTo(layerOf[b] ?? 0));
  }

  // Per-layer height (max real-node height) so we can derive layer top/bottom
  // when needed. Mirrors the calculation in coordinates.dart.
  final layers = ordered.orderedLayers;
  final layerHeights = <double>[];
  for (final layer in layers) {
    var maxH = 0.0;
    for (final id in layer) {
      final n = nodeById[id];
      if (n == null) continue;
      if (id.startsWith(kDummyNodePrefix)) continue;
      if (n.height > maxH) maxH = n.height;
    }
    layerHeights.add(maxH);
  }

  // Half-height for a node (for attachment points). Dummies contribute 0 so
  // the polyline passes through their center exactly.
  double halfHeight(String id) {
    if (id.startsWith(kDummyNodePrefix)) return 0;
    if (config.attachmentInset != null) return config.attachmentInset!;
    final n = nodeById[id];
    if (n == null) return 0;
    return n.height / 2;
  }

  Offset center(String id) => Offset(xByNode[id] ?? 0, yByNode[id] ?? 0);

  Offset bottomOf(String id) {
    final c = center(id);
    return Offset(c.dx, c.dy + halfHeight(id));
  }

  Offset topOf(String id) {
    final c = center(id);
    return Offset(c.dx, c.dy - halfHeight(id));
  }

  // We need to route every ORIGINAL edge — i.e. every edge present in the
  // post-cycle-removal Graph. After dummy insertion long edges are gone from
  // the augmented graph (only their chain segments remain), so the augmented
  // graph alone cannot tell us a long edge's isReversed flag. If the caller
  // passes [originalDag] we iterate its edges directly; otherwise we iterate
  // the augmented graph (which still preserves short/self-loop edges) and
  // synthesize stubs for the long edges discovered via [chainsByEdge].
  final edgeSource = <GraphEdge>[];
  if (originalDag != null) {
    for (final e in originalDag.edges) {
      edgeSource.add(e);
    }
  } else {
    for (final e in augmented.edges) {
      if (e.id.startsWith(kDummyEdgePrefix)) continue;
      edgeSource.add(e);
    }
    // For long edges (present only as a dummy chain), synthesize a stub with
    // effective endpoints. We can't recover the original isReversed, so we
    // default to false; pass `originalDag` to get the real flag.
    final seen = {for (final e in edgeSource) e.id};
    for (final entry in chainsByEdge.entries) {
      if (seen.contains(entry.key)) continue;
      final chain = entry.value;
      if (chain.isEmpty) continue;
      // Find the two surrounding chain segments to recover effective src/dst.
      final firstDummy = chain.first;
      final lastDummy = chain.last;
      String? effSrc;
      String? effDst;
      for (final seg in augmented.edges) {
        if (!seg.id.startsWith(kDummyEdgePrefix)) continue;
        if (seg.dst == firstDummy &&
            !seg.src.startsWith(kDummyNodePrefix)) {
          effSrc = seg.src;
        }
        if (seg.src == lastDummy &&
            !seg.dst.startsWith(kDummyNodePrefix)) {
          effDst = seg.dst;
        }
      }
      if (effSrc == null || effDst == null) continue;
      edgeSource.add(GraphEdge(
        id: entry.key,
        src: effSrc,
        dst: effDst,
      ));
    }
  }

  final routes = <EdgeRoute>[];
  for (final edge in edgeSource) {
    if (edge.id.startsWith(kDummyEdgePrefix)) continue;

    // Self-loop: emit the 5-point loopback. After cycle removal a self-loop
    // always carries isReversed = true.
    if (edge.src == edge.dst) {
      final n = nodeById[edge.src];
      if (n == null) continue;
      final cx = xByNode[edge.src] ?? 0;
      final cy = yByNode[edge.src] ?? 0;
      final w = n.width;
      final sw = config.selfLoopWidth;
      final sh = config.selfLoopHeight;
      routes.add(EdgeRoute(
        edgeId: edge.id,
        isReversed: edge.isReversed,
        points: [
          Offset(cx + w / 2, cy),
          Offset(cx + w / 2 + sw, cy),
          Offset(cx + w / 2 + sw, cy - sh),
          Offset(cx + w / 2, cy - sh),
          Offset(cx + w / 2, cy),
        ],
      ));
      continue;
    }

    // For reversed edges the DAG sees `dst -> src` in effective layer space.
    // We want the polyline in logical src -> dst order, so we walk from the
    // higher-y end (effective sink = logical src) down to the lower-y end? No:
    // a reversed back-edge originally points from a *lower* layer to a
    // *higher* layer; cycle removal flipped it so layering treats it as
    // higher->lower. The visual route should still read src -> dst.
    //
    // Operational summary:
    //   - logical src = edge.src, logical dst = edge.dst.
    //   - effective (DAG) source = edge.isReversed ? edge.dst : edge.src.
    //   - chainsByEdge[id] is ordered ascending by layer, i.e. effective
    //     source side -> effective sink side.
    //   - We walk from logical src to logical dst, which means if the edge is
    //     reversed we must traverse the dummy chain in reverse, and the
    //     "bottom attachment" of the logical src is actually its top (it's
    //     above the dst in layer space).

    final logicalSrc = edge.src;
    final logicalDst = edge.dst;
    final effectiveSrc = edge.isReversed ? edge.dst : edge.src;

    final chain = chainsByEdge[edge.id] ?? const <String>[];

    // Decide attachment direction for the logical endpoints. The effective
    // source sits at a lower layer (higher up the page), so its outgoing
    // attachment is its bottom; the effective sink's incoming attachment is
    // its top. When the edge is reversed, logical src == effective sink and
    // logical dst == effective source.
    final srcIsEffectiveSrc = (logicalSrc == effectiveSrc);
    final srcAttach = srcIsEffectiveSrc ? bottomOf(logicalSrc) : topOf(logicalSrc);
    final dstAttach = srcIsEffectiveSrc ? topOf(logicalDst) : bottomOf(logicalDst);

    // Dummy waypoints in logical src -> dst order.
    final waypoints = <Offset>[];
    if (chain.isNotEmpty) {
      final orderedChain =
          srcIsEffectiveSrc ? chain : chain.reversed.toList();
      for (final d in orderedChain) {
        waypoints.add(center(d));
      }
    }

    var points = <Offset>[srcAttach, ...waypoints, dstAttach];
    points = _injectClusterBoundaryWaypoints(
      points: points,
      logicalSrc: logicalSrc,
      logicalDst: logicalDst,
      ancestorsOf: ancestorsOf,
      clusterBoxes: clusterBoxes,
    );

    routes.add(EdgeRoute(
      edgeId: edge.id,
      isReversed: edge.isReversed,
      points: points,
    ));
  }

  return EdgeRoutes(input: input, routes: List.unmodifiable(routes));
}

/// Insert waypoints where the polyline crosses a cluster bbox that only one
/// endpoint belongs to. Edges fully inside one cluster (or fully outside any
/// cluster) are returned untouched.
///
/// Simplification (Phase 6d.1): when nested clusters are exited or entered,
/// we use the *outermost affected* cluster on each side as a single boundary
/// stop. Multi-shell crossings (e.g. through 2 layers of nesting on each
/// side) collapse to one waypoint per side. The polyline still cleanly leaves
/// the outer enclosure and enters the destination's outer enclosure.
List<Offset> _injectClusterBoundaryWaypoints({
  required List<Offset> points,
  required String logicalSrc,
  required String logicalDst,
  required List<String> Function(String) ancestorsOf,
  required Map<String, Rect> clusterBoxes,
}) {
  if (clusterBoxes.isEmpty) return points;
  if (points.length < 2) return points;

  final ancSrc = ancestorsOf(logicalSrc);
  final ancDst = ancestorsOf(logicalDst);
  if (ancSrc.isEmpty && ancDst.isEmpty) return points;

  final srcSet = ancSrc.toSet();
  final dstSet = ancDst.toSet();

  // Clusters exited on the src side: in src ancestry but not in dst's.
  // Order: innermost (index 0 of ancSrc) → outermost.
  final exits = <String>[
    for (final c in ancSrc)
      if (!dstSet.contains(c) && clusterBoxes.containsKey(c)) c,
  ];
  // Clusters entered on the dst side: in dst ancestry but not in src's.
  // Order in route: outermost first → innermost. Walk ancDst in reverse.
  final enters = <String>[
    for (final c in ancDst.reversed)
      if (!srcSet.contains(c) && clusterBoxes.containsKey(c)) c,
  ];

  if (exits.isEmpty && enters.isEmpty) return points;

  // Outermost-affected simplification: keep only the outermost cluster on each
  // side. For exits, that's the last item (chain is innermost→outermost).
  // For enters, that's the first item (chain is outermost→innermost).
  final exitCluster = exits.isEmpty ? null : exits.last;
  final enterCluster = enters.isEmpty ? null : enters.first;

  // Use the original src and dst endpoints as the "outside" reference points
  // for each side's intersection. The exit boundary is found by clipping the
  // segment from src toward the route's last point; the entry boundary is
  // found by clipping the segment from dst back toward the route's first
  // point. This naturally handles long-edge dummy chains: the cluster-cross
  // happens between the inner node and its nearest dummy.
  final result = <Offset>[...points];

  if (exitCluster != null) {
    final rect = clusterBoxes[exitCluster]!;
    // Find the first segment (in src->dst order) that has its src-end inside
    // the rect and dst-end outside. Insert the exit intersection there.
    for (var i = 0; i + 1 < result.length; i++) {
      final inside = _rectContainsOrOn(rect, result[i]);
      final outsideNext = !_rectContainsOrOn(rect, result[i + 1]);
      if (inside && outsideNext) {
        final hit = _segmentRectExit(result[i], result[i + 1], rect);
        if (hit != null) {
          result.insert(i + 1, hit);
        }
        break;
      }
    }
  }

  if (enterCluster != null) {
    final rect = clusterBoxes[enterCluster]!;
    // Find the first segment whose src-end is outside and dst-end is inside.
    for (var i = 0; i + 1 < result.length; i++) {
      final outside = !_rectContainsOrOn(rect, result[i]);
      final insideNext = _rectContainsOrOn(rect, result[i + 1]);
      if (outside && insideNext) {
        final hit = _segmentRectEntry(result[i], result[i + 1], rect);
        if (hit != null) {
          result.insert(i + 1, hit);
        }
        break;
      }
    }
  }

  return result;
}

bool _rectContainsOrOn(Rect r, Offset p) {
  return p.dx >= r.left - 1e-9 &&
      p.dx <= r.right + 1e-9 &&
      p.dy >= r.top - 1e-9 &&
      p.dy <= r.bottom + 1e-9;
}

/// Intersect segment p1→p2 with rect [r] and return the intersection point
/// closer to [p2] (the "outside" end, used for exiting). Returns null if the
/// segment does not cross the rect boundary in (0..1].
Offset? _segmentRectExit(Offset p1, Offset p2, Rect r) {
  // Liang–Barsky line clipping: find parametric t in [0,1] where segment
  // exits the rect. p1 is assumed inside (or on the boundary); we want the
  // largest t for which the point is still inside.
  final dx = p2.dx - p1.dx;
  final dy = p2.dy - p1.dy;
  if (dx == 0 && dy == 0) return null;
  var tExit = 1.0;
  // For each edge: compute the t at which the segment crosses, and clamp.
  bool clip(double p, double q) {
    if (p == 0) {
      return q >= 0;
    }
    final t = q / p;
    if (p > 0) {
      if (t < tExit) tExit = t;
    }
    return true;
  }

  if (!clip(-dx, p1.dx - r.left)) return null; // left
  if (!clip(dx, r.right - p1.dx)) return null; // right
  if (!clip(-dy, p1.dy - r.top)) return null; // top
  if (!clip(dy, r.bottom - p1.dy)) return null; // bottom

  if (tExit <= 0 || tExit > 1.0 + 1e-9) return null;
  return Offset(p1.dx + tExit * dx, p1.dy + tExit * dy);
}

/// Intersect segment p1→p2 with rect [r] and return the intersection point
/// closer to [p1] (the "outside" end, used for entering). Returns null if
/// the segment does not cross.
Offset? _segmentRectEntry(Offset p1, Offset p2, Rect r) {
  // Mirror of _segmentRectExit: find smallest t≥0 at which we enter the rect.
  final dx = p2.dx - p1.dx;
  final dy = p2.dy - p1.dy;
  if (dx == 0 && dy == 0) return null;
  var tEnter = 0.0;
  bool clip(double p, double q) {
    if (p == 0) {
      return q >= 0;
    }
    final t = q / p;
    if (p < 0) {
      if (t > tEnter) tEnter = t;
    }
    return true;
  }

  if (!clip(-dx, p1.dx - r.left)) return null;
  if (!clip(dx, r.right - p1.dx)) return null;
  if (!clip(-dy, p1.dy - r.top)) return null;
  if (!clip(dy, r.bottom - p1.dy)) return null;

  if (tEnter < -1e-9 || tEnter >= 1.0) return null;
  return Offset(p1.dx + tEnter * dx, p1.dy + tEnter * dy);
}
