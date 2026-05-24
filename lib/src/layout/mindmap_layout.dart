import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class MindmapLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _nodePaddingX = 12.0;
  static const _nodePaddingY = 8.0;
  static const _minNodeWidth = 60.0;
  static const _minNodeHeight = 28.0;
  static const _horizontalGap = 60.0;
  static const _verticalGap = 12.0;
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

  const MindmapLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! MindmapDiagram) {
      throw ArgumentError('MindmapLayout expects MindmapDiagram');
    }
    final root = diagram.root;
    if (root == null) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    final rootMeasured = _measure(root, isRoot: true, measurer: measurer);
    final leftChildren = <MindmapNode>[];
    final rightChildren = <MindmapNode>[];
    var autoToggle = 0;
    for (final child in root.children) {
      final side = _resolveTopSide(child, autoToggle);
      if (side == MindmapSide.left) {
        leftChildren.add(child);
      } else {
        rightChildren.add(child);
      }
      if (child.side == MindmapSide.auto) {
        autoToggle++;
      }
    }

    final leftTree = leftChildren
        .map((c) => _buildSubtree(c, MindmapSide.left, measurer))
        .toList();
    final rightTree = rightChildren
        .map((c) => _buildSubtree(c, MindmapSide.right, measurer))
        .toList();

    final leftHeight = _totalHeight(leftTree);
    final rightHeight = _totalHeight(rightTree);
    final bodyHeight =
        math.max(math.max(leftHeight, rightHeight), rootMeasured.size.height);

    final rootY = _padding + (bodyHeight - rootMeasured.size.height) / 2;
    final leftBlockTop = _padding + (bodyHeight - leftHeight) / 2;
    final rightBlockTop = _padding + (bodyHeight - rightHeight) / 2;

    final leftWidth = _maxDepthWidth(leftTree);
    final rightWidth = _maxDepthWidth(rightTree);

    final rootX = _padding + leftWidth;
    final rootRect = Rect.fromLTWH(
      rootX,
      rootY,
      rootMeasured.size.width,
      rootMeasured.size.height,
    );

    final shapes = <SceneShape>[];

    _placeSide(
      rightTree,
      leftEdgeX: rootRect.right + _horizontalGap,
      topY: rightBlockTop,
      side: MindmapSide.right,
      shapes: shapes,
      parentAttachPoint:
          Offset(rootRect.right, rootRect.top + rootRect.height / 2),
    );
    _placeSide(
      leftTree,
      leftEdgeX: rootRect.left - _horizontalGap,
      topY: leftBlockTop,
      side: MindmapSide.left,
      shapes: shapes,
      parentAttachPoint:
          Offset(rootRect.left, rootRect.top + rootRect.height / 2),
    );

    shapes.add(SceneRoundedBox(
      rect: rootRect,
      label: root.text,
      textStyle: _rootStyle,
      fill: root.color ?? _rootFill,
      stroke: _stroke,
      cornerRadius: _rootCornerRadius,
    ));

    final totalWidth =
        rootRect.width + leftWidth + rightWidth + _padding * 2;
    final totalHeight = bodyHeight + _padding * 2;

    return Scene(
      size: Size(totalWidth, totalHeight),
      shapes: shapes,
      background: diagram.skin.backgroundColor,
    );
  }

  MindmapSide _resolveTopSide(MindmapNode child, int autoIndex) {
    if (child.side != MindmapSide.auto) return child.side;
    return autoIndex.isEven ? MindmapSide.right : MindmapSide.left;
  }

  _NodeMeasured _measure(
    MindmapNode node, {
    required bool isRoot,
    required TextMeasurer measurer,
  }) {
    final style = isRoot ? _rootStyle : _nodeStyle;
    final ts = measurer.measure(node.text, style);
    final w = math.max(_minNodeWidth, ts.width + _nodePaddingX * 2);
    final h = math.max(_minNodeHeight, ts.height + _nodePaddingY * 2);
    return _NodeMeasured(node: node, size: Size(w, h));
  }

  _Subtree _buildSubtree(
    MindmapNode node,
    MindmapSide side,
    TextMeasurer measurer,
  ) {
    final measured = _measure(node, isRoot: false, measurer: measurer);
    final children = <_Subtree>[];
    for (final c in node.children) {
      children.add(_buildSubtree(c, side, measurer));
    }
    final ownHeight = measured.size.height;
    final childrenHeight = children.isEmpty
        ? 0.0
        : children.map((c) => c.height).reduce((a, b) => a + b) +
            _verticalGap * (children.length - 1);
    final height = math.max(ownHeight, childrenHeight);
    final depthWidth = measured.size.width +
        (children.isEmpty
            ? 0.0
            : _horizontalGap +
                children
                    .map((c) => c.depthWidth)
                    .reduce((a, b) => math.max(a, b)));
    return _Subtree(
      measured: measured,
      children: children,
      side: side,
      height: height,
      depthWidth: depthWidth,
    );
  }

  double _totalHeight(List<_Subtree> trees) {
    if (trees.isEmpty) return 0;
    return trees.map((t) => t.height).reduce((a, b) => a + b) +
        _verticalGap * (trees.length - 1);
  }

  double _maxDepthWidth(List<_Subtree> trees) {
    if (trees.isEmpty) return 0;
    return trees
        .map((t) => t.depthWidth + _horizontalGap)
        .reduce((a, b) => math.max(a, b));
  }

  void _placeSide(
    List<_Subtree> trees, {
    required double leftEdgeX,
    required double topY,
    required MindmapSide side,
    required List<SceneShape> shapes,
    required Offset parentAttachPoint,
  }) {
    var y = topY;
    for (final t in trees) {
      _place(
        t,
        leftEdgeX: leftEdgeX,
        topY: y,
        side: side,
        shapes: shapes,
        parentAttachPoint: parentAttachPoint,
      );
      y += t.height + _verticalGap;
    }
  }

  void _place(
    _Subtree tree, {
    required double leftEdgeX,
    required double topY,
    required MindmapSide side,
    required List<SceneShape> shapes,
    required Offset parentAttachPoint,
  }) {
    final w = tree.measured.size.width;
    final h = tree.measured.size.height;
    final nodeTop = topY + (tree.height - h) / 2;
    final double nodeX;
    if (side == MindmapSide.right) {
      nodeX = leftEdgeX;
    } else {
      nodeX = leftEdgeX - w;
    }
    final rect = Rect.fromLTWH(nodeX, nodeTop, w, h);

    final attachStart = side == MindmapSide.right
        ? Offset(rect.left, rect.top + rect.height / 2)
        : Offset(rect.right, rect.top + rect.height / 2);
    shapes.add(SceneLine(
      from: parentAttachPoint,
      to: attachStart,
      head: null,
      stroke: _connector,
      strokeWidth: 1.2,
    ));

    shapes.add(SceneRoundedBox(
      rect: rect,
      label: tree.measured.node.text,
      textStyle: _nodeStyle,
      fill: tree.measured.node.color ?? _nodeFill,
      stroke: _stroke,
      cornerRadius: _nodeCornerRadius,
    ));

    if (tree.children.isEmpty) return;

    final childParentAttach = side == MindmapSide.right
        ? Offset(rect.right, rect.top + rect.height / 2)
        : Offset(rect.left, rect.top + rect.height / 2);
    final childrenBlockHeight = tree.children
            .map((c) => c.height)
            .reduce((a, b) => a + b) +
        _verticalGap * (tree.children.length - 1);
    final childrenTop = topY + (tree.height - childrenBlockHeight) / 2;
    final childLeftEdge = side == MindmapSide.right
        ? rect.right + _horizontalGap
        : rect.left - _horizontalGap;
    var y = childrenTop;
    for (final c in tree.children) {
      _place(
        c,
        leftEdgeX: childLeftEdge,
        topY: y,
        side: side,
        shapes: shapes,
        parentAttachPoint: childParentAttach,
      );
      y += c.height + _verticalGap;
    }
  }
}

class _NodeMeasured {
  final MindmapNode node;
  final Size size;
  const _NodeMeasured({required this.node, required this.size});
}

class _Subtree {
  final _NodeMeasured measured;
  final List<_Subtree> children;
  final MindmapSide side;
  final double height;
  final double depthWidth;

  const _Subtree({
    required this.measured,
    required this.children,
    required this.side,
    required this.height,
    required this.depthWidth,
  });
}
