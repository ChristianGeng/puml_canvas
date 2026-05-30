/// Crossing reduction for the Sugiyama framework (Phase 2, step 2).
///
/// Implements the classic barycenter heuristic with alternating
/// down/up sweeps. Within each layer, every node's "barycenter" is the
/// average index of its neighbours in the adjacent layer; sorting layers by
/// that value tends to pull connected nodes closer and reduces edge
/// crossings.
library;

import 'dummy_nodes.dart';

/// The result of crossing reduction: the [ProperLayering] from Phase 2/step 1
/// plus a left-to-right ordering of every layer.
class OrderedLayering {
  final ProperLayering input;

  /// `orderedLayers[k]` is the left-to-right order of node ids at layer `k`.
  final List<List<String>> orderedLayers;

  const OrderedLayering({required this.input, required this.orderedLayers});
}

/// Reduce crossings using the barycenter heuristic.
///
/// Performs up to [maxSweeps] alternating down/up sweeps. Stops early when a
/// pair of sweeps leaves every layer ordering unchanged.
OrderedLayering reduceCrossings(
  ProperLayering input, {
  int maxSweeps = 24,
}) {
  final graph = input.graph;
  final layering = input.layering;

  // Mutable copy of the per-layer ordering we'll iterate on.
  final orders = <List<String>>[
    for (final layer in layering.layers) List<String>.from(layer),
  ];

  if (orders.length <= 1) {
    return OrderedLayering(input: input, orderedLayers: orders);
  }

  // Build effective adjacency lookups so reversed edges are still treated as
  // running from the effective source (lower layer) to the effective sink
  // (higher layer).
  // effectivePrevs[v] = ids in layer L-1 that point into v
  // effectiveNexts[u] = ids in layer L+1 that u points into
  final effectivePrevs = <String, List<String>>{
    for (final n in graph.nodes) n.id: <String>[],
  };
  final effectiveNexts = <String, List<String>>{
    for (final n in graph.nodes) n.id: <String>[],
  };
  for (final e in graph.edges) {
    if (e.src == e.dst) continue;
    final from = e.isReversed ? e.dst : e.src;
    final to = e.isReversed ? e.src : e.dst;
    final lf = layering.nodeLayer[from];
    final lt = layering.nodeLayer[to];
    if (lf == null || lt == null) continue;
    // After insertDummyNodes, |lt - lf| should be exactly 1, but we guard
    // just in case (e.g., the caller fed us a graph without going through
    // dummy insertion).
    if (lt > lf) {
      effectiveNexts[from]!.add(to);
      effectivePrevs[to]!.add(from);
    } else if (lf > lt) {
      effectiveNexts[to]!.add(from);
      effectivePrevs[from]!.add(to);
    }
  }

  bool sortLayerByBarycenter(
    int layerIndex,
    Map<String, List<String>> neighbourMap,
    Map<String, int> neighbourPositions,
  ) {
    final layer = orders[layerIndex];
    if (layer.isEmpty) return false;
    // Compute barycenter; nodes with no neighbours keep their current index
    // so they're treated as already in-position.
    final barys = <String, double>{};
    final originalIndex = <String, int>{
      for (var i = 0; i < layer.length; i++) layer[i]: i,
    };
    for (final id in layer) {
      final neigh = neighbourMap[id] ?? const <String>[];
      if (neigh.isEmpty) {
        barys[id] = originalIndex[id]!.toDouble();
        continue;
      }
      var sum = 0.0;
      var count = 0;
      for (final n in neigh) {
        final pos = neighbourPositions[n];
        if (pos == null) continue;
        sum += pos;
        count += 1;
      }
      barys[id] = count == 0 ? originalIndex[id]!.toDouble() : sum / count;
    }

    // Stable sort by (barycenter, original index). Dart's List.sort isn't
    // stable, so we sort a list of records with the original index baked in
    // as the tie-breaker.
    final sorted = [
      for (var i = 0; i < layer.length; i++)
        (id: layer[i], bary: barys[layer[i]]!, originalIndex: i),
    ];
    sorted.sort((a, b) {
      final cmp = a.bary.compareTo(b.bary);
      if (cmp != 0) return cmp;
      return a.originalIndex.compareTo(b.originalIndex);
    });

    var changed = false;
    for (var i = 0; i < sorted.length; i++) {
      if (orders[layerIndex][i] != sorted[i].id) {
        changed = true;
        break;
      }
    }
    if (changed) {
      orders[layerIndex] = [for (final r in sorted) r.id];
    }
    return changed;
  }

  Map<String, int> positionsOf(int layerIndex) {
    final layer = orders[layerIndex];
    return {for (var i = 0; i < layer.length; i++) layer[i]: i};
  }

  for (var sweep = 0; sweep < maxSweeps; sweep++) {
    var changed = false;

    // Down sweep: layers 1..L-1, sort by predecessor positions.
    for (var k = 1; k < orders.length; k++) {
      final prevPositions = positionsOf(k - 1);
      if (sortLayerByBarycenter(k, effectivePrevs, prevPositions)) {
        changed = true;
      }
    }

    // Up sweep: layers L-2..0, sort by successor positions.
    for (var k = orders.length - 2; k >= 0; k--) {
      final nextPositions = positionsOf(k + 1);
      if (sortLayerByBarycenter(k, effectiveNexts, nextPositions)) {
        changed = true;
      }
    }

    if (!changed) break;
  }

  return OrderedLayering(input: input, orderedLayers: orders);
}
