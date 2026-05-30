import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/layout/graph/coordinates.dart';
import 'package:puml_canvas/src/layout/graph/crossing_reduction.dart';
import 'package:puml_canvas/src/layout/graph/cycle_removal.dart';
import 'package:puml_canvas/src/layout/graph/dummy_nodes.dart';
import 'package:puml_canvas/src/layout/graph/graph.dart';
import 'package:puml_canvas/src/layout/graph/layering.dart';

GraphNode _n(String id, {double w = 40, double h = 20}) =>
    GraphNode(id: id, width: w, height: h);
GraphEdge _e(String id, String s, String d) =>
    GraphEdge(id: id, src: s, dst: d);

Coordinates _run(Graph g, {CoordinatesConfig? config}) {
  final dag = removeCycles(g);
  final layering = assignLayers(dag);
  final proper = insertDummyNodes(dag, layering);
  final ordered = reduceCrossings(proper);
  return assignCoordinates(
    ordered,
    config: config ?? const CoordinatesConfig(),
  );
}

void main() {
  group('assignCoordinates', () {
    test('single node is placed at origin', () {
      final g = Graph(nodes: [_n('a')], edges: []);
      final c = _run(g);
      // Single node: its left edge is normalized to x=0, top edge to y=0,
      // so the center sits at (w/2, h/2).
      expect(c.xByNode['a'], closeTo(20, 1e-9));
      expect(c.yByNode['a'], closeTo(10, 1e-9));
      expect(c.totalWidth, closeTo(40, 1e-9));
      expect(c.totalHeight, closeTo(20, 1e-9));
    });

    test('linear chain stacks vertically with aligned x', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'b', 'c')],
      );
      final c = _run(g);
      // All three nodes should share the same x because each picks up its
      // single neighbour's position.
      expect(c.xByNode['a'], closeTo(c.xByNode['b']!, 1e-6));
      expect(c.xByNode['b'], closeTo(c.xByNode['c']!, 1e-6));
      // Y should strictly increase top-to-bottom.
      expect(c.yByNode['a']! < c.yByNode['b']!, isTrue);
      expect(c.yByNode['b']! < c.yByNode['c']!, isTrue);
    });

    test('diamond: A and D centered between B and C', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'a', 'c'),
          _e('e3', 'b', 'd'),
          _e('e4', 'c', 'd'),
        ],
      );
      final c = _run(g);
      final bMid = (c.xByNode['b']! + c.xByNode['c']!) / 2;
      expect(c.xByNode['a'], closeTo(bMid, 1e-6));
      expect(c.xByNode['d'], closeTo(bMid, 1e-6));
      // Three layers: a at top, b/c middle, d bottom.
      expect(c.yByNode['a']! < c.yByNode['b']!, isTrue);
      expect(c.yByNode['b'], closeTo(c.yByNode['c']!, 1e-9));
      expect(c.yByNode['c']! < c.yByNode['d']!, isTrue);
    });

    test('long edge with dummy: endpoints share x', () {
      // A->B->C plus a long edge A->C (spans two layers).
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'd'),
          _e('long', 'a', 'd'), // 2-layer span: layer 0 -> layer 2
        ],
      );
      final c = _run(g);
      // The dummy node introduced for the long edge has dummyWidth=0, so
      // it doesn't push anything around; the chain a -> dummy -> d should be
      // roughly vertical.
      expect(c.xByNode['a'], isNotNull);
      expect(c.xByNode['d'], isNotNull);
      // Find the dummy node.
      final dummyKey = c.xByNode.keys
          .firstWhere((k) => k.startsWith(kDummyNodePrefix));
      // Top and bottom of the long edge should be no farther apart in x than
      // half a real-node width — much tighter than they'd be if the dummy
      // contributed full spacing pressure.
      final delta = (c.xByNode['a']! - c.xByNode['d']!).abs();
      expect(delta, lessThan(40),
          reason: 'long-edge endpoints should remain roughly aligned, got '
              'delta=$delta with dummy=${c.xByNode[dummyKey]}');
    });

    test('two unconnected components land side by side', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [_e('e1', 'a', 'b'), _e('e2', 'c', 'd')],
      );
      final c = _run(g);
      // Components don't overlap: every node has the same width=40, so the
      // four nodes should pack into a single row in each layer with
      // nodeSpacing=20 between them.
      // Layer 0 should contain {a, c}; layer 1 should contain {b, d}.
      final xs0 = [c.xByNode['a']!, c.xByNode['c']!]..sort();
      final xs1 = [c.xByNode['b']!, c.xByNode['d']!]..sort();
      // Distance between centers must be >= width (40) + spacing (20) = 60.
      expect(xs0[1] - xs0[0], greaterThanOrEqualTo(60 - 1e-6));
      expect(xs1[1] - xs1[0], greaterThanOrEqualTo(60 - 1e-6));
    });

    test('nodes within a layer never overlap horizontally', () {
      // Wide graph: A,B,C all point to D, then D->E,F,G.
      final g = Graph(
        nodes: [
          _n('a'), _n('b'), _n('c'),
          _n('d'),
          _n('e'), _n('f'), _n('g'),
        ],
        edges: [
          _e('e1', 'a', 'd'),
          _e('e2', 'b', 'd'),
          _e('e3', 'c', 'd'),
          _e('e4', 'd', 'e'),
          _e('e5', 'd', 'f'),
          _e('e6', 'd', 'g'),
        ],
      );
      final c = _run(g);
      // Group ids by layer using y.
      final byY = <double, List<String>>{};
      for (final id in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        byY.putIfAbsent(c.yByNode[id]!, () => []).add(id);
      }
      for (final ids in byY.values) {
        ids.sort((p, q) => c.xByNode[p]!.compareTo(c.xByNode[q]!));
        for (var i = 1; i < ids.length; i++) {
          final left = c.xByNode[ids[i - 1]]! + 20; // half width
          final right = c.xByNode[ids[i]]! - 20;
          expect(right - left, greaterThanOrEqualTo(20 - 1e-6),
              reason: 'nodes ${ids[i - 1]} and ${ids[i]} overlap');
        }
      }
    });

    test('y assignments are normalized to start at 0', () {
      final g = Graph(
        nodes: [_n('a'), _n('b')],
        edges: [_e('e1', 'a', 'b')],
      );
      final c = _run(g);
      // Top node's top edge at y=0.
      expect(c.yByNode['a'], closeTo(10, 1e-9)); // height/2
      // Bottom node sits below with default layerSpacing=40.
      expect(c.yByNode['b'], closeTo(10 + 20 + 40, 1e-9)); // h/2 + h + spacing
    });

    test('custom layerSpacing affects vertical gap', () {
      final g = Graph(
        nodes: [_n('a'), _n('b')],
        edges: [_e('e1', 'a', 'b')],
      );
      final c = _run(
        g,
        config: const CoordinatesConfig(layerSpacing: 100),
      );
      expect(c.yByNode['b']! - c.yByNode['a']!, closeTo(20 + 100, 1e-9));
    });

    test('empty graph returns empty coordinates', () {
      final g = Graph(nodes: [], edges: []);
      final c = _run(g);
      expect(c.xByNode, isEmpty);
      expect(c.yByNode, isEmpty);
      expect(c.totalWidth, 0);
      expect(c.totalHeight, 0);
    });
  });

  group('assignCoordinates clusters', () {
    test('cluster bbox encloses its single member with padding', () {
      const pad = 16.0;
      const titleH = 18.0;
      final g = Graph(
        nodes: [
          GraphNode(id: 'a', width: 40, height: 20, clusterId: 'c1'),
        ],
        edges: [],
        clusters: const [
          GraphCluster(id: 'c1', memberIds: ['a']),
        ],
      );
      final c = _run(g);
      final box = c.clusterBoxes['c1'];
      expect(box, isNotNull);
      // Member a's normalized rect is (0,0)-(40,20).
      expect(box!.left, closeTo(-pad, 1e-6));
      expect(box.right, closeTo(40 + pad, 1e-6));
      expect(box.top, closeTo(-(pad + titleH), 1e-6));
      expect(box.bottom, closeTo(20 + pad, 1e-6));
    });

    test('cluster bbox grows to include nested cluster', () {
      final g = Graph(
        nodes: [
          GraphNode(id: 'a', width: 40, height: 20, clusterId: 'inner'),
        ],
        edges: [],
        clusters: const [
          GraphCluster(id: 'outer', memberIds: []),
          GraphCluster(
              id: 'inner', parentClusterId: 'outer', memberIds: ['a']),
        ],
      );
      final c = _run(g);
      final inner = c.clusterBoxes['inner'];
      final outer = c.clusterBoxes['outer'];
      expect(inner, isNotNull);
      expect(outer, isNotNull);
      // Outer must enclose inner on every side (strictly larger because of
      // the parent's own padding + title inset).
      expect(outer!.left, lessThan(inner!.left));
      expect(outer.top, lessThan(inner.top));
      expect(outer.right, greaterThan(inner.right));
      expect(outer.bottom, greaterThan(inner.bottom));
    });

    test(
        'inter-cluster spacing adds clusterPadding between adjacent nodes in '
        'different clusters', () {
      // Same layer, two top-level clusters each with one node. Force a/b into
      // the same layer by connecting both to a shared child.
      final g = Graph(
        nodes: [
          GraphNode(id: 'a', width: 40, height: 20, clusterId: 'c1'),
          GraphNode(id: 'b', width: 40, height: 20, clusterId: 'c2'),
          GraphNode(id: 'sink', width: 40, height: 20),
        ],
        edges: [
          _e('e1', 'a', 'sink'),
          _e('e2', 'b', 'sink'),
        ],
        clusters: const [
          GraphCluster(id: 'c1', memberIds: ['a']),
          GraphCluster(id: 'c2', memberIds: ['b']),
        ],
      );
      final cWith = _run(g);
      final cWithout = _run(
        Graph(
          nodes: [
            GraphNode(id: 'a', width: 40, height: 20),
            GraphNode(id: 'b', width: 40, height: 20),
            GraphNode(id: 'sink', width: 40, height: 20),
          ],
          edges: [_e('e1', 'a', 'sink'), _e('e2', 'b', 'sink')],
        ),
      );
      // Both layouts place a/b in the same layer. The clustered version must
      // have a strictly larger horizontal gap between them.
      final gapWith =
          (cWith.xByNode['a']! - cWith.xByNode['b']!).abs();
      final gapWithout =
          (cWithout.xByNode['a']! - cWithout.xByNode['b']!).abs();
      expect(gapWith, greaterThan(gapWithout + 16 - 1e-6));
    });

    test('same-cluster adjacent nodes use only nodeSpacing', () {
      final g = Graph(
        nodes: [
          GraphNode(id: 'a', width: 40, height: 20, clusterId: 'c1'),
          GraphNode(id: 'b', width: 40, height: 20, clusterId: 'c1'),
          GraphNode(id: 'sink', width: 40, height: 20, clusterId: 'c1'),
        ],
        edges: [_e('e1', 'a', 'sink'), _e('e2', 'b', 'sink')],
        clusters: const [
          GraphCluster(id: 'c1', memberIds: ['a', 'b', 'sink']),
        ],
      );
      final c = _run(g);
      // a/b share a layer; gap between centers must equal width + nodeSpacing
      // (no cluster boundary crossed).
      final gap = (c.xByNode['a']! - c.xByNode['b']!).abs();
      expect(gap, closeTo(60, 1e-6)); // 40 (width) + 20 (nodeSpacing)
    });

    test('top-level node + clustered node count as different clusters', () {
      final g = Graph(
        nodes: [
          GraphNode(id: 'a', width: 40, height: 20), // top-level
          GraphNode(id: 'b', width: 40, height: 20, clusterId: 'c1'),
          GraphNode(id: 'sink', width: 40, height: 20),
        ],
        edges: [_e('e1', 'a', 'sink'), _e('e2', 'b', 'sink')],
        clusters: const [
          GraphCluster(id: 'c1', memberIds: ['b']),
        ],
      );
      final c = _run(g);
      // a/b share a layer; gap = width + nodeSpacing + clusterPadding (one
      // boundary crossed because b is one cluster deep from the null NCA).
      final gap = (c.xByNode['a']! - c.xByNode['b']!).abs();
      expect(gap, greaterThan(60 + 16 - 1e-6));
    });

    test('clusterTopInsets overrides the default title-height top inset', () {
      const pad = 16.0;
      const titleH = 18.0;
      const overrideInset = 60.0;
      final g = Graph(
        nodes: [
          GraphNode(id: 'a', width: 40, height: 20, clusterId: 'c1'),
        ],
        edges: [],
        clusters: const [
          GraphCluster(id: 'c1', memberIds: ['a']),
        ],
      );
      // Baseline run with the default title-height inset.
      final cDefault = _run(g);
      // Same graph but with a per-cluster override taller than the default.
      final cOverride = _run(
        g,
        config: const CoordinatesConfig(
          clusterTopInsets: {'c1': overrideInset},
        ),
      );
      final defBox = cDefault.clusterBoxes['c1']!;
      final ovrBox = cOverride.clusterBoxes['c1']!;
      // Member rect is unchanged, so the override's top sits exactly
      // `overrideInset` above the top of the member node (instead of the
      // default `titleH`).
      // a's center y is at 10 (h/2). Top of a's rect is y=0. Top of the
      // override bbox is at -(pad + overrideInset).
      expect(ovrBox.top, closeTo(-(pad + overrideInset), 1e-6));
      expect(defBox.top, closeTo(-(pad + titleH), 1e-6));
      expect(ovrBox.top, lessThan(defBox.top));
      // Sides and bottom are unchanged — only the top moves.
      expect(ovrBox.left, closeTo(defBox.left, 1e-6));
      expect(ovrBox.right, closeTo(defBox.right, 1e-6));
      expect(ovrBox.bottom, closeTo(defBox.bottom, 1e-6));
    });
  });
}
