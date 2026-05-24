import 'package:flutter/painting.dart';

class LayoutGraph {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;

  const LayoutGraph({
    required this.nodes,
    this.edges = const [],
  });
}

class LayoutNode {
  final String id;
  final Size size;

  const LayoutNode({
    required this.id,
    required this.size,
  });
}

class LayoutEdge {
  final String from;
  final String to;
  final bool directed;

  const LayoutEdge({
    required this.from,
    required this.to,
    this.directed = true,
  });
}
