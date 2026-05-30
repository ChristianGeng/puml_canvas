/// Greedy DFS-based cycle removal for the Sugiyama framework.
///
/// We don't physically reverse edges in the [Graph]; we mark
/// [GraphEdge.isReversed] = true so subsequent phases treat the graph as a
/// DAG. This is a heuristic minimum feedback arc set: it doesn't need to be
/// optimal, just sufficient to break every cycle.
library;

import 'graph.dart';

/// Returns a new [Graph] in which any edge that participated in a cycle
/// (back-edge in a DFS) is marked with [GraphEdge.isReversed] = true. Forward
/// and cross edges are left untouched. Self-loops are also marked reversed
/// so layering can skip them safely.
Graph removeCycles(Graph input) {
  // Visit state: 0 = unvisited, 1 = on current DFS stack, 2 = fully done.
  final state = <String, int>{
    for (final n in input.nodes) n.id: 0,
  };

  // Set of edge ids that should be marked reversed.
  final reversedIds = <String>{};

  // Iterative DFS to avoid blowing the stack on deep graphs. Each stack
  // entry tracks the node id plus an index into its outgoing edges list.
  void dfs(String startId) {
    final stack = <_Frame>[];
    state[startId] = 1;
    stack.add(_Frame(startId, 0));

    while (stack.isNotEmpty) {
      final frame = stack.last;
      final outgoing = input.edgesFrom(frame.nodeId);

      if (frame.index >= outgoing.length) {
        // Finished this node.
        state[frame.nodeId] = 2;
        stack.removeLast();
        continue;
      }

      final edge = outgoing[frame.index++];

      // Already-marked-reversed edges (e.g. on a re-run) are skipped to
      // avoid double-marking. They behave as if removed for traversal.
      if (reversedIds.contains(edge.id)) {
        continue;
      }

      // Self-loops are inherently cyclic; mark them and skip recursion.
      if (edge.src == edge.dst) {
        reversedIds.add(edge.id);
        continue;
      }

      final dstState = state[edge.dst] ?? 0;
      if (dstState == 1) {
        // Back-edge to a node on the current DFS path -> reverse it.
        reversedIds.add(edge.id);
      } else if (dstState == 0) {
        state[edge.dst] = 1;
        stack.add(_Frame(edge.dst, 0));
      }
      // dstState == 2: forward / cross edge, leave as-is.
    }
  }

  for (final n in input.nodes) {
    if (state[n.id] == 0) {
      dfs(n.id);
    }
  }

  if (reversedIds.isEmpty) {
    return input;
  }

  final newEdges = [
    for (final e in input.edges)
      if (reversedIds.contains(e.id)) e.copyWith(isReversed: true) else e,
  ];

  return Graph(
    nodes: input.nodes,
    edges: newEdges,
    clusters: input.clusters,
  );
}

class _Frame {
  final String nodeId;
  int index;
  _Frame(this.nodeId, this.index);
}
