import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class ComponentLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _componentPaddingX = 16.0;
  static const _componentPaddingY = 10.0;
  static const _componentStereotypeGap = 2.0;
  static const _componentMinWidth = 110.0;
  static const _componentMinHeight = 50.0;
  static const _interfaceRadius = 8.0;
  static const _interfaceLabelGap = 4.0;
  static const _interfaceCellPad = 6.0;
  static const _itemGap = 18.0;
  static const _containerPaddingX = 16.0;
  static const _containerPaddingY = 14.0;
  static const _containerHeaderGap = 6.0;
  static const _containerGap = 22.0;
  static const _nodeShadingOffset = 6.0;
  static const _frameNotchHeight = 14.0;
  static const _frameNotchWidth = 56.0;
  static const _artifactPaddingX = 10.0;
  static const _artifactPaddingY = 6.0;
  static const _artifactMinWidth = 80.0;
  static const _artifactMinHeight = 40.0;
  static const _artifactFoldSize = 8.0;

  static const _componentStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  static const _stereotypeStyle = TextStyle(
    color: Color(0xFF555555),
    fontSize: 10,
    fontStyle: FontStyle.italic,
  );
  static const _interfaceStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
  );
  static const _containerStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _relationLabelStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 10,
  );

  static const _componentFill = Color(0xFFE3F2FD);
  static const _componentStroke = Color(0xFF000000);
  static const _interfaceFill = Color(0xFFFFFFFF);
  static const _interfaceStroke = Color(0xFF000000);
  static const _containerStroke = Color(0xFF606060);
  static const _containerFill = Color(0x00000000);
  static const _nodeFill = Color(0xFFF5F5F5);
  static const _artifactFill = Color(0xFFFFFFFF);
  static const _artifactStroke = Color(0xFF000000);

  static const _componentStereotype = '<<component>>';

  const ComponentLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! ComponentDiagram) {
      throw ArgumentError('ComponentLayout expects ComponentDiagram');
    }
    if (diagram.nodes.isEmpty && diagram.containers.isEmpty) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    final nodeByAlias = <String, ComponentNode>{
      for (final n in diagram.nodes) n.alias: n,
    };

    final containedAliases = <String>{};
    void collectContained(ComponentContainer c) {
      for (final a in c.nodeAliases) {
        containedAliases.add(a);
      }
      for (final n in c.nestedContainers) {
        collectContained(n);
      }
    }
    for (final c in diagram.containers) {
      collectContained(c);
    }

    final freeNodes = <ComponentNode>[];
    for (final n in diagram.nodes) {
      if (!containedAliases.contains(n.alias)) {
        freeNodes.add(n);
      }
    }

    final shapes = <SceneShape>[];
    final nodeRects = <String, Rect>{};

    var x = _padding;
    var y = _padding;
    var rowHeight = 0.0;
    var diagramRight = _padding;

    for (final container in diagram.containers) {
      final laid = _layoutContainer(container, nodeByAlias, measurer);
      _placeContainer(laid, Offset(x, y), shapes, nodeRects, measurer);
      final width = laid.size.width;
      final height = laid.size.height;
      x += width + _containerGap;
      if (height > rowHeight) rowHeight = height;
      if (x > diagramRight) diagramRight = x;
    }

    if (diagram.containers.isNotEmpty) {
      x = _padding;
      y += rowHeight + _containerGap;
      rowHeight = 0.0;
    }

    if (freeNodes.isNotEmpty) {
      for (final node in freeNodes) {
        final size = _measureNode(node, measurer);
        final rect = Rect.fromLTWH(x, y, size.width, size.height);
        nodeRects[node.alias] = rect;
        _emitNode(node, rect, shapes, measurer);
        x += size.width + _itemGap;
        if (size.height > rowHeight) rowHeight = size.height;
        if (x > diagramRight) diagramRight = x;
      }
      y += rowHeight;
    }

    for (final relation in diagram.relations) {
      final fromRect = nodeRects[relation.from];
      final toRect = nodeRects[relation.to];
      if (fromRect == null || toRect == null) continue;
      final fromNode = nodeByAlias[relation.from];
      final toNode = nodeByAlias[relation.to];
      final fromEdge = _edgeFor(fromRect, fromNode, toRect.center);
      final toEdge = _edgeFor(toRect, toNode, fromRect.center);
      shapes.add(SceneLine(
        from: fromEdge,
        to: toEdge,
        dashed: relation.lineStyle == LineStyle.dashed,
        head: relation.head,
        headAtFrom: false,
        label: relation.label,
        labelStyle: relation.label == null ? null : _relationLabelStyle,
        stroke: const Color(0xFF000000),
      ));
    }

    final width = math.max(diagramRight, _padding) + _padding;
    final height = y + _padding;
    return Scene(
      size: Size(width, height),
      shapes: shapes,
      background: diagram.skin.backgroundColor,
    );
  }

  Size _measureNode(ComponentNode node, TextMeasurer measurer) {
    if (node.kind == ComponentNodeKind.interface) {
      final label = measurer.measure(node.label, _interfaceStyle);
      final cellWidth = math.max(
        label.width + _interfaceCellPad * 2,
        _interfaceRadius * 2 + _interfaceCellPad,
      );
      final cellHeight =
          _interfaceRadius * 2 + _interfaceLabelGap + label.height;
      return Size(cellWidth, cellHeight);
    }
    if (node.kind == ComponentNodeKind.artifact) {
      final labelSize = measurer.measure(node.label, _componentStyle);
      final width = math.max(
        _artifactMinWidth,
        labelSize.width + _artifactPaddingX * 2,
      );
      final height = math.max(
        _artifactMinHeight,
        labelSize.height + _artifactPaddingY * 2,
      );
      return Size(width, height);
    }
    final labelSize = measurer.measure(node.label, _componentStyle);
    final stereotypeSize = measurer.measure(_componentStereotype, _stereotypeStyle);
    final width = math.max(
      _componentMinWidth,
      math.max(labelSize.width, stereotypeSize.width) +
          _componentPaddingX * 2,
    );
    final height = math.max(
      _componentMinHeight,
      _componentPaddingY * 2 +
          stereotypeSize.height +
          _componentStereotypeGap +
          labelSize.height,
    );
    return Size(width, height);
  }

  void _emitNode(
    ComponentNode node,
    Rect rect,
    List<SceneShape> shapes,
    TextMeasurer measurer,
  ) {
    if (node.kind == ComponentNodeKind.interface) {
      final cx = rect.center.dx;
      final circleCenter = Offset(cx, rect.top + _interfaceRadius);
      shapes.add(SceneCircle(
        center: circleCenter,
        radius: _interfaceRadius,
        fill: _interfaceFill,
        stroke: _interfaceStroke,
        ring: true,
      ));
      final labelSize = measurer.measure(node.label, _interfaceStyle);
      shapes.add(SceneText(
        offset: Offset(
          cx - labelSize.width / 2,
          rect.top + _interfaceRadius * 2 + _interfaceLabelGap,
        ),
        text: node.label,
        textStyle: _interfaceStyle,
      ));
      return;
    }
    if (node.kind == ComponentNodeKind.artifact) {
      shapes.add(SceneNote(
        rect: rect,
        text: node.label,
        textStyle: _componentStyle,
        fill: _artifactFill,
        stroke: _artifactStroke,
        foldSize: _artifactFoldSize,
      ));
      return;
    }
    shapes.add(SceneBox(
      rect: rect,
      fill: _componentFill,
      stroke: _componentStroke,
      textStyle: _componentStyle,
    ));
    final stereotypeSize = measurer.measure(_componentStereotype, _stereotypeStyle);
    final labelSize = measurer.measure(node.label, _componentStyle);
    final totalTextHeight = stereotypeSize.height +
        _componentStereotypeGap +
        labelSize.height;
    final ty = rect.center.dy - totalTextHeight / 2;
    shapes.add(SceneText(
      offset: Offset(
        rect.center.dx - stereotypeSize.width / 2,
        ty,
      ),
      text: _componentStereotype,
      textStyle: _stereotypeStyle,
    ));
    shapes.add(SceneText(
      offset: Offset(
        rect.center.dx - labelSize.width / 2,
        ty + stereotypeSize.height + _componentStereotypeGap,
      ),
      text: node.label,
      textStyle: _componentStyle,
    ));
  }

  _LaidContainer _layoutContainer(
    ComponentContainer container,
    Map<String, ComponentNode> nodeByAlias,
    TextMeasurer measurer,
  ) {
    final children = <_LaidItem>[];
    for (final alias in container.nodeAliases) {
      final node = nodeByAlias[alias];
      if (node == null) continue;
      final size = _measureNode(node, measurer);
      children.add(_LaidItem.node(node, size));
    }
    for (final nested in container.nestedContainers) {
      final laid = _layoutContainer(nested, nodeByAlias, measurer);
      children.add(_LaidItem.container(laid));
    }

    var labelSize = Size.zero;
    if (container.label != null) {
      labelSize = measurer.measure(container.label!, _containerStyle);
    }
    final headerHeight =
        container.label == null ? 0.0 : labelSize.height + _containerHeaderGap;

    final innerOrigin = Offset(
      _containerPaddingX,
      _containerPaddingY + headerHeight,
    );
    var innerWidth = 0.0;
    var innerHeight = 0.0;
    var cy = innerOrigin.dy;
    for (final child in children) {
      child.offset = Offset(innerOrigin.dx, cy);
      cy += child.size.height + _itemGap;
      if (child.size.width > innerWidth) innerWidth = child.size.width;
    }
    if (children.isNotEmpty) {
      innerHeight = cy - _itemGap - innerOrigin.dy;
    }
    innerWidth = math.max(innerWidth, labelSize.width);

    final width = innerWidth + _containerPaddingX * 2;
    final height = innerOrigin.dy + innerHeight + _containerPaddingY;
    return _LaidContainer(
      container: container,
      labelSize: labelSize,
      headerHeight: headerHeight,
      children: children,
      size: Size(width, height),
    );
  }

  void _placeContainer(
    _LaidContainer laid,
    Offset origin,
    List<SceneShape> shapes,
    Map<String, Rect> nodeRects,
    TextMeasurer measurer,
  ) {
    final rect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      laid.size.width,
      laid.size.height,
    );
    _emitContainerFrame(laid, rect, shapes);
    for (final child in laid.children) {
      final childOrigin = Offset(
        origin.dx + child.offset.dx,
        origin.dy + child.offset.dy,
      );
      if (child.isContainer) {
        _placeContainer(
          child.container!,
          childOrigin,
          shapes,
          nodeRects,
          measurer,
        );
      } else {
        final node = child.node!;
        final size = child.size;
        final nodeRect = Rect.fromLTWH(
          childOrigin.dx,
          childOrigin.dy,
          size.width,
          size.height,
        );
        nodeRects[node.alias] = nodeRect;
        _emitNode(node, nodeRect, shapes, measurer);
      }
    }
  }

  void _emitContainerFrame(
    _LaidContainer laid,
    Rect rect,
    List<SceneShape> shapes,
  ) {
    final kind = laid.container.kind;
    final label = laid.container.label;
    switch (kind) {
      case ContainerKind.package:
        shapes.add(SceneBox(
          rect: rect,
          fill: _containerFill,
          stroke: _containerStroke,
          textStyle: _containerStyle,
        ));
        if (label != null) {
          final tabRect = Rect.fromLTWH(
            rect.left,
            rect.top,
            laid.labelSize.width + _containerPaddingX * 2,
            laid.labelSize.height + _containerHeaderGap,
          );
          shapes.add(SceneBox(
            rect: tabRect,
            fill: const Color(0xFFEEEEEE),
            stroke: _containerStroke,
            textStyle: _containerStyle,
          ));
          shapes.add(SceneText(
            offset: Offset(
              tabRect.left + _containerPaddingX,
              tabRect.top + _containerHeaderGap / 2,
            ),
            text: label,
            textStyle: _containerStyle,
          ));
        }
      case ContainerKind.node:
        shapes.add(SceneBox(
          rect: rect,
          fill: _nodeFill,
          stroke: _containerStroke,
          textStyle: _containerStyle,
        ));
        shapes.add(SceneLine(
          from: Offset(rect.left, rect.top),
          to: Offset(rect.left + _nodeShadingOffset,
              rect.top - _nodeShadingOffset),
          head: null,
          stroke: _containerStroke,
        ));
        shapes.add(SceneLine(
          from: Offset(rect.right, rect.top),
          to: Offset(rect.right + _nodeShadingOffset,
              rect.top - _nodeShadingOffset),
          head: null,
          stroke: _containerStroke,
        ));
        shapes.add(SceneLine(
          from: Offset(rect.left + _nodeShadingOffset,
              rect.top - _nodeShadingOffset),
          to: Offset(rect.right + _nodeShadingOffset,
              rect.top - _nodeShadingOffset),
          head: null,
          stroke: _containerStroke,
        ));
        if (label != null) {
          shapes.add(SceneText(
            offset: Offset(
              rect.left + _containerPaddingX,
              rect.top + _containerHeaderGap / 2,
            ),
            text: label,
            textStyle: _containerStyle,
          ));
        }
      case ContainerKind.cloud:
        shapes.add(SceneRoundedBox(
          rect: rect,
          fill: _containerFill,
          stroke: _containerStroke,
          textStyle: _containerStyle,
          cornerRadius: 18.0,
        ));
        if (label != null) {
          shapes.add(SceneText(
            offset: Offset(
              rect.left + _containerPaddingX,
              rect.top + _containerHeaderGap / 2,
            ),
            text: label,
            textStyle: _containerStyle,
          ));
        }
      case ContainerKind.frame:
        shapes.add(SceneBox(
          rect: rect,
          fill: _containerFill,
          stroke: _containerStroke,
          textStyle: _containerStyle,
        ));
        if (label != null) {
          final tabWidth = math.max(
            _frameNotchWidth,
            laid.labelSize.width + _containerPaddingX * 2,
          );
          final notchRect = Rect.fromLTWH(
            rect.left,
            rect.top,
            tabWidth,
            _frameNotchHeight,
          );
          shapes.add(SceneBox(
            rect: notchRect,
            fill: const Color(0xFFE0E0E0),
            stroke: _containerStroke,
            textStyle: _containerStyle,
          ));
          shapes.add(SceneText(
            offset: Offset(
              notchRect.left + _containerPaddingX,
              notchRect.top + 1,
            ),
            text: label,
            textStyle: _containerStyle,
          ));
        }
    }
  }

  Offset _edgeFor(Rect rect, ComponentNode? node, Offset toward) {
    if (node != null && node.kind == ComponentNodeKind.interface) {
      final center = Offset(
        rect.center.dx,
        rect.top + _interfaceRadius,
      );
      final dx = toward.dx - center.dx;
      final dy = toward.dy - center.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) return center;
      return Offset(
        center.dx + dx / len * _interfaceRadius,
        center.dy + dy / len * _interfaceRadius,
      );
    }
    return _rectEdge(rect, toward);
  }

  Offset _rectEdge(Rect rect, Offset toward) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final dx = toward.dx - cx;
    final dy = toward.dy - cy;
    if (dx == 0 && dy == 0) return rect.center;
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final tx = dx == 0 ? double.infinity : halfW / dx.abs();
    final ty = dy == 0 ? double.infinity : halfH / dy.abs();
    final t = math.min(tx, ty);
    return Offset(cx + dx * t, cy + dy * t);
  }
}

class _LaidContainer {
  final ComponentContainer container;
  final Size labelSize;
  final double headerHeight;
  final List<_LaidItem> children;
  final Size size;

  const _LaidContainer({
    required this.container,
    required this.labelSize,
    required this.headerHeight,
    required this.children,
    required this.size,
  });
}

class _LaidItem {
  final ComponentNode? node;
  final _LaidContainer? container;
  final Size size;
  Offset offset = Offset.zero;

  _LaidItem.node(ComponentNode this.node, this.size) : container = null;
  _LaidItem.container(_LaidContainer this.container)
      : node = null,
        size = container.size;

  bool get isContainer => container != null;
}

