import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/layout/graph/graph.dart';
import 'package:puml_canvas/src/layout/graph/layering.dart';

GraphNode _n(String id) => GraphNode(id: id, width: 10, height: 10);
GraphEdge _e(String id, String s, String d) =>
    GraphEdge(id: id, src: s, dst: d);

void main() {
  group('assignLayers (longest path)', () {
    test('linear chain A->B->C->D produces layers 0,1,2,3', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'd'),
        ],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['a'], 0);
      expect(l.nodeLayer['b'], 1);
      expect(l.nodeLayer['c'], 2);
      expect(l.nodeLayer['d'], 3);
      expect(l.layerCount, 4);
    });

    test('diamond A->B, A->C, B->D, C->D places A at 0, D at 2', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'a', 'c'),
          _e('e3', 'b', 'd'),
          _e('e4', 'c', 'd'),
        ],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['a'], 0);
      expect(l.nodeLayer['b'], 1);
      expect(l.nodeLayer['c'], 1);
      expect(l.nodeLayer['d'], 2);
      expect(l.layerCount, 3);
    });

    test('disconnected components both start at layer 0', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('x'), _n('y')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'x', 'y')],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['a'], 0);
      expect(l.nodeLayer['x'], 0);
      expect(l.nodeLayer['b'], 1);
      expect(l.nodeLayer['y'], 1);
      expect(l.layerCount, 2);
    });

    test('already-layered tree assigns canonical layers', () {
      // Tree:
      //   root
      //   / \
      //  a   b
      //  |
      //  c
      final g = Graph(
        nodes: [_n('root'), _n('a'), _n('b'), _n('c')],
        edges: [
          _e('e1', 'root', 'a'),
          _e('e2', 'root', 'b'),
          _e('e3', 'a', 'c'),
        ],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['root'], 0);
      expect(l.nodeLayer['a'], 1);
      expect(l.nodeLayer['b'], 1);
      expect(l.nodeLayer['c'], 2);
      expect(l.layerCount, 3);
    });

    test('reversed edge is respected when computing layers', () {
      // Originally A->B->A; after cycle removal the back-edge is reversed.
      // Effective DAG should yield two layers.
      final g = Graph(
        nodes: [_n('a'), _n('b')],
        edges: [
          _e('e1', 'a', 'b'),
          GraphEdge(id: 'e2', src: 'b', dst: 'a', isReversed: true),
        ],
      );
      final l = assignLayers(g);
      // Both edges effectively go a->b.
      expect(l.nodeLayer['a'], 0);
      expect(l.nodeLayer['b'], 1);
      expect(l.layerCount, 2);
    });

    test('self-loops do not affect layering', () {
      final g = Graph(
        nodes: [_n('a'), _n('b')],
        edges: [
          _e('loop', 'a', 'a'),
          _e('e1', 'a', 'b'),
        ],
      );
      final l = assignLayers(g);
      expect(l.nodeLayer['a'], 0);
      expect(l.nodeLayer['b'], 1);
    });
  });
}
