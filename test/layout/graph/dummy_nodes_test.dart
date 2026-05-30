import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/layout/graph/dummy_nodes.dart';
import 'package:puml_canvas/src/layout/graph/graph.dart';
import 'package:puml_canvas/src/layout/graph/layering.dart';

GraphNode _n(String id, {String? clusterId}) =>
    GraphNode(id: id, width: 10, height: 10, clusterId: clusterId);
GraphEdge _e(String id, String s, String d, {bool reversed = false}) =>
    GraphEdge(id: id, src: s, dst: d, isReversed: reversed);

void main() {
  group('insertDummyNodes', () {
    test('no long edges: no dummies inserted', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'b', 'c')],
      );
      final l = assignLayers(g);
      final p = insertDummyNodes(g, l);

      expect(p.dummyOriginalEdge, isEmpty);
      expect(p.graph.nodes.length, 3);
      expect(p.graph.edges.length, 2);
      // No nodes should be dummies.
      for (final n in p.graph.nodes) {
        expect(n.id.startsWith(kDummyNodePrefix), isFalse);
      }
    });

    test('single long edge spanning 2 layers inserts 1 dummy', () {
      // A is layer 0, B layer 1, C layer 2. Edge A->C directly is long
      // (spans 2). We need to make sure C is at layer 2 by adding A->B->C.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('long', 'a', 'c'),
        ],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['a'], 0);
      expect(l.nodeLayer['c'], 2);

      final p = insertDummyNodes(g, l);
      final dummies = p.graph.nodes
          .where((n) => n.id.startsWith(kDummyNodePrefix))
          .toList();
      expect(dummies.length, 1);
      expect(p.dummyOriginalEdge[dummies.single.id], 'long');
      expect(p.layering.nodeLayer[dummies.single.id], 1);

      // The original 'long' edge should be gone from p.graph.edges; in its
      // place we should have 2 segment edges with the dummy edge prefix.
      expect(p.graph.edges.any((e) => e.id == 'long'), isFalse);
      final segs = p.graph.edges
          .where((e) => e.id.startsWith(kDummyEdgePrefix))
          .toList();
      expect(segs.length, 2);
    });

    test('single long edge spanning 3 layers inserts 2 dummies', () {
      // Chain A->B->C->D forces D into layer 3. Edge A->D is long (span 3).
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'd'),
          _e('long', 'a', 'd'),
        ],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['d'], 3);

      final p = insertDummyNodes(g, l);
      final dummies = p.graph.nodes
          .where((n) => n.id.startsWith(kDummyNodePrefix))
          .toList();
      expect(dummies.length, 2);
      for (final d in dummies) {
        expect(p.dummyOriginalEdge[d.id], 'long');
      }
      // Dummies sit at layers 1 and 2.
      final dummyLayers =
          dummies.map((d) => p.layering.nodeLayer[d.id]).toSet();
      expect(dummyLayers, {1, 2});

      // 3 segment edges connect a -> dummy1 -> dummy2 -> d.
      final segs = p.graph.edges
          .where((e) => e.id.startsWith(kDummyEdgePrefix))
          .toList();
      expect(segs.length, 3);
    });

    test('multiple long edges sharing endpoints get separate dummy chains', () {
      // A and X both go to D (layer 3). Each should get its own 2 dummies.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d'), _n('x')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'd'),
          _e('e4', 'x', 'b'), // anchor x to layer 0
          _e('longA', 'a', 'd'),
          _e('longX', 'x', 'd'),
        ],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['d'], 3);
      expect(l.nodeLayer['a'], 0);
      expect(l.nodeLayer['x'], 0);

      final p = insertDummyNodes(g, l);
      final dummies = p.graph.nodes
          .where((n) => n.id.startsWith(kDummyNodePrefix))
          .toList();
      expect(dummies.length, 4); // 2 per long edge, no sharing.

      final byEdge = <String, int>{};
      for (final d in dummies) {
        final origId = p.dummyOriginalEdge[d.id]!;
        byEdge[origId] = (byEdge[origId] ?? 0) + 1;
      }
      expect(byEdge['longA'], 2);
      expect(byEdge['longX'], 2);
    });

    test('dummies do not inherit clusterId from their endpoints', () {
      final g = Graph(
        nodes: [
          _n('a', clusterId: 'C1'),
          _n('b'),
          _n('c'),
        ],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('long', 'a', 'c'),
        ],
        clusters: [
          const GraphCluster(id: 'C1', memberIds: ['a']),
        ],
      );
      final l = assignLayers(g);
      final p = insertDummyNodes(g, l);
      final dummy = p.graph.nodes
          .firstWhere((n) => n.id.startsWith(kDummyNodePrefix));
      // Dummy must be a fresh free-floating node — no cluster membership.
      expect(dummy.clusterId, isNull);

      // Cluster membership of the real node is preserved.
      final realA = p.graph.nodes.firstWhere((n) => n.id == 'a');
      expect(realA.clusterId, 'C1');

      // Cluster itself is carried over untouched.
      expect(p.graph.clusters.length, 1);
      expect(p.graph.clusters.single.memberIds, ['a']);
    });

    test('all edges in result span exactly one layer', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'd'),
          _e('long1', 'a', 'd'),
          _e('long2', 'a', 'c'),
        ],
      );
      final l = assignLayers(g);
      final p = insertDummyNodes(g, l);
      for (final e in p.graph.edges) {
        if (e.src == e.dst) continue;
        final lf = p.layering.nodeLayer[e.src]!;
        final lt = p.layering.nodeLayer[e.dst]!;
        expect((lt - lf).abs(), 1,
            reason: 'edge ${e.id} should span exactly one layer');
      }
    });
  });
}
