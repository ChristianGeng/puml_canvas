import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'graph.dart';

enum LayoutDirection {
  topToBottom,
  leftToRight,
}

class LayeredLayoutOptions {
  final LayoutDirection direction;
  final double padding;
  final double layerGap;
  final double nodeGap;
  final int orderingPasses;

  const LayeredLayoutOptions({
    this.direction = LayoutDirection.topToBottom,
    this.padding = 24.0,
    this.layerGap = 60.0,
    this.nodeGap = 60.0,
    this.orderingPasses = 4,
  });
}

class LayeredLayoutResult {
  final Map<String, Rect> nodeRects;
  final List<List<String>> layers;
  final Size size;

  const LayeredLayoutResult({
    required this.nodeRects,
    required this.layers,
    required this.size,
  });
}

class LayeredGraphLayout {
  final LayeredLayoutOptions options;

  const LayeredGraphLayout({
    this.options = const LayeredLayoutOptions(),
  });

  LayeredLayoutResult layout(LayoutGraph graph) {
    if (graph.nodes.isEmpty) {
      return const LayeredLayoutResult(
        nodeRects: {},
        layers: [],
        size: Size.zero,
      );
    }

    final nodes = <String, LayoutNode>{
      for (final node in graph.nodes) node.id: node,
    };
    final ids = graph.nodes.map((node) => node.id).toList();
    final ranks = _assignRanks(ids, graph.edges, nodes);
    final layers = _buildLayers(ids, ranks);
    _orderLayers(layers, graph.edges);
    final rects = _positionLayers(layers, nodes);

    var width = 0.0;
    var height = 0.0;
    for (final rect in rects.values) {
      width = math.max(width, rect.right);
      height = math.max(height, rect.bottom);
    }

    return LayeredLayoutResult(
      nodeRects: Map.unmodifiable(rects),
      layers: List<List<String>>.unmodifiable(
        layers.map((layer) => List<String>.unmodifiable(layer)),
      ),
      size: Size(width + options.padding, height + options.padding),
    );
  }

  Map<String, int> _assignRanks(
    List<String> ids,
    List<LayoutEdge> edges,
    Map<String, LayoutNode> nodes,
  ) {
    final neighbors = <String, List<String>>{
      for (final id in ids) id: <String>[],
    };
    final incoming = <String, int>{
      for (final id in ids) id: 0,
    };

    for (final edge in edges) {
      if (!nodes.containsKey(edge.from) || !nodes.containsKey(edge.to)) {
        continue;
      }
      neighbors[edge.from]!.add(edge.to);
      neighbors[edge.to]!.add(edge.from);
      if (edge.directed && edge.from != edge.to) {
        incoming[edge.to] = incoming[edge.to]! + 1;
      }
    }

    final rank = <String, int>{};
    final queue = <String>[];
    for (final id in ids) {
      if (incoming[id] == 0) {
        rank[id] = 0;
        queue.add(id);
      }
    }
    if (queue.isEmpty) {
      rank[ids.first] = 0;
      queue.add(ids.first);
    }

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final currentRank = rank[current]!;
      for (final next in neighbors[current]!) {
        if (rank.containsKey(next)) continue;
        rank[next] = currentRank + 1;
        queue.add(next);
      }
    }

