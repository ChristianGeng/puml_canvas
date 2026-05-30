import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/layout/graph/dummy_nodes.dart';
import 'package:puml_canvas/src/layout/graph/graph.dart';
import 'package:puml_canvas/src/layout/graph/sugiyama.dart';

GraphNode _n(String id) => GraphNode(id: id, width: 10, height: 10);
GraphEdge _e(String id, String s, String d) =>
    GraphEdge(id: id, src: s, dst: d);

void main() {
  group('runSugiyama (Phase 1)', () {
    test('cycle is broken and layering respects effective edge direction', () {
      // A->B->C->A, plus A->D, plus E->A.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d'), _n('e')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'a'),
          _e('e4', 'a', 'd'),
          _e('e5', 'e', 'a'),
        ],
      );

      final r = runSugiyama(g);

      // Every node should have a layer.
      for (final n in g.nodes) {
        expect(r.layering.nodeLayer.containsKey(n.id), isTrue,
            reason: 'node ${n.id} should have a layer');
      }

      // Every non-self-loop edge, taking isReversed into account, must point
      // strictly from a lower-layer node to a higher-layer node.
      for (final edge in r.dag.edges) {
        if (edge.src == edge.dst) continue;
        final from = edge.isReversed ? edge.dst : edge.src;
        final to = edge.isReversed ? edge.src : edge.dst;
        final lf = r.layering.nodeLayer[from]!;
        final lt = r.layering.nodeLayer[to]!;
        expect(lt > lf, isTrue,
            reason:
                'effective edge $from->$to should go to a strictly higher '
                'layer (got $lf -> $lt) for original edge ${edge.id}');
      }

      // At least one edge from the original cycle must be marked reversed.
      final reversed = r.dag.edges.where((e) => e.isReversed).toList();
      expect(reversed.isNotEmpty, isTrue);
    });

    test('acyclic input is returned unchanged structurally', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'b', 'c')],
      );
      final r = runSugiyama(g);
      expect(r.dag.edges.where((e) => e.isReversed).isEmpty, isTrue);
      expect(r.layering.nodeLayer['a'], 0);
      expect(r.layering.nodeLayer['b'], 1);
      expect(r.layering.nodeLayer['c'], 2);
    });

    test('Phase 2 integration: cycle + long edge produces ordered proper '
        'layering', () {
      // A->B->C->A (cycle), plus a long edge A->D with chain A->B->C->D.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'a'), // back-edge, will be reversed
          _e('e4', 'c', 'd'),
          _e('long', 'a', 'd'),
        ],
      );

      final r = runSugiyama(g);

      // properLayering: every edge spans exactly one layer.
      for (final e in r.properLayering.graph.edges) {
        if (e.src == e.dst) continue;
        final lf = r.properLayering.layering.nodeLayer[e.src]!;
        final lt = r.properLayering.layering.nodeLayer[e.dst]!;
        expect((lt - lf).abs(), 1,
            reason:
                'proper-layered edge ${e.id} must connect adjacent layers');
      }

      // orderedLayering: each layer is a fully populated list and contains
      // exactly the ids the proper layering placed there.
      for (var k = 0; k < r.orderedLayering.orderedLayers.length; k++) {
        expect(
          r.orderedLayering.orderedLayers[k].toSet(),
          r.properLayering.layering.layers[k].toSet(),
        );
      }

      // At least one dummy must exist (the long edge a->d spans >1 layer).
      final hasDummy = r.properLayering.graph.nodes
          .any((n) => n.id.startsWith(kDummyNodePrefix));
      expect(hasDummy, isTrue);
    });

    test('layers list partitions all nodes exactly once', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'a', 'c'),
          _e('e3', 'b', 'd'),
          _e('e4', 'c', 'd'),
        ],
      );
      final r = runSugiyama(g);
      final flat = <String>[
        for (final layer in r.layering.layers) ...layer,
      ];
      expect(flat.toSet(), {'a', 'b', 'c', 'd'});
      expect(flat.length, 4);
    });

    test('Phase 3 integration: every node gets a coordinate and bounds are '
        'sensible', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'a', 'c'),
          _e('e3', 'b', 'd'),
          _e('e4', 'c', 'd'),
          _e('long', 'a', 'd'), // spans 2 layers; produces a dummy
        ],
      );
      final r = runSugiyama(g);
      // Every node in the properLayering graph (real + dummy) has coords.
      for (final n in r.properLayering.graph.nodes) {
        expect(r.coordinates.xByNode.containsKey(n.id), isTrue,
            reason: 'node ${n.id} should have an x');
        expect(r.coordinates.yByNode.containsKey(n.id), isTrue,
            reason: 'node ${n.id} should have a y');
      }
      // Bounds are non-negative and finite.
      expect(r.coordinates.totalWidth, greaterThan(0));
      expect(r.coordinates.totalHeight, greaterThan(0));
      // a should be at the top layer, d at the bottom.
      expect(r.coordinates.yByNode['a']! < r.coordinates.yByNode['b']!,
          isTrue);
      expect(r.coordinates.yByNode['b']! < r.coordinates.yByNode['d']!,
          isTrue);
    });
  });
}
