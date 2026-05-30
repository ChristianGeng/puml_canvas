/// Coordinate assignment for the Sugiyama framework (Phase 3).
///
/// Given an [OrderedLayering] (each layer's left-to-right node order from
/// crossing reduction), assigns a final `(x, y)` to every node — including
/// dummy nodes inserted for long-edge subdivision.
///
/// This file ships a *simplified* Brandes–Köpf style algorithm:
///
/// 1. Y is assigned once: each layer `k` sits at
///    `y = sum(prev layer heights) + k * layerSpacing`. All nodes in a layer
///    share the layer's Y center.
/// 2. X is assigned by two passes that compute an "ideal" position from
///    neighbours and then enforce a minimum-gap constraint left-to-right:
///    a downward pass (ideal = average of predecessors) and an upward pass
///    (ideal = average of successors). Final X is the mean of the two.
/// 3. The result is shifted so the leftmost node starts at x=0 / topmost
///    node at y=0.
///
/// Dummy nodes use a configurable [CoordinatesConfig.dummyWidth] (default 0),
/// so the spacing constraint does not push them apart — long edges stay
/// roughly straight through their dummy chain.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'crossing_reduction.dart';
import 'dummy_nodes.dart';

/// Tunables for [assignCoordinates].
class CoordinatesConfig {
  /// Horizontal gap between adjacent nodes within a layer.
  final double nodeSpacing;

  /// Vertical gap between adjacent layers.
  final double layerSpacing;

  /// Effective width used for dummy nodes regardless of their declared
  /// [width]. Defaults to 0 so dummies act as ideal-line waypoints and don't
  /// force horizontal spacing on the long edges that pass through them.
  final double dummyWidth;

  /// Extra padding around cluster boundaries: added to the bbox on every side
  /// and to the inter-node gap when adjacent nodes belong to different
  /// (innermost) clusters.
  final double clusterPadding;

  /// Extra inset on the top side of a cluster bbox, reserved for the
  /// cluster's title label.
  final double clusterTitleHeight;

  /// Per-cluster override for the top inset of the cluster bbox. When a
  /// cluster id maps to a value here, its bbox top inset becomes
  /// `max(clusterTitleHeight, clusterTopInsets[id])`. Used by callers that
  /// need to reserve extra space above the children for things like a
  /// composite-state description block. Entries for unknown ids are ignored;
  /// missing ids fall back to [clusterTitleHeight].
  final Map<String, double> clusterTopInsets;

  const CoordinatesConfig({
    this.nodeSpacing = 20,
    this.layerSpacing = 40,
    this.dummyWidth = 0,
    this.clusterPadding = 16,
    this.clusterTitleHeight = 18,
    this.clusterTopInsets = const {},
  });
}

/// Final per-node coordinates produced by Phase 3.
class Coordinates {
  /// The ordered layering this assignment was computed from.
  final OrderedLayering input;

  /// Center X coordinate per node id (real + dummy).
  final Map<String, double> xByNode;

  /// Center Y coordinate per node id (real + dummy).
  final Map<String, double> yByNode;

  /// Width of the bounding box of all node bodies (max right − min left).
  final double totalWidth;

  /// Height of the bounding box of all node bodies (max bottom − min top).
  final double totalHeight;

  /// Cluster id → bounding box in the same (post-normalization) coordinate
  /// space as [xByNode]/[yByNode].
  final Map<String, Rect> clusterBoxes;

  const Coordinates({
    required this.input,
    required this.xByNode,
    required this.yByNode,
    required this.totalWidth,
    required this.totalHeight,
    this.clusterBoxes = const {},
  });
}

/// Effective horizontal half-width for [nodeId]: 0 for dummy nodes (so they
/// don't introduce spacing pressure), `width / 2` for real nodes.
double _halfWidth(String nodeId, double declared, CoordinatesConfig config) {
  if (nodeId.startsWith(kDummyNodePrefix)) {
    return config.dummyWidth / 2;
  }
  return declared / 2;
}

