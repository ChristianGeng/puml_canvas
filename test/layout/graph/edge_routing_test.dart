import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/layout/graph/coordinates.dart';
import 'package:puml_canvas/src/layout/graph/crossing_reduction.dart';
import 'package:puml_canvas/src/layout/graph/cycle_removal.dart';
import 'package:puml_canvas/src/layout/graph/dummy_nodes.dart';
import 'package:puml_canvas/src/layout/graph/edge_routing.dart';
import 'package:puml_canvas/src/layout/graph/graph.dart';
import 'package:puml_canvas/src/layout/graph/layering.dart';

GraphNode _n(String id, {double w = 40, double h = 20, String? clusterId}) =>
    GraphNode(id: id, width: w, height: h, clusterId: clusterId);
GraphEdge _e(String id, String s, String d) =>
    GraphEdge(id: id, src: s, dst: d);

EdgeRoutes _run(
  Graph g, {
  EdgeRoutingConfig? config,
  CoordinatesConfig? coordsConfig,
}) {
  final dag = removeCycles(g);
  final layering = assignLayers(dag);
  final proper = insertDummyNodes(dag, layering);
  final ordered = reduceCrossings(proper);
  final coords = assignCoordinates(
    ordered,
    config: coordsConfig ?? const CoordinatesConfig(),
  );
  return routeEdges(
    coords,
    originalDag: dag,
    config: config ?? const EdgeRoutingConfig(),
  );
}

EdgeRoute _routeFor(EdgeRoutes routes, String edgeId) {
  return routes.routes.firstWhere(
    (r) => r.edgeId == edgeId,
    orElse: () =>
        throw StateError('no route for $edgeId in ${routes.routes.map((r) => r.edgeId).toList()}'),
  );
}

