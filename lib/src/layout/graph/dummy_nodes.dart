/// Long-edge subdivision for the Sugiyama framework (Phase 2, step 1).
///
/// After layering, any edge that spans more than one layer is replaced by a
/// chain of dummy nodes (one per intermediate layer) and short edges that
/// each connect adjacent layers. This makes the layered graph "proper" so
/// crossing reduction and coordinate assignment only need to think about
/// edges between consecutive layers. Phase 4 (edge routing) reconstructs the
/// original edge's path from the dummy chain using
/// [ProperLayering.dummyOriginalEdge].
library;

import 'graph.dart';
import 'layering.dart';

/// Prefix used for synthetic dummy node ids.
const String kDummyNodePrefix = '__dummy_';

/// Prefix used for synthetic segment edge ids that subdivide a long edge.
const String kDummyEdgePrefix = '__dummyedge_';

/// The result of dummy-node insertion: a graph in which every (non-self-loop)
/// edge spans exactly one layer.
class ProperLayering {
  /// The augmented DAG, containing both original real nodes/edges and any
  /// inserted dummy nodes / chain segments. Edges that were short to begin
  /// with are carried over unchanged; long edges are removed from this graph
  /// and replaced by their dummy chain.
  final Graph graph;

  /// Layer assignment for [graph]. Every dummy node has a layer; every
  /// non-self-loop edge in [graph] connects layer L to layer L+1 (taking
  /// [GraphEdge.isReversed] into account).
  final Layering layering;

  /// Maps each dummy node id to the id of the original long edge it belongs
  /// to. Real nodes are not present in this map.
  final Map<String, String> dummyOriginalEdge;

  const ProperLayering({
    required this.graph,
    required this.layering,
    required this.dummyOriginalEdge,
  });
}

/// Subdivide every long edge in [dag] by inserting dummy nodes at each
/// intermediate layer.
///
/// An edge `u -> v` (or, if reversed, effectively `v -> u`) is "long" when
/// the absolute layer difference between its endpoints is greater than one.
/// Self-loops and edges whose endpoints are missing from [layering] are left
/// untouched.
ProperLayering insertDummyNodes(Graph dag, Layering layering) {
  // Carry over all real nodes and start collecting any dummies we create.
  final newNodes = <GraphNode>[...dag.nodes];
  final newEdges = <GraphEdge>[];
  final dummyOriginalEdge = <String, String>{};
  final nodeLayer = Map<String, int>.from(layering.nodeLayer);

  for (final edge in dag.edges) {
    // Self-loop: keep as is. Crossing reduction / routing handles it.
    if (edge.src == edge.dst) {
      newEdges.add(edge);
      continue;
    }
    final srcLayer = layering.nodeLayer[edge.src];
    final dstLayer = layering.nodeLayer[edge.dst];
    if (srcLayer == null || dstLayer == null) {
      newEdges.add(edge);
      continue;
    }

    // Determine the "effective" lower and upper layer of the edge so we can
    // subdivide regardless of whether the edge was reversed by cycle removal.
    final effectiveFromLayer =
        edge.isReversed ? dstLayer : srcLayer;
    final effectiveToLayer = edge.isReversed ? srcLayer : dstLayer;
    final span = effectiveToLayer - effectiveFromLayer;

    if (span <= 1 && span >= -1) {
      // Short edge (or zero-span, which shouldn't normally happen post
      // layering but is safe to pass through).
      newEdges.add(edge);
      continue;
    }

    // Long edge: build a chain of dummy nodes at each intermediate layer.
    // The chain stays oriented from the effective source to the effective
    // sink. The replacement edges all carry isReversed=false: the original
    // reversal has already been "consumed" by laying the chain out in the
    // effective direction. Phase 4 will restitch the original edge.
    final ascending = effectiveToLayer > effectiveFromLayer;
    final loLayer =
        ascending ? effectiveFromLayer : effectiveToLayer;
    final hiLayer =
        ascending ? effectiveToLayer : effectiveFromLayer;

    // Effective source / sink real node ids (so the chain is built in topo
    // order regardless of isReversed).
    final effectiveSrcId = edge.isReversed ? edge.dst : edge.src;
    final effectiveDstId = edge.isReversed ? edge.src : edge.dst;

    // Create one dummy per intermediate layer.
    final dummyIds = <String>[];
    for (var layer = loLayer + 1; layer < hiLayer; layer++) {
      final dummyId = '$kDummyNodePrefix${edge.id}_$layer';
      newNodes.add(GraphNode(
        id: dummyId,
        width: 1,
        height: 1,
      ));
      nodeLayer[dummyId] = layer;
      dummyOriginalEdge[dummyId] = edge.id;
      dummyIds.add(dummyId);
    }

    // Build the chain of segment edges. Segment i connects chainNodes[i] ->
    // chainNodes[i+1]. We preserve the visual style (dash + head) on the
    // final segment so the arrowhead lands on the real target; intermediate
    // segments are styled as plain dashed/solid continuations with no head.
    final chain = <String>[
      effectiveSrcId,
      ...dummyIds,
      effectiveDstId,
    ];
    for (var i = 0; i < chain.length - 1; i++) {
      final isLast = i == chain.length - 2;
      final segmentId = '$kDummyEdgePrefix${edge.id}_$i';
      newEdges.add(GraphEdge(
        id: segmentId,
        src: chain[i],
        dst: chain[i + 1],
        label: isLast ? edge.label : null,
        isDashed: edge.isDashed,
        head: isLast ? edge.head : EdgeHead.none,
        // The chain is laid out in effective (forward) direction, so no
        // segment is "reversed" relative to its endpoints' layers.
        isReversed: false,
      ));
    }
  }

  // Re-bucket layers, including dummy ids. The relative order of real nodes
  // within each layer is preserved (we walk layering.layers in order); new
  // dummies are appended to their layer in edge-iteration order so that the
  // initial ordering passed to crossing reduction is deterministic.
  final byLayer = <int, List<String>>{};
  for (final layer in nodeLayer.values) {
    byLayer.putIfAbsent(layer, () => <String>[]);
  }
  // First insert real nodes in the order layering.layers gives us, so we
  // remain stable for nodes that already had a position.
  for (var k = 0; k < layering.layers.length; k++) {
    for (final id in layering.layers[k]) {
      byLayer.putIfAbsent(k, () => <String>[]).add(id);
    }
  }
  // Then append dummies (in creation / edge-iteration order).
  for (final n in newNodes) {
    if (!n.id.startsWith(kDummyNodePrefix)) continue;
    final layer = nodeLayer[n.id]!;
    byLayer.putIfAbsent(layer, () => <String>[]).add(n.id);
  }

  var maxLayer = 0;
  for (final l in byLayer.keys) {
    if (l > maxLayer) maxLayer = l;
  }
  final layers =
      List<List<String>>.generate(maxLayer + 1, (k) => byLayer[k] ?? <String>[]);

  final newGraph = Graph(
    nodes: newNodes,
    edges: newEdges,
    clusters: dag.clusters,
  );
  final newLayering = Layering(
    nodeLayer: Map.unmodifiable(nodeLayer),
    layers: layers,
  );

  return ProperLayering(
    graph: newGraph,
    layering: newLayering,
    dummyOriginalEdge: Map.unmodifiable(dummyOriginalEdge),
  );
}
