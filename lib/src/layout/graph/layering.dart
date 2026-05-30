/// Longest-path layer assignment for the Sugiyama framework.
///
/// Operates on a DAG (after [cycle_removal.removeCycles]). For each edge, the
/// "effective" direction respects [GraphEdge.isReversed]: a reversed edge
/// from src->dst is treated as if it ran dst->src for layering.
library;

import 'graph.dart';

/// The result of layer assignment: which layer each node lives on, and the
/// (unordered) lists of node ids per layer.
class Layering {
  final Map<String, int> nodeLayer;
  final List<List<String>> layers;

  const Layering({required this.nodeLayer, required this.layers});

  int get layerCount => layers.length;
}

/// Longest-path layer assignment.
///
/// Layer 0 holds all nodes with no effective predecessors. For every other
/// node `v`, `layer(v) = 1 + max(layer(u))` over all effective predecessors
/// `u`. Reversed edges count for layering with their direction flipped.
/// Self-loops are ignored (they were marked reversed by cycle removal and
/// neither side imposes a real predecessor constraint).
Layering assignLayers(Graph dagGraph) {
  // Build effective predecessor and successor maps.
  final preds = <String, List<String>>{
    for (final n in dagGraph.nodes) n.id: <String>[],
  };
  final succs = <String, List<String>>{
    for (final n in dagGraph.nodes) n.id: <String>[],
  };

  for (final e in dagGraph.edges) {
    if (e.src == e.dst) continue; // self-loop, skip
    final from = e.isReversed ? e.dst : e.src;
    final to = e.isReversed ? e.src : e.dst;
    // Defensive: only add if both nodes exist in the graph.
    if (preds.containsKey(to) && succs.containsKey(from)) {
      preds[to]!.add(from);
      succs[from]!.add(to);
    }
  }

  // Kahn's topological sort to detect any leftover cycles (shouldn't happen
  // after cycle removal, but we guard) and to assign layers in topo order.
  final inDegree = <String, int>{
    for (final entry in preds.entries) entry.key: entry.value.length,
  };
  final queue = <String>[];
  for (final n in dagGraph.nodes) {
    if ((inDegree[n.id] ?? 0) == 0) {
      queue.add(n.id);
    }
  }

  final nodeLayer = <String, int>{};
  var head = 0;
  while (head < queue.length) {
    final u = queue[head++];
    final layerU = nodeLayer[u] ?? 0;
    nodeLayer[u] = layerU;
    for (final v in succs[u] ?? const []) {
      final candidate = layerU + 1;
      final existing = nodeLayer[v];
      if (existing == null || candidate > existing) {
        nodeLayer[v] = candidate;
      }
      final remaining = (inDegree[v] ?? 0) - 1;
      inDegree[v] = remaining;
      if (remaining == 0) {
        queue.add(v);
      }
    }
  }

  // Any node not reached by Kahn's algorithm (would indicate a residual
  // cycle) gets layer 0 as a safe fallback.
  for (final n in dagGraph.nodes) {
    nodeLayer.putIfAbsent(n.id, () => 0);
  }

  // Bucket into layers.
  var maxLayer = 0;
  for (final l in nodeLayer.values) {
    if (l > maxLayer) maxLayer = l;
  }
  final layers = List<List<String>>.generate(maxLayer + 1, (_) => <String>[]);
  for (final n in dagGraph.nodes) {
    layers[nodeLayer[n.id]!].add(n.id);
  }

  return Layering(nodeLayer: Map.unmodifiable(nodeLayer), layers: layers);
}