void main() {
  group('routeEdges', () {
    test('single adjacent-layer edge yields 2-point polyline at attachments', () {
      final g = Graph(
        nodes: [_n('a'), _n('b')],
        edges: [_e('e1', 'a', 'b')],
      );
      final routes = _run(g);
      expect(routes.routes.length, 1);
      final r = _routeFor(routes, 'e1');
      expect(r.points.length, 2);
      expect(r.isReversed, isFalse);

      final coords = routes.input;
      final ax = coords.xByNode['a']!;
      final ay = coords.yByNode['a']!;
      final bx = coords.xByNode['b']!;
      final by = coords.yByNode['b']!;

      // Source: bottom of a (cx, cy + h/2 = cy + 10).
      expect(r.points[0].dx, closeTo(ax, 1e-9));
      expect(r.points[0].dy, closeTo(ay + 10, 1e-9));
      // Dest: top of b.
      expect(r.points[1].dx, closeTo(bx, 1e-9));
      expect(r.points[1].dy, closeTo(by - 10, 1e-9));
    });

    test('long edge with dummy chain yields chain-length+2 points', () {
      // Long edge spanning 3 layers: A -> B -> C -> D plus direct A -> D.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'd'),
          _e('long', 'a', 'd'),
        ],
      );
      final routes = _run(g);
      final r = _routeFor(routes, 'long');
      // Layers: a=0, b=1, c=2, d=3. Long edge intermediate layers = 1, 2 ->
      // 2 dummies. Polyline = src attach + 2 dummies + dst attach = 4.
      expect(r.points.length, 4);
      expect(r.isReversed, isFalse);

      final coords = routes.input;
      // First point near top (above the dummies), last point near bottom.
      for (var i = 1; i < r.points.length; i++) {
        expect(r.points[i].dy, greaterThanOrEqualTo(r.points[i - 1].dy - 1e-6),
            reason: 'long-edge polyline should progress downward, got '
                '${r.points}');
      }
      // First point is a's bottom attachment.
      expect(r.points.first.dy, closeTo(coords.yByNode['a']! + 10, 1e-9));
      // Last point is d's top attachment.
      expect(r.points.last.dy, closeTo(coords.yByNode['d']! - 10, 1e-9));
    });

    test('node with multiple incoming and outgoing edges gets one route each', () {
      // Diamond + extra: A -> B, A -> C, B -> D, C -> D, plus D -> E, D -> F.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d'), _n('e'), _n('f')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'a', 'c'),
          _e('e3', 'b', 'd'),
          _e('e4', 'c', 'd'),
          _e('e5', 'd', 'e'),
          _e('e6', 'd', 'f'),
        ],
      );
      final routes = _run(g);
      final ids = routes.routes.map((r) => r.edgeId).toSet();
      expect(ids, {'e1', 'e2', 'e3', 'e4', 'e5', 'e6'});

      final coords = routes.input;
      // Every route into d should land at d's top, every route out at d's bottom.
      final dTop = coords.yByNode['d']! - 10;
      final dBottom = coords.yByNode['d']! + 10;
      for (final id in ['e3', 'e4']) {
        final r = _routeFor(routes, id);
        expect(r.points.last.dy, closeTo(dTop, 1e-9),
            reason: '$id should terminate at d top');
        expect(r.points.last.dx, closeTo(coords.xByNode['d']!, 1e-9));
      }
      for (final id in ['e5', 'e6']) {
        final r = _routeFor(routes, id);
        expect(r.points.first.dy, closeTo(dBottom, 1e-9),
            reason: '$id should originate at d bottom');
        expect(r.points.first.dx, closeTo(coords.xByNode['d']!, 1e-9));
      }
    });

    test('self-loop produces 5-point loopback to the right', () {
      final g = Graph(
        nodes: [_n('a')],
        edges: [_e('self', 'a', 'a')],
      );
      final routes = _run(g);
      final r = _routeFor(routes, 'self');
      expect(r.points.length, 5);
      // After cycle removal, self-loops are marked reversed.
      expect(r.isReversed, isTrue);

      final coords = routes.input;
      final cx = coords.xByNode['a']!;
      final cy = coords.yByNode['a']!;
      const w = 40.0;
      const sw = 30.0;
      const sh = 20.0;
      expect(r.points[0], Offset(cx + w / 2, cy));
      expect(r.points[1], Offset(cx + w / 2 + sw, cy));
      expect(r.points[2], Offset(cx + w / 2 + sw, cy - sh));
      expect(r.points[3], Offset(cx + w / 2, cy - sh));
      expect(r.points[4], Offset(cx + w / 2, cy));
    });

    test('reversed back-edge: route flows logical src -> dst and isReversed is set', () {
      // Cycle: A -> B -> C -> A. The C -> A edge will be reversed.
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('back', 'c', 'a'),
        ],
      );
      final routes = _run(g);
      final r = _routeFor(routes, 'back');
      expect(r.isReversed, isTrue);

      final coords = routes.input;
      final cx = coords.xByNode['c']!;
      final cy = coords.yByNode['c']!;
      final ax = coords.xByNode['a']!;
      final ay = coords.yByNode['a']!;

      // c is the logical src and sits lower on the page (higher layer);
      // a is the logical dst and sits higher on the page (layer 0).
      expect(cy, greaterThan(ay));

      // First point originates near c (logical src); since c is below a, the
      // outgoing attachment goes up (top of c).
      expect(r.points.first.dx, closeTo(cx, 1e-9));
      expect(r.points.first.dy, closeTo(cy - 10, 1e-9));
      // Last point arrives at a (logical dst), at a's bottom.
      expect(r.points.last.dx, closeTo(ax, 1e-9));
      expect(r.points.last.dy, closeTo(ay + 10, 1e-9));
      // Polyline progresses upward (decreasing y) overall.
      expect(r.points.last.dy, lessThan(r.points.first.dy));
    });

    test('does not emit routes for synthetic dummy segment edges', () {
      final g = Graph(
        nodes: [_n('a'), _n('b'), _n('c'), _n('d')],
        edges: [
          _e('e1', 'a', 'b'),
          _e('e2', 'b', 'c'),
          _e('e3', 'c', 'd'),
          _e('long', 'a', 'd'),
        ],
      );
      final routes = _run(g);
      // Only the 4 original edge ids should appear.
      final ids = routes.routes.map((r) => r.edgeId).toSet();
      expect(ids, {'e1', 'e2', 'e3', 'long'});
      // None of them should be synthetic.
      for (final id in ids) {
        expect(id.startsWith(kDummyEdgePrefix), isFalse);
      }
    });

    test('custom attachmentInset overrides node-half-height', () {
      final g = Graph(
        nodes: [_n('a', h: 100), _n('b', h: 100)],
        edges: [_e('e1', 'a', 'b')],
      );
      final routes = _run(g, config: const EdgeRoutingConfig(attachmentInset: 5));
      final r = _routeFor(routes, 'e1');
      final coords = routes.input;
      // With inset=5, source attachment is at cy+5 (not cy+50).
      expect(r.points.first.dy, closeTo(coords.yByNode['a']! + 5, 1e-9));
      expect(r.points.last.dy, closeTo(coords.yByNode['b']! - 5, 1e-9));
    });

    test('edge from outside into cluster attaches at cluster boundary', () {
      // Graph: a (top-level) -> b (inside cluster C). The route src→dst should
      // get an extra waypoint where the segment crosses C's bbox.
      final g = Graph(
        nodes: [_n('a'), _n('b', clusterId: 'C')],
        edges: [_e('e1', 'a', 'b')],
        clusters: [
          const GraphCluster(id: 'C', memberIds: ['b']),
        ],
      );
      final routes = _run(g);
      final r = _routeFor(routes, 'e1');
      expect(r.points.length, 3);
      final coords = routes.input;
      final box = coords.clusterBoxes['C']!;
      // The middle waypoint must lie on cluster C's bbox edge.
      final mid = r.points[1];
      final onLeft = (mid.dx - box.left).abs() < 1e-6;
      final onRight = (mid.dx - box.right).abs() < 1e-6;
      final onTop = (mid.dy - box.top).abs() < 1e-6;
      final onBottom = (mid.dy - box.bottom).abs() < 1e-6;
      expect(onLeft || onRight || onTop || onBottom, isTrue,
          reason: 'mid waypoint $mid should sit on bbox $box edge');
      // First point: bottom of a; last point: top of b.
      expect(r.points.first.dy, closeTo(coords.yByNode['a']! + 10, 1e-9));
      expect(r.points.last.dy, closeTo(coords.yByNode['b']! - 10, 1e-9));
    });

    test('edge entirely within cluster is unchanged', () {
      // Both endpoints share innermost cluster — no boundary crossing.
      final g = Graph(
        nodes: [
          _n('a', clusterId: 'C'),
          _n('b', clusterId: 'C'),
        ],
        edges: [_e('e1', 'a', 'b')],
        clusters: [
          const GraphCluster(id: 'C', memberIds: ['a', 'b']),
        ],
      );
      final routes = _run(g);
      final r = _routeFor(routes, 'e1');
      expect(r.points.length, 2,
          reason: 'same-cluster edge should not get cluster waypoints');
      final coords = routes.input;
      expect(r.points.first.dy, closeTo(coords.yByNode['a']! + 10, 1e-9));
      expect(r.points.last.dy, closeTo(coords.yByNode['b']! - 10, 1e-9));
    });

    test('edge between two sibling clusters yields exit + entry waypoints', () {
      // a in cluster A, b in cluster B (no shared parent). Use a large
      // layerSpacing so the two cluster bboxes don't overlap vertically (the
      // simplification picks the outermost crossed cluster on each side, and
      // we want a clean exit-A → enter-B sequence).
      final g = Graph(
        nodes: [
          _n('a', clusterId: 'A'),
          _n('b', clusterId: 'B'),
        ],
        edges: [_e('e1', 'a', 'b')],
        clusters: [
          const GraphCluster(id: 'A', memberIds: ['a']),
          const GraphCluster(id: 'B', memberIds: ['b']),
        ],
      );
      final routes = _run(
        g,
        coordsConfig: const CoordinatesConfig(layerSpacing: 100),
      );
      final r = _routeFor(routes, 'e1');
      expect(r.points.length, 4,
          reason: 'sibling-cluster edge should have src + exitA + enterB + dst');
      final coords = routes.input;
      final boxA = coords.clusterBoxes['A']!;
      final boxB = coords.clusterBoxes['B']!;
      // points[1] should lie on A's bbox; points[2] on B's bbox.
      bool onRect(Rect r, Offset p) =>
          (p.dx - r.left).abs() < 1e-6 ||
          (p.dx - r.right).abs() < 1e-6 ||
          (p.dy - r.top).abs() < 1e-6 ||
          (p.dy - r.bottom).abs() < 1e-6;
      expect(onRect(boxA, r.points[1]), isTrue,
          reason: 'points[1] ${r.points[1]} should sit on A bbox $boxA');
      expect(onRect(boxB, r.points[2]), isTrue,
          reason: 'points[2] ${r.points[2]} should sit on B bbox $boxB');
    });

    test('no clusters defined: routing matches cluster-unaware behavior', () {
      // Sanity: when no clusters are defined, the cluster-aware code path
      // must not introduce any waypoints.
      final g = Graph(
        nodes: [_n('a'), _n('b')],
        edges: [_e('e1', 'a', 'b')],
      );
      final routes = _run(g);
      final r = _routeFor(routes, 'e1');
      expect(r.points.length, 2);
    });
  });
}
