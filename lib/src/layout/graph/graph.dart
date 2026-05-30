/// Core data structures for the Sugiyama graph layout framework.
///
/// These types describe an input directed graph (with optional cluster
/// membership) in a form that is independent of any particular PlantUML
/// diagram kind. Later phases of the framework transform a [Graph] into a
/// laid-out scene.
library;

/// Arrowhead style on the destination end of an edge.
enum EdgeHead {
  none,
  arrow,
  triangle,
  openTriangle,
  diamond,
  openDiamond,
}

/// A node in the layout graph.
///
/// Width and height are the node's intrinsic dimensions in logical pixels.
/// Optional [label] is informational; [clusterId] indicates membership in a
/// [GraphCluster] (composite / package / state container).
class GraphNode {
  final String id;
  final double width;
  final double height;
  final String? label;
  final String? clusterId;

  const GraphNode({
    required this.id,
    required this.width,
    required this.height,
    this.label,
    this.clusterId,
  });

  GraphNode copyWith({
    String? id,
    double? width,
    double? height,
    String? label,
    String? clusterId,
  }) {
    return GraphNode(
      id: id ?? this.id,
      width: width ?? this.width,
      height: height ?? this.height,
      label: label ?? this.label,
      clusterId: clusterId ?? this.clusterId,
    );
  }
}

/// A directed edge between two [GraphNode]s.
///
/// [isReversed] is set by cycle removal: the edge still semantically goes
/// from [src] to [dst], but layering treats it as if it went the other way
/// so the rest of the framework can operate on a DAG.
class GraphEdge {
  final String id;
  final String src;
  final String dst;
  final String? label;
  final bool isDashed;
  final EdgeHead head;
  final bool isReversed;

  const GraphEdge({
    required this.id,
    required this.src,
    required this.dst,
    this.label,
    this.isDashed = false,
    this.head = EdgeHead.arrow,
    this.isReversed = false,
  });

  GraphEdge copyWith({
    String? id,
    String? src,
    String? dst,
    String? label,
    bool? isDashed,
    EdgeHead? head,
    bool? isReversed,
  }) {
    return GraphEdge(
      id: id ?? this.id,
      src: src ?? this.src,
      dst: dst ?? this.dst,
      label: label ?? this.label,
      isDashed: isDashed ?? this.isDashed,
      head: head ?? this.head,
      isReversed: isReversed ?? this.isReversed,
    );
  }
}

/// A composite cluster that groups nodes (and possibly other clusters).
class GraphCluster {
  final String id;
  final String? label;
  final String? parentClusterId;
  final List<String> memberIds;

  const GraphCluster({
    required this.id,
    this.label,
    this.parentClusterId,
    this.memberIds = const [],
  });

  GraphCluster copyWith({
    String? id,
    String? label,
    String? parentClusterId,
    List<String>? memberIds,
  }) {
    return GraphCluster(
      id: id ?? this.id,
      label: label ?? this.label,
      parentClusterId: parentClusterId ?? this.parentClusterId,
      memberIds: memberIds ?? this.memberIds,
    );
  }
}

/// A directed graph + optional clustering, the input to the Sugiyama
/// framework.
class Graph {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<GraphCluster> clusters;

  late final Map<String, GraphNode> _nodeById = {
    for (final n in nodes) n.id: n,
  };

  late final Map<String, List<GraphEdge>> _edgesFrom = _buildFromIndex();
  late final Map<String, List<GraphEdge>> _edgesTo = _buildToIndex();

  Graph({
    required this.nodes,
    required this.edges,
    this.clusters = const [],
  });

  Map<String, List<GraphEdge>> _buildFromIndex() {
    final m = <String, List<GraphEdge>>{};
    for (final e in edges) {
      m.putIfAbsent(e.src, () => []).add(e);
    }
    return m;
  }

  Map<String, List<GraphEdge>> _buildToIndex() {
    final m = <String, List<GraphEdge>>{};
    for (final e in edges) {
      m.putIfAbsent(e.dst, () => []).add(e);
    }
    return m;
  }

  /// Lookup node by id.
  Map<String, GraphNode> get nodeById => _nodeById;

  /// All edges whose [GraphEdge.src] is [nodeId] (regardless of [isReversed]).
  List<GraphEdge> edgesFrom(String nodeId) =>
      List.unmodifiable(_edgesFrom[nodeId] ?? const []);

  /// All edges whose [GraphEdge.dst] is [nodeId] (regardless of [isReversed]).
  List<GraphEdge> edgesTo(String nodeId) =>
      List.unmodifiable(_edgesTo[nodeId] ?? const []);
}