    for (final id in ids) {
      rank.putIfAbsent(id, () => 0);
    }
    return rank;
  }

  List<List<String>> _buildLayers(List<String> ids, Map<String, int> ranks) {
    final byRank = <int, List<String>>{};
    for (final id in ids) {
      byRank.putIfAbsent(ranks[id]!, () => <String>[]).add(id);
    }
    final rankKeys = byRank.keys.toList()..sort();
    return [for (final rank in rankKeys) byRank[rank]!];
  }

  void _orderLayers(List<List<String>> layers, List<LayoutEdge> edges) {
    if (layers.length < 2) return;
    final layerOf = <String, int>{};
    for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      for (final id in layers[layerIndex]) {
        layerOf[id] = layerIndex;
      }
    }

    for (var pass = 0; pass < options.orderingPasses; pass++) {
      for (var i = 1; i < layers.length; i++) {
        _sortLayerByBarycenter(layers, edges, layerOf, i, i - 1);
      }
      for (var i = layers.length - 2; i >= 0; i--) {
        _sortLayerByBarycenter(layers, edges, layerOf, i, i + 1);
      }
    }
  }

  void _sortLayerByBarycenter(
    List<List<String>> layers,
    List<LayoutEdge> edges,
    Map<String, int> layerOf,
    int layerIndex,
    int neighborLayerIndex,
  ) {
    final target = layers[layerIndex];
    final neighbor = layers[neighborLayerIndex];
    final neighborPos = <String, int>{
      for (var i = 0; i < neighbor.length; i++) neighbor[i]: i,
    };
    final originalPos = <String, int>{
      for (var i = 0; i < target.length; i++) target[i]: i,
    };

    double barycenter(String id) {
      var sum = 0.0;
      var count = 0;
      for (final edge in edges) {
        String? other;
        if (edge.from == id) {
          other = edge.to;
        } else if (edge.to == id) {
          other = edge.from;
        }
        if (other == null || layerOf[other] != neighborLayerIndex) {
          continue;
        }
        sum += neighborPos[other]!;
        count++;
      }
      if (count == 0) return originalPos[id]!.toDouble();
      return sum / count;
    }

    target.sort((a, b) {
      final cmp = barycenter(a).compareTo(barycenter(b));
      if (cmp != 0) return cmp;
      return originalPos[a]!.compareTo(originalPos[b]!);
    });
  }

  Map<String, Rect> _positionLayers(
    List<List<String>> layers,
    Map<String, LayoutNode> nodes,
  ) {
    return switch (options.direction) {
      LayoutDirection.topToBottom => _positionTopToBottom(layers, nodes),
      LayoutDirection.leftToRight => _positionLeftToRight(layers, nodes),
    };
  }

  Map<String, Rect> _positionTopToBottom(
    List<List<String>> layers,
    Map<String, LayoutNode> nodes,
  ) {
    final rects = <String, Rect>{};
    final layerWidths = <double>[];
    final layerHeights = <double>[];
    var maxLayerWidth = 0.0;

    for (final layer in layers) {
      var width = 0.0;
      var height = 0.0;
      for (final id in layer) {
        final size = nodes[id]!.size;
        width += size.width;
        height = math.max(height, size.height);
      }
      if (layer.length > 1) {
        width += (layer.length - 1) * options.nodeGap;
      }
      layerWidths.add(width);
      layerHeights.add(height);
      maxLayerWidth = math.max(maxLayerWidth, width);
    }

    var y = options.padding;
    for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      var x = options.padding + (maxLayerWidth - layerWidths[layerIndex]) / 2;
      for (final id in layers[layerIndex]) {
        final size = nodes[id]!.size;
        rects[id] = Rect.fromLTWH(x, y, size.width, size.height);
        x += size.width + options.nodeGap;
      }
      y += layerHeights[layerIndex] + options.layerGap;
    }
    return rects;
  }

  Map<String, Rect> _positionLeftToRight(
    List<List<String>> layers,
    Map<String, LayoutNode> nodes,
  ) {
    final rects = <String, Rect>{};
    final layerWidths = <double>[];
    final layerHeights = <double>[];
    var maxLayerHeight = 0.0;

    for (final layer in layers) {
      var width = 0.0;
      var height = 0.0;
      for (final id in layer) {
        final size = nodes[id]!.size;
        width = math.max(width, size.width);
        height += size.height;
      }
      if (layer.length > 1) {
        height += (layer.length - 1) * options.nodeGap;
      }
      layerWidths.add(width);
      layerHeights.add(height);
      maxLayerHeight = math.max(maxLayerHeight, height);
    }

    var x = options.padding;
    for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      var y = options.padding + (maxLayerHeight - layerHeights[layerIndex]) / 2;
      for (final id in layers[layerIndex]) {
        final size = nodes[id]!.size;
        rects[id] = Rect.fromLTWH(x, y, size.width, size.height);
        y += size.height + options.nodeGap;
      }
      x += layerWidths[layerIndex] + options.layerGap;
    }
    return rects;
  }
}
