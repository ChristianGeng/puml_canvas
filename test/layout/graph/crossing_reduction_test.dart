import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/layout/graph/crossing_reduction.dart';
import 'package:puml_canvas/src/layout/graph/dummy_nodes.dart';
import 'package:puml_canvas/src/layout/graph/graph.dart';
import 'package:puml_canvas/src/layout/graph/layering.dart';

GraphNode _n(String id) => GraphNode(id: id, width: 10, height: 10);
GraphEdge _e(String id, String s, String d) =>
    GraphEdge(id: id, src: s, dst: d);

/// Count crossings between two adjacent ordered layers given the list of
/// edges that connect them.
int _countCrossings(
  List<String> upper,
  List<String> lower,
  List<({String u, String v})> edges,
) {
  final posUpper = {for (var i = 0; i < upper.length; i++) upper[i]: i};
  final posLower = {for (var i = 0; i < lower.length; i++) lower[i]: i};
  var c = 0;
  for (var i = 0; i < edges.length; i++) {
    for (var j = i + 1; j < edges.length; j++) {
      final a = edges[i];
      final b = edges[j];
      final ai = posUpper[a.u]!;
      final aj = posLower[a.v]!;
      final bi = posUpper[b.u]!;
      final bj = posLower[b.v]!;
      if ((ai < bi && aj > bj) || (ai > bi && aj < bj)) c++;
    }
  }
  return c;
}

void main() {
  group('reduceCrossings (barycenter)', () {
    test('2-layer graph with crossings reorders to remove them', () {
      // Top layer ids start as [A, B], bottom as [C, D]. Edges A->D and
      // B->C cross. After reduction we expect no crossings.
      final g = Graph(
        nodes: [_n('A'), _n('B'), _n('C'), _n('D')],
        edges: [
          _e('e1', 'A', 'D'),
          _e('e2', 'B', 'C'),
        ],
      );
      final l = assignLayers(g);
      final p = insertDummyNodes(g, l);
      final r = reduceCrossings(p);

      // Both layers must have all original nodes, possibly reordered.
      final upper = r.orderedLayers[0];
      final lower = r.orderedLayers[1];
      expect(upper.toSet(), {'A', 'B'});
      expect(lower.toSet(), {'C', 'D'});

      final crossings = _countCrossings(upper, lower, [
        (u: 'A', v: 'D'),
        (u: 'B', v: 'C'),
      ]);
      expect(crossings, 0);
    });

    test('3-layer easy structure: barycenter pulls connected nodes together',
        () {
      // Layer 0: a1, a2
      // Layer 1: b1, b2, b3
      // Layer 2: c1, c2
      // Edges: a1->b3, a2->b1, b1->c2, b3->c1. (Both an upper and lower
      // crossing in the initial ordering.)
      final g = Graph(
        nodes: [
          _n('a1'),
          _n('a2'),
          _n('b1'),
          _n('b2'),
          _n('b3'),
          _n('c1'),
          _n('c2'),
        ],
        edges: [
          _e('e1', 'a1', 'b3'),
          _e('e2', 'a2', 'b1'),
          _e('e3', 'b1', 'c2'),
          _e('e4', 'b3', 'c1'),
          // Force b2 to layer 1 with a harmless anchor.
          _e('anchor', 'a1', 'b2'),
        ],
      );
      final l = assignLayers(g);
      final p = insertDummyNodes(g, l);
      final r = reduceCrossings(p);

      // Count crossings on each adjacent layer pair.
      final cross01 = _countCrossings(
        r.orderedLayers[0],
        r.orderedLayers[1],
        [
          (u: 'a1', v: 'b3'),
          (u: 'a2', v: 'b1'),
          (u: 'a1', v: 'b2'),
        ],
      );
      final cross12 = _countCrossings(
        r.orderedLayers[1],
        r.orderedLayers[2],
        [
          (u: 'b1', v: 'c2'),
          (u: 'b3', v: 'c1'),
        ],
      );
      // Both should reduce to 0 with this structure.
      expect(cross01, 0);
      expect(cross12, 0);
    });

    test('already optimal: orderings remain stable', () {
      // Path graph with no crossings possible. Output ordering should equal
      // input ordering.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'b', 'c')],
      );
      final l = assignLayers(g);
      final p = insertDummyNodes(g, l);
      final r = reduceCrossings(p);
      for (var k = 0; k < r.orderedLayers.length; k++) {
        expect(r.orderedLayers[k], p.layering.layers[k]);
      }
    });

    test('converges within maxSweeps and returns deterministic result', () {
      final g = Graph(
        nodes: [
          _n('a'),
          _n('b'),
          _n('c'),
          _n('d'),
          _n('e'),
          _n('f'),
        ],
        edges: [
          _e('e1', 'a', 'e'),
          _e('e2', 'b', 'd'),
          _e('e3', 'c', 'f'),
          _e('e4', 'a', 'd'),
          _e('e5', 'b', 'f'),
        ],
      );
      final l = assignLayers(g);
      final p = insertDummyNodes(g, l);
      final r1 = reduceCrossings(p);
      final r2 = reduceCrossings(p);
      // Determinism: same input, same output.
      for (var k = 0; k < r1.orderedLayers.length; k++) {
        expect(r1.orderedLayers[k], r2.orderedLayers[k]);
      }
    });

    test('with dummy nodes from long edges, ordering still respects layers',
        () {
      // A->B->C->D, plus a long edge A->D that gets 2 dummies.
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
      final p = insertDummyNodes(g, l);
      final r = reduceCrossings(p);

      // Each ordered layer must equal (as a set) the proper layering's
      // layer.
      for (var k = 0; k < r.orderedLayers.length; k++) {
        expect(r.orderedLayers[k].toSet(),
            p.layering.layers[k].toSet());
      }
      // Layer 1 should contain b and exactly one dummy.
      final layer1 = r.orderedLayers[1];
      expect(layer1.length, 2);
      expect(layer1.contains('b'), isTrue);
      expect(
        layer1.any((id) => id.startsWith(kDummyNodePrefix)),
        isTrue,
      );
    });
  });
}
