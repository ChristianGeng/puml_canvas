import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class WbsLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _nodePaddingX = 12.0;
  static const _nodePaddingY = 8.0;
  static const _minNodeWidth = 60.0;
  static const _minNodeHeight = 28.0;
  static const _horizontalGap = 24.0;
  static const _verticalGap = 32.0;
  static const _rootCornerRadius = 16.0;
  static const _nodeCornerRadius = 10.0;

  static const _rootFill = Color(0xFFFEF3C7);
  static const _nodeFill = Color(0xFFFFFFFF);
  static const _stroke = Color(0xFF000000);
  static const _connector = Color(0xFF606060);

  static const _nodeStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
  );
  static const _rootStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  const WbsLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! WbsDiagram) {
      throw ArgumentError('WbsLayout expects WbsDiagram');
    }
    final root = diagram.root;
    if (root == null) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    final tree = _buildSubtree(root, isRoot: true, measurer: measurer);
    final shapes = <SceneShape>[];
    final totalWidth = tree.subtreeWidth + _padding * 2;
    _place(tree, leftX: _padding, topY: _padding, shapes: shapes);
    final totalHeight = _padding * 2 + _treeHeight(tree);

    return Scene(
      size: Size(totalWidth, totalHeight),
      shapes: shapes,
      background: diagram.skin.backgroundColor,
    );
  }

  _Subtree _buildSubtree(
    MindmapNode node, {
    required bool isRoot,
    required TextMeasurer measurer,
  }) {
    final style = isRoot ? _rootStyle : _nodeStyle;
    final ts = measurer.measure(node.text, style);
    final w = math.max(_minNodeWidth, ts.width + _nodePaddingX * 2);
    final h = math.max(_minNodeHeight, ts.height + _nodePaddingY * 2);
    final children = <_Subtree>[
      for (final c in node.children)
        _buildSubtree(c, isRoot: false, measurer: measurer),
    ];
    final childrenWidth = children.isEmpty
        ? 0.0
        : children.map((c) => c.subtreeWidth).reduce((a, b) => a + b) +
            _horizontalGap * (children.length - 1);
    final subtreeWidth = math.max(w, childrenWidth);
    return _Subtree(
      node: node,
      isRoot: isRoot,
      width: w,
      height: h,
      children: children,
      subtreeWidth: subtreeWidth,
    );
  }

  double _treeHeight(_Subtree tree) {
    if (tree.children.isEmpty) return tree.height;
    final childHeight =
        tree.children.map(_treeHeight).reduce((a, b) => math.max(a, b));
    return tree.height + _verticalGap + childHeight;
  }

  void _place(
    _Subtree tree, {
    required double leftX,
    required double topY,
    required List<SceneShape> shapes,
  }) {
    final centerX = leftX + tree.subtreeWidth / 2;
    final nodeX = centerX - tree.width / 2;
    final rect = Rect.fromLTWH(nodeX, topY, tree.width, tree.height);

    final style = tree.isRoot ? _rootStyle : _nodeStyle;
    final fill = tree.node.color ??
        (tree.isRoot ? _rootFill : _nodeFill);
    final radius = tree.isRoot ? _rootCornerRadius : _nodeCornerRadius;
    shapes.add(SceneRoundedBox(
      rect: rect,
      label: tree.node.text,
      textStyle: style,
      fill: fill,
      stroke: _stroke,
      cornerRadius: radius,
    ));

    if (tree.children.isEmpty) return;

    final parentBottom = Offset(rect.left + rect.width / 2, rect.bottom);
    final childTopY = topY + tree.height + _verticalGap;
    var x = leftX;
    for (final child in tree.children) {
      final childCenterX = x + child.subtreeWidth / 2;
      _place(child, leftX: x, topY: childTopY, shapes: shapes);
      final childTop = Offset(childCenterX, childTopY);
      _connect(shapes, parentBottom, childTop);
      x += child.subtreeWidth + _horizontalGap;
    }
  }

  void _connect(List<SceneShape> shapes, Offset from, Offset to) {
    if ((from.dx - to.dx).abs() < 0.5) {
      shapes.add(SceneLine(
        from: from,
        to: to,
        head: null,
        stroke: _connector,
        strokeWidth: 1.2,
      ));
      return;
    }
    final midY = (from.dy + to.dy) / 2;
    final p1 = Offset(from.dx, midY);
    final p2 = Offset(to.dx, midY);
    shapes.add(SceneLine(
      from: from,
      to: p1,
      head: null,
      stroke: _connector,
      strokeWidth: 1.2,
    ));
    shapes.add(SceneLine(
      from: p1,
      to: p2,
      head: null,
      stroke: _connector,
      strokeWidth: 1.2,
    ));
    shapes.add(SceneLine(
      from: p2,
      to: to,
      head: null,
      stroke: _connector,
      strokeWidth: 1.2,
    ));
  }
}

class _Subtree {
  final MindmapNode node;
  final bool isRoot;
  final double width;
  final double height;
  final List<_Subtree> children;
  final double subtreeWidth;

  const _Subtree({
    required this.node,
    required this.isRoot,
    required this.width,
    required this.height,
    required this.children,
    required this.subtreeWidth,
  });
}
