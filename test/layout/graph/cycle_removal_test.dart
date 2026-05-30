import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/layout/graph/cycle_removal.dart';
import 'package:puml_canvas/src/layout/graph/graph.dart';

GraphNode _n(String id) => GraphNode(id: id, width: 10, height: 10);
GraphEdge _e(String id, String s, String d) =>
    GraphEdge(id: id, src: s, dst: d);

void main() {
  group('removeCycles', () {
    test('linear DAG has no edges reversed', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'b', 'c')],
      );
      final r = removeCycles(g);
      expect(r.edges.where((e) => e.isReversed).isEmpty, isTrue);
    });

    test('simple cycle A->B->A reverses exactly one edge', () {
      final g = Graph(
        nodes: [_n('a'), _n('b')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'b', 'a')],
      );
      final r = removeCycles(g);
      final rev = r.edges.where((e) => e.isReversed).toList();
      expect(rev.length, 1);
    });

    test('triangle cycle A->B->C->A reverses exactly one edge', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'a'),
        ],
      );
      final r = removeCycles(g);
      final rev = r.edges.where((e) => e.isReversed).toList();
      expect(rev.length, 1);
      // The reversed edge must be one of the cycle's edges.
      expect(rev.first.id, anyOf('e1', 'e2', 'e3'));
    });

    test('two independent cycles each get one edge reversed', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'a'),
          _e('e3', 'c', 'd'),
          _e('e4', 'd', 'c'),
        ],
      );
      final r = removeCycles(g);
      final rev = r.edges.where((e) => e.isReversed).toList();
      expect(rev.length, 2);
    });

    test('self-loop A->A is marked reversed', () {
      final g = Graph(
        nodes: [_n('a')],
        edges: [_e('loop', 'a', 'a')],
      );
      final r = removeCycles(g);
      expect(r.edges.single.isReversed, isTrue);
    });

    test('cycle removal yields a DAG (no path follows direction back to '
        'start)', () {
      // A->B->C->A->D plus a side edge.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'a'),
          _e('e4', 'a', 'd'),
        ],
      );
      final r = removeCycles(g);
      // Build effective successor map respecting isReversed.
      final succ = <String, List<String>>{};
      for (final e in r.edges) {
        final from = e.isReversed ? e.dst : e.src;
        final to = e.isReversed ? e.src : e.dst;
        if (from == to) continue;
        succ.putIfAbsent(from, () => []).add(to);
      }
      // Verify acyclic via Kahn.
      final inDeg = <String, int>{for (final n in r.nodes) n.id: 0};
      for (final outs in succ.values) {
        for (final v in outs) {
          inDeg[v] = (inDeg[v] ?? 0) + 1;
        }
      }
      final q = <String>[
        for (final e in inDeg.entries) if (e.value == 0) e.key,
      ];
      var visited = 0;
      var head = 0;
      while (head < q.length) {
        final u = q[head++];
        visited++;
        for (final v in succ[u] ?? const []) {
          inDeg[v] = inDeg[v]! - 1;
          if (inDeg[v] == 0) q.add(v);
        }
      }
      expect(visited, r.nodes.length, reason: 'graph should be acyclic');
    });
  });
}
