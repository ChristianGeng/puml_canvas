/// Entry point for the Sugiyama hierarchical graph layout framework.
///
/// Phase 1 wires up cycle removal and layer assignment. Phase 2 adds dummy
/// node insertion (long-edge subdivision) and crossing reduction
/// (barycenter heuristic). Future phases (coordinate assignment, edge
/// routing) will extend [SugiyamaResult] with positions, routes, and cluster
/// bounds.
library;

import 'coordinates.dart';
import 'crossing_reduction.dart';
import 'cycle_removal.dart';
import 'dummy_nodes.dart';
import 'edge_routing.dart';
import 'graph.dart';
import 'layering.dart';

/// The output of running the Sugiyama framework on a [Graph].
class SugiyamaResult {
  // From Phase 1.
  final Graph dag;
  final Layering layering;

  // From Phase 2.
  final ProperLayering properLayering;
  final OrderedLayering orderedLayering;

  // From Phase 3.
  final Coordinates coordinates;

  // From Phase 4.
  final EdgeRoutes edgeRoutes;

  const SugiyamaResult({
    required this.dag,
    required this.layering,
    required this.properLayering,
    required this.orderedLayering,
    required this.coordinates,
    required this.edgeRoutes,
  });
}

/// Run the (currently Phase 1 + Phase 2 + Phase 3 + Phase 4) Sugiyama pipeline.
///
/// [sameRank] is an optional set of node-id pairs constrained to share a layer
/// (PlantUML horizontal transitions). Empty (default) leaves the pipeline
/// byte-identical to the unconstrained engine.
SugiyamaResult runSugiyama(
  Graph input, {
  CoordinatesConfig coordinatesConfig = const CoordinatesConfig(),
  EdgeRoutingConfig edgeRoutingConfig = const EdgeRoutingConfig(),
  Set<(String, String)> sameRank = const {},
}) {
  final dag = removeCycles(input);
  final layering = assignLayers(dag, sameRank: sameRank);
  final proper = insertDummyNodes(dag, layering);
  final ordered = reduceCrossings(proper);
  final coords = assignCoordinates(ordered, config: coordinatesConfig);
  final routes = routeEdges(
    coords,
    originalDag: dag,
    config: edgeRoutingConfig,
  );
  return SugiyamaResult(
    dag: dag,
    layering: layering,
    properLayering: proper,
    orderedLayering: ordered,
    coordinates: coords,
    edgeRoutes: routes,
  );
}