/// Run simplified Brandes–Köpf coordinate assignment.
Coordinates assignCoordinates(
  OrderedLayering input, {
  CoordinatesConfig config = const CoordinatesConfig(),
}) {
  final layers = input.orderedLayers;
  final graph = input.input.graph;
  final nodeById = graph.nodeById;

  // --- Y assignment ---------------------------------------------------------
  // Each layer's Y is the center line: top of layer + layer max-height/2.
  final layerHeights = <double>[];
  for (final layer in layers) {
    var maxH = 0.0;
    for (final id in layer) {
      final n = nodeById[id];
      if (n == null) continue;
      final h = id.startsWith(kDummyNodePrefix) ? 0.0 : n.height;
      if (h > maxH) maxH = h;
    }
    layerHeights.add(maxH);
  }

  final yByNode = <String, double>{};
  var cursor = 0.0;
  for (var k = 0; k < layers.length; k++) {
    final h = layerHeights[k];
    final center = cursor + h / 2;
    for (final id in layers[k]) {
      yByNode[id] = center;
    }
    cursor += h + config.layerSpacing;
  }

  // --- Adjacency (effective direction) -------------------------------------
  // Lower-layer neighbours (predecessors in the effective DAG direction).
  final effectivePrevs = <String, List<String>>{
    for (final n in graph.nodes) n.id: <String>[],
  };
  // Higher-layer neighbours (successors).
  final effectiveNexts = <String, List<String>>{
    for (final n in graph.nodes) n.id: <String>[],
  };
  final nodeLayer = input.input.layering.nodeLayer;
  for (final e in graph.edges) {
    if (e.src == e.dst) continue;
    final from = e.isReversed ? e.dst : e.src;
    final to = e.isReversed ? e.src : e.dst;
    final lf = nodeLayer[from];
    final lt = nodeLayer[to];
    if (lf == null || lt == null) continue;
    if (lt > lf) {
      effectiveNexts[from]!.add(to);
      effectivePrevs[to]!.add(from);
    } else if (lf > lt) {
      effectiveNexts[to]!.add(from);
      effectivePrevs[from]!.add(to);
    }
  }

  // --- Cluster ancestry helpers --------------------------------------------
  // Map cluster id → parent cluster id (or null). Top-level clusters and
  // top-level nodes both resolve to a null chain.
  final clusterParent = <String, String?>{
    for (final c in graph.clusters) c.id: c.parentClusterId,
  };

  // Build ancestor chain for a node id: starts with the node's clusterId and
  // walks up through parent clusters. Top-level nodes get an empty chain.
  List<String> ancestorsOf(String nodeId) {
    final n = nodeById[nodeId];
    if (n == null) return const [];
    final out = <String>[];
    var cur = n.clusterId;
    while (cur != null) {
      out.add(cur);
      cur = clusterParent[cur];
    }
    return out;
  }

  // Boundary-spacing heuristic: walk both ancestor chains from the innermost
  // cluster outwards. Find the nearest common ancestor (NCA) — the first
  // cluster id that appears in both chains (or null if neither shares any).
  // Add `clusterPadding` once for every distinct cluster between each node
  // and the NCA. Effectively: padding = (depth(a→NCA) + depth(b→NCA)) *
  // clusterPadding. Two top-level nodes => 0. One top-level + one clustered
  // => depth on the clustered side. Sibling clusters under a shared parent
  // => 2x padding (cross out of one, into the other). This stays sane for
  // 1–2 levels of nesting which is what state diagrams produce in practice.
  double boundaryPadding(String aId, String bId) {
    final ancA = ancestorsOf(aId);
    final ancB = ancestorsOf(bId);
    if (ancA.isEmpty && ancB.isEmpty) return 0;
    final setB = ancB.toSet();
    var depthA = ancA.length; // default: no shared ancestor => full chain
    var nca = -1;
    for (var i = 0; i < ancA.length; i++) {
      if (setB.contains(ancA[i])) {
        depthA = i;
        nca = ancB.indexOf(ancA[i]);
        break;
      }
    }
    final depthB = nca < 0 ? ancB.length : nca;
    return (depthA + depthB) * config.clusterPadding;
  }

  // --- X assignment helpers ------------------------------------------------
  double width(String id) {
    final n = nodeById[id];
    if (n == null) return 0;
    return id.startsWith(kDummyNodePrefix) ? config.dummyWidth : n.width;
  }

  // Pack a layer left-to-right with minimum spacing, anchor at x=0 (first
  // node's left edge lands at 0). Returns packed centers in layer order.
  // The gap between adjacent nodes is `nodeSpacing + boundaryPadding(...)`,
  // so nodes in different clusters get pushed apart by cluster padding too.
  List<double> packLayer(List<String> layer) {
    final out = <double>[];
    var cursor = 0.0;
    for (var i = 0; i < layer.length; i++) {
      final hw = _halfWidth(layer[i], width(layer[i]), config);
      if (i == 0) {
        out.add(hw);
        cursor = hw + hw;
      } else {
        final gap = config.nodeSpacing + boundaryPadding(layer[i - 1], layer[i]);
        out.add(cursor + gap + hw);
        cursor = cursor + gap + hw + hw;
      }
    }
    return out;
  }

  // Compute ideal X for [id] using already-known neighbour positions across
  // both preds and succs. Returns null if no neighbour is known.
  double? idealFor(String id, Map<String, double> known) {
    var sum = 0.0;
    var count = 0;
    for (final n in effectivePrevs[id] ?? const []) {
      final v = known[n];
      if (v == null) continue;
      sum += v;
      count++;
    }
    for (final n in effectiveNexts[id] ?? const []) {
      final v = known[n];
      if (v == null) continue;
      sum += v;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  // --- Pack each layer; iteratively shift each layer to align with the
  // average of its nodes' ideal positions (avg over preds + succs). This is a
  // simplified Brandes-Köpf: each layer is internally packed (so spacing is
  // always satisfied) and only the layer's offset moves to track neighbour
  // centroids. Converges quickly for typical DAG shapes.
  final xByNode = <String, double>{};
  final packed = <List<double>>[
    for (final layer in layers) packLayer(layer),
  ];
  // Initialize: place every layer at its packed positions (offset 0).
  for (var k = 0; k < layers.length; k++) {
    for (var i = 0; i < layers[k].length; i++) {
      xByNode[layers[k][i]] = packed[k][i];
    }
  }
  // Iterate: each round walks top→bottom then bottom→top, shifting each
  // layer so the mean of (ideal − current) across nodes with known ideal is
  // zero. 6 iterations is more than enough for the shape of diagrams we
  // produce — values stabilize within 3 in practice.
  for (var iter = 0; iter < 32; iter++) {
    for (var dir = 0; dir < 2; dir++) {
      for (var idx = 0; idx < layers.length; idx++) {
        final k = dir == 0 ? idx : layers.length - 1 - idx;
        final layer = layers[k];
        if (layer.isEmpty) continue;
        var sumDelta = 0.0;
        var nDelta = 0;
        for (var i = 0; i < layer.length; i++) {
          final ideal = idealFor(layer[i], xByNode);
          if (ideal == null) continue;
          sumDelta += ideal - xByNode[layer[i]]!;
          nDelta++;
        }
        if (nDelta == 0) continue;
        final shift = sumDelta / nDelta;
        for (var i = 0; i < layer.length; i++) {
          xByNode[layer[i]] = xByNode[layer[i]]! + shift;
        }
      }
    }
  }

  // --- Final spacing-repair pass -------------------------------------------
  // Walk each layer left→right and bump x rightward so adjacent centers are
  // at least `halfWidth(left) + nodeSpacing + boundaryPadding + halfWidth(right)`
  // apart. The iterative shifts preserve internal spacing within a layer
  // (each shift is uniform across the layer), but defensively re-enforce
  // here so any future changes upstream can't violate the minimum-gap or
  // cluster-boundary constraints.
  for (final layer in layers) {
    for (var i = 1; i < layer.length; i++) {
      final left = layer[i - 1];
      final right = layer[i];
      final leftHw = _halfWidth(left, width(left), config);
      final rightHw = _halfWidth(right, width(right), config);
      final minCenterGap =
          leftHw + rightHw + config.nodeSpacing + boundaryPadding(left, right);
      final actualGap = xByNode[right]! - xByNode[left]!;
      if (actualGap < minCenterGap) {
        xByNode[right] = xByNode[left]! + minCenterGap;
      }
    }
  }

  // --- Normalize to start at (0, 0) ----------------------------------------
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  for (final id in xByNode.keys) {
    final hw = _halfWidth(id, width(id), config);
    final l = xByNode[id]! - hw;
    final r = xByNode[id]! + hw;
    if (l < minX) minX = l;
    if (r > maxX) maxX = r;
  }
  if (!minX.isFinite) {
    minX = 0;
    maxX = 0;
  }

  var minY = double.infinity;
  var maxY = double.negativeInfinity;
  for (var k = 0; k < layers.length; k++) {
    final h = layerHeights[k];
    for (final id in layers[k]) {
      final cy = yByNode[id]!;
      final t = cy - h / 2;
      final b = cy + h / 2;
      if (t < minY) minY = t;
      if (b > maxY) maxY = b;
    }
  }
  if (!minY.isFinite) {
    minY = 0;
    maxY = 0;
  }

  final shiftedX = <String, double>{
    for (final e in xByNode.entries) e.key: e.value - minX,
  };
  final shiftedY = <String, double>{
    for (final e in yByNode.entries) e.key: e.value - minY,
  };

  // --- Cluster bounding boxes ----------------------------------------------
  // Topological order: children before parents. Then a cluster's bbox unions
  // its members' real-node rects plus any child cluster bboxes, expanded by
  // padding on all sides (and an extra title inset on top).
  final clusterBoxes = <String, Rect>{};
  if (graph.clusters.isNotEmpty) {
    // Build children index.
    final childClusters = <String, List<String>>{};
    for (final c in graph.clusters) {
      if (c.parentClusterId != null) {
        childClusters.putIfAbsent(c.parentClusterId!, () => []).add(c.id);
      }
    }
    // Depth from root (0 for top-level). Process deepest first so a parent
    // sees its children's bboxes already computed.
    final depth = <String, int>{};
    int depthOf(String id) {
      final cached = depth[id];
      if (cached != null) return cached;
      final parent = clusterParent[id];
      final d = parent == null ? 0 : depthOf(parent) + 1;
      depth[id] = d;
      return d;
    }
    for (final c in graph.clusters) {
      depthOf(c.id);
    }
    final ordered = [...graph.clusters]
      ..sort((a, b) => depthOf(b.id).compareTo(depthOf(a.id)));

    for (final c in ordered) {
      var minLx = double.infinity;
      var minLy = double.infinity;
      var maxLx = double.negativeInfinity;
      var maxLy = double.negativeInfinity;

      // Member real-node rects (skip dummies, skip missing ids).
      for (final mid in c.memberIds) {
        if (mid.startsWith(kDummyNodePrefix)) continue;
        final cx = shiftedX[mid];
        final cy = shiftedY[mid];
        if (cx == null || cy == null) continue;
        final n = nodeById[mid];
        if (n == null) continue;
        final l = cx - n.width / 2;
        final r = cx + n.width / 2;
        final t = cy - n.height / 2;
        final b = cy + n.height / 2;
        if (l < minLx) minLx = l;
        if (r > maxLx) maxLx = r;
        if (t < minLy) minLy = t;
        if (b > maxLy) maxLy = b;
      }

      // Child cluster bboxes.
      for (final childId in childClusters[c.id] ?? const []) {
        final child = clusterBoxes[childId];
        if (child == null) continue;
        if (child.left < minLx) minLx = child.left;
        if (child.top < minLy) minLy = child.top;
        if (child.right > maxLx) maxLx = child.right;
        if (child.bottom > maxLy) maxLy = child.bottom;
      }

      if (!minLx.isFinite) {
        // No content — skip.
        continue;
      }

      final pad = config.clusterPadding;
      final overrideInset = config.clusterTopInsets[c.id];
      final topInset = overrideInset == null
          ? config.clusterTitleHeight
          : math.max(config.clusterTitleHeight, overrideInset);
      final rect = Rect.fromLTRB(
        minLx - pad,
        minLy - pad - topInset,
        maxLx + pad,
        maxLy + pad,
      );
      clusterBoxes[c.id] = rect;
    }
  }

  return Coordinates(
    input: input,
    xByNode: Map.unmodifiable(shiftedX),
    yByNode: Map.unmodifiable(shiftedY),
    totalWidth: (maxX - minX).isFinite ? (maxX - minX) : 0,
    totalHeight: (maxY - minY).isFinite ? (maxY - minY) : 0,
    clusterBoxes: Map.unmodifiable(clusterBoxes),
  );
}
