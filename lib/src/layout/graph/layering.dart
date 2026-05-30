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
///
/// [sameRank] is an optional set of node-id pairs that must share a layer
/// (e.g. PlantUML horizontal `A -> B` transitions). When empty (the default)
/// the behavior is the plain longest-path assignment described above and is
/// byte-identical to the no-constraint engine. When non-empty, the connected
/// components of the same-rank relation are collapsed into a single "group"
/// for layering: the group DAG is layered by longest path, and every member
/// of a group inherits the group's layer. A common successor of two same-rank
/// nodes therefore sits exactly one layer below them and centers between them.
Layering assignLayers(
  Graph dagGraph, {
  Set<(String, String)> sameRank = const {},
}) {
  // --- Same-rank grouping (union-find over node ids) -----------------------
  final parent = <String, String>{for (final n in dagGraph.nodes) n.id: n.id};
  String find(String x) {
    var root = x;
    while (parent[root] != root) {
      root = parent[root]!;
    }
    // Path compression.
    var cur = x;
    while (parent[cur] != root) {
      final next = parent[cur]!;
      parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(String a, String b) {
    if (!parent.containsKey(a) || !parent.containsKey(b)) return;
    final ra = find(a);
    final rb = find(b);
    if (ra != rb) parent[ra] = rb;
  }

  for (final pair in sameRank) {
    union(pair.$1, pair.$2);
  }

  String groupOf(String id) => find(id);

  // --- Build group-level effective edges -----------------------------------
  // Group predecessors/successors for longest-path layering. Edges WITHIN a
  // group (both endpoints in the same group, e.g. the horizontal edge itself)
  // impose no layer constraint and are dropped here.
  final groupPreds = <String, Set<String>>{};
  final groupSuccs = <String, Set<String>>{};
  final groupIds = <String>{for (final n in dagGraph.nodes) groupOf(n.id)};
  for (final g in groupIds) {
    groupPreds[g] = <String>{};
    groupSuccs[g] = <String>{};
  }

  for (final e in dagGraph.edges) {
    if (e.src == e.dst) continue; // self-loop, skip
    final from = e.isReversed ? e.dst : e.src;
    final to = e.isReversed ? e.src : e.dst;
    if (!parent.containsKey(from) || !parent.containsKey(to)) continue;
    final gf = groupOf(from);
    final gt = groupOf(to);
    if (gf == gt) continue; // intra-group edge: no ranking constraint
    groupSuccs[gf]!.add(gt);
    groupPreds[gt]!.add(gf);
  }

  // --- Longest-path layering over groups (Kahn's topo sort) ----------------
  final inDegree = <String, int>{
    for (final g in groupIds) g: groupPreds[g]!.length,
  };
  final queue = <String>[];
  for (final g in groupIds) {
    if ((inDegree[g] ?? 0) == 0) queue.add(g);
  }

  final groupLayer = <String, int>{};
  var head = 0;
  while (head < queue.length) {
    final u = queue[head++];
    final layerU = groupLayer[u] ?? 0;
    groupLayer[u] = layerU;
    for (final v in groupSuccs[u] ?? const <String>{}) {
      final candidate = layerU + 1;
      final existing = groupLayer[v];
      if (existing == null || candidate > existing) {
        groupLayer[v] = candidate;
      }
      final remaining = (inDegree[v] ?? 0) - 1;
      inDegree[v] = remaining;
      if (remaining == 0) queue.add(v);
    }
  }

  // Any group not reached (residual cycle) gets layer 0 as a safe fallback.
  for (final g in groupIds) {
    groupLayer.putIfAbsent(g, () => 0);
  }

  // --- Project group layers back onto nodes --------------------------------
  final nodeLayer = <String, int>{
    for (final n in dagGraph.nodes) n.id: groupLayer[groupOf(n.id)]!,
  };

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
