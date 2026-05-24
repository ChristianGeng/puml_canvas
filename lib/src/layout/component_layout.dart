import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
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
  static const _databaseCapHeight = 6.0;
  static const _queueCapWidth = 8.0;

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
  static const _storageStereotype = '<<storage>>';

  const ComponentLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! ComponentDiagram) {
      throw ArgumentError('ComponentLayout expects ComponentDiagram');
    }
    if (diagram.nodes.isEmpty && diagram.containers.isEmpty) {
      return wrapWithDecorations(
        Scene(
          size: Size.zero,
          shapes: const [],
          background: diagram.decorations.skin.backgroundColor,
        ),
        diagram.decorations,
        measurer,
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
    final containerRects = <String, Rect>{};

    final items = <_TopItem>[];
    for (final container in diagram.containers) {
      final laid = _layoutContainer(
        container,
        nodeByAlias,
        measurer,
        leftToRight: diagram.leftToRightDirection,
      );
      final owned = <String>{};
      _collectContainerAliases(container, owned);
      items.add(_TopItem(
        laid: laid,
        size: laid.size,
        owned: owned,
      ));
    }
    for (final node in freeNodes) {
      final size = _measureNode(node, measurer);
      items.add(_TopItem(
        freeNode: node,
        size: size,
        owned: {node.alias},
      ));
    }

    final aliasToItem = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      for (final a in items[i].owned) {
        aliasToItem[a] = i;
      }
    }

    final layout = _bfsLayered(
      items,
      diagram.relations,
      aliasToItem,
      leftToRight: diagram.leftToRightDirection,
    );

    var diagramRight = _padding;
    var diagramBottom = _padding;
    for (var i = 0; i < items.length; i++) {
      final pos = layout[i];
      final item = items[i];
      if (item.laid != null) {
        _placeContainer(
            item.laid!, pos, shapes, nodeRects, containerRects, measurer);
      } else {
        final node = item.freeNode!;
        final rect =
            Rect.fromLTWH(pos.dx, pos.dy, item.size.width, item.size.height);
        nodeRects[node.alias] = rect;
        _emitNode(node, rect, shapes, measurer);
      }
      final right = pos.dx + item.size.width;
      final bottom = pos.dy + item.size.height;
      if (right > diagramRight) diagramRight = right;
      if (bottom > diagramBottom) diagramBottom = bottom;
    }
    final y = diagramBottom;

    Rect? rectFor(String alias) =>
        nodeRects[alias] ?? containerRects[alias];

    final allNodeRects = nodeRects.values.toList(growable: false);

    for (final relation in diagram.relations) {
      final fromRect = rectFor(relation.from);
      final toRect = rectFor(relation.to);
      if (fromRect == null || toRect == null) continue;
      final fromNode = nodeByAlias[relation.from];
      final toNode = nodeByAlias[relation.to];
      _emitRelation(
        relation,
        fromRect,
        toRect,
        fromNode,
        toNode,
        allNodeRects,
        shapes,
      );
    }

    final width = math.max(diagramRight, _padding) + _padding;
    final height = y + _padding;
    return wrapWithDecorations(
      Scene(
        size: Size(width, height),
        shapes: shapes,
        background: diagram.decorations.skin.backgroundColor,
      ),
      diagram.decorations,
      measurer,
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
    if (node.kind == ComponentNodeKind.database) {
      final labelSize = measurer.measure(node.label, _componentStyle);
      final width = math.max(
        _componentMinWidth,
        labelSize.width + _componentPaddingX * 2,
      );
      final height = math.max(
        _componentMinHeight,
        labelSize.height + _componentPaddingY * 2 + _databaseCapHeight * 2,
      );
      return Size(width, height);
    }
    if (node.kind == ComponentNodeKind.queue) {
      final labelSize = measurer.measure(node.label, _componentStyle);
      final width = math.max(
        _componentMinWidth,
        labelSize.width + _componentPaddingX * 2 + _queueCapWidth * 2,
      );
      final height = math.max(
        _componentMinHeight,
        labelSize.height + _componentPaddingY * 2,
      );
      return Size(width, height);
    }
    if (node.kind == ComponentNodeKind.storage) {
      final labelSize = measurer.measure(node.label, _componentStyle);
      final stereotypeSize =
          measurer.measure(_storageStereotype, _stereotypeStyle);
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
    if (node.kind == ComponentNodeKind.database) {
      shapes.add(SceneSymbol(
        rect: rect,
        label: node.label,
        labelStyle: _componentStyle,
        kind: ParticipantKind.database,
        fill: _componentFill,
        stroke: _componentStroke,
      ));
      return;
    }
    if (node.kind == ComponentNodeKind.queue) {
      shapes.add(SceneSymbol(
        rect: rect,
        label: node.label,
        labelStyle: _componentStyle,
        kind: ParticipantKind.queue,
        fill: _componentFill,
        stroke: _componentStroke,
      ));
      return;
    }
    final stereotypeText = node.kind == ComponentNodeKind.storage
        ? _storageStereotype
        : _componentStereotype;
    shapes.add(SceneBox(
      rect: rect,
      fill: _componentFill,
      stroke: _componentStroke,
      textStyle: _componentStyle,
    ));
    final stereotypeSize = measurer.measure(stereotypeText, _stereotypeStyle);
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
      text: stereotypeText,
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
    TextMeasurer measurer, {
    bool leftToRight = false,
  }) {
    final children = <_LaidItem>[];
    for (final alias in container.nodeAliases) {
      final node = nodeByAlias[alias];
      if (node == null) continue;
      final size = _measureNode(node, measurer);
      children.add(_LaidItem.node(node, size));
    }
    for (final nested in container.nestedContainers) {
      final laid = _layoutContainer(
        nested,
        nodeByAlias,
        measurer,
        leftToRight: leftToRight,
      );
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
    final allContainers =
        children.isNotEmpty && children.every((c) => c.isContainer);
    final horizontal = allContainers ? !leftToRight : leftToRight;
    final positions = _linearArrange(
      children.map((c) => c.size).toList(),
      gap: _itemGap,
      horizontal: horizontal,
    );
    var innerWidth = 0.0;
    var innerHeight = 0.0;
    for (var i = 0; i < children.length; i++) {
      final pos = positions[i];
      children[i].offset = Offset(innerOrigin.dx + pos.dx, innerOrigin.dy + pos.dy);
      final right = pos.dx + children[i].size.width;
      final bottom = pos.dy + children[i].size.height;
      if (right > innerWidth) innerWidth = right;
      if (bottom > innerHeight) innerHeight = bottom;
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
    Map<String, Rect> containerRects,
    TextMeasurer measurer,
  ) {
    final rect = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      laid.size.width,
      laid.size.height,
    );
    _emitContainerFrame(laid, rect, shapes);
    final alias = laid.container.alias;
    if (alias != null) {
      containerRects[alias] = rect;
    }
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
          containerRects,
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

  void _emitRelation(
    ComponentRelation relation,
    Rect fromRect,
    Rect toRect,
    ComponentNode? fromNode,
    ComponentNode? toNode,
    List<Rect> allNodeRects,
    List<SceneShape> shapes,
  ) {
    final dashed = relation.lineStyle == LineStyle.dashed;
    final stroke = const Color(0xFF000000);
    final fromCenter = fromRect.center;
    final toCenter = toRect.center;
    final dx = (toCenter.dx - fromCenter.dx).abs();
    final dy = (toCenter.dy - fromCenter.dy).abs();
    final vertical = dy >= dx;

    Offset start;
    Offset end;
    Offset midA;
    Offset midB;
    if (vertical) {
      final midY = (fromCenter.dy + toCenter.dy) / 2;
      start = _edgeFor(
          fromRect, fromNode, Offset(fromCenter.dx, toCenter.dy));
      end =
          _edgeFor(toRect, toNode, Offset(toCenter.dx, fromCenter.dy));
      midA = Offset(start.dx, midY);
      midB = Offset(end.dx, midY);
      if (_pathHitsAnyOther(
          start, midA, midB, end, fromRect, toRect, allNodeRects)) {
        final detourX = math.max(fromRect.right, toRect.right) + 16.0;
        start = Offset(fromRect.right, fromCenter.dy);
        end = Offset(toRect.right, toCenter.dy);
        midA = Offset(detourX, start.dy);
        midB = Offset(detourX, end.dy);
      }
    } else {
      final midX = (fromCenter.dx + toCenter.dx) / 2;
      start = _edgeFor(
          fromRect, fromNode, Offset(toCenter.dx, fromCenter.dy));
      end =
          _edgeFor(toRect, toNode, Offset(fromCenter.dx, toCenter.dy));
      midA = Offset(midX, start.dy);
      midB = Offset(midX, end.dy);
      if (_pathHitsAnyOther(
          start, midA, midB, end, fromRect, toRect, allNodeRects)) {
        final detourY = math.max(fromRect.bottom, toRect.bottom) + 16.0;
        start = Offset(fromCenter.dx, fromRect.bottom);
        end = Offset(toCenter.dx, toRect.bottom);
        midA = Offset(start.dx, detourY);
        midB = Offset(end.dx, detourY);
      }
    }

    shapes.add(SceneLine(
      from: start,
      to: midA,
      dashed: dashed,
      head: null,
      stroke: stroke,
    ));
    shapes.add(SceneLine(
      from: midA,
      to: midB,
      dashed: dashed,
      head: null,
      stroke: stroke,
    ));
    shapes.add(SceneLine(
      from: midB,
      to: end,
      dashed: dashed,
      head: relation.head,
      headAtFrom: false,
      stroke: stroke,
      label: relation.label,
      labelStyle: relation.label == null ? null : _relationLabelStyle,
    ));
  }

  bool _pathHitsAnyOther(
    Offset s,
    Offset a,
    Offset b,
    Offset e,
    Rect from,
    Rect to,
    List<Rect> rects,
  ) {
    return _segmentHitsAnyOther(s, a, from, to, rects) ||
        _segmentHitsAnyOther(a, b, from, to, rects) ||
        _segmentHitsAnyOther(b, e, from, to, rects);
  }

  bool _segmentHitsAnyOther(
    Offset a,
    Offset b,
    Rect from,
    Rect to,
    List<Rect> rects,
  ) {
    final minX = math.min(a.dx, b.dx);
    final maxX = math.max(a.dx, b.dx);
    final minY = math.min(a.dy, b.dy);
    final maxY = math.max(a.dy, b.dy);
    for (final r in rects) {
      if (r == from || r == to) continue;
      final inflated = r.deflate(0.5);
      if (inflated.right < minX || inflated.left > maxX) continue;
      if (inflated.bottom < minY || inflated.top > maxY) continue;
      return true;
    }
    return false;
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
      case ContainerKind.database:
      case ContainerKind.queue:
      case ContainerKind.storage:
        shapes.add(SceneBox(
          rect: rect,
          fill: _containerFill,
          stroke: _containerStroke,
          textStyle: _containerStyle,
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

  void _collectContainerAliases(ComponentContainer c, Set<String> into) {
    if (c.alias != null) into.add(c.alias!);
    for (final a in c.nodeAliases) {
      into.add(a);
    }
    for (final n in c.nestedContainers) {
      _collectContainerAliases(n, into);
    }
  }

  List<Offset> _bfsLayered(
    List<_TopItem> items,
    List<ComponentRelation> relations,
    Map<String, int> aliasToItem, {
    required bool leftToRight,
  }) {
    final positions = _bfsArrange(
      items.map((i) => i.size).toList(),
      items.map((i) => i.owned).toList(),
      relations,
      gap: _containerGap,
      leftToRight: leftToRight,
    );
    return [for (final p in positions) Offset(p.dx + _padding, p.dy + _padding)];
  }

  List<Offset> _linearArrange(
    List<Size> sizes, {
    required double gap,
    required bool horizontal,
  }) {
    final positions = <Offset>[];
    if (horizontal) {
      var rowHeight = 0.0;
      for (final s in sizes) {
        if (s.height > rowHeight) rowHeight = s.height;
      }
      var x = 0.0;
      for (final s in sizes) {
        final cy = (rowHeight - s.height) / 2;
        positions.add(Offset(x, cy));
        x += s.width + gap;
      }
    } else {
      var colWidth = 0.0;
      for (final s in sizes) {
        if (s.width > colWidth) colWidth = s.width;
      }
      var y = 0.0;
      for (final s in sizes) {
        final cx = (colWidth - s.width) / 2;
        positions.add(Offset(cx, y));
        y += s.height + gap;
      }
    }
    return positions;
  }

  List<Offset> _bfsArrange(
    List<Size> sizes,
    List<Set<String>> owned,
    List<ComponentRelation> relations, {
    required double gap,
    required bool leftToRight,
  }) {
    final n = sizes.length;
    if (n == 0) return const <Offset>[];

    final aliasToItem = <String, int>{};
    for (var i = 0; i < n; i++) {
      for (final a in owned[i]) {
        aliasToItem[a] = i;
      }
    }

    final outEdges = List.generate(n, (_) => <int>{});
    final inDegree = List<int>.filled(n, 0);
    for (final r in relations) {
      final fi = aliasToItem[r.from];
      final ti = aliasToItem[r.to];
      if (fi == null || ti == null || fi == ti) continue;
      if (outEdges[fi].add(ti)) {
        inDegree[ti]++;
      }
    }

    final level = List<int>.filled(n, -1);
    final queue = <int>[];
    for (var i = 0; i < n; i++) {
      if (inDegree[i] == 0) {
        level[i] = 0;
        queue.add(i);
      }
    }
    if (queue.isEmpty) {
      level[0] = 0;
      queue.add(0);
    }
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final v in outEdges[cur]) {
        final candidate = level[cur] + 1;
        if (candidate > level[v]) {
          level[v] = candidate;
          queue.add(v);
        }
      }
    }
    for (var i = 0; i < n; i++) {
      if (level[i] < 0) level[i] = 0;
    }

    final byLevel = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      byLevel.putIfAbsent(level[i], () => <int>[]).add(i);
    }
    final levels = byLevel.keys.toList()..sort();

    final positions = List<Offset>.filled(n, Offset.zero);
    if (leftToRight) {
      var x = 0.0;
      for (final lv in levels) {
        final col = byLevel[lv]!;
        var colWidth = 0.0;
        for (final i in col) {
          if (sizes[i].width > colWidth) colWidth = sizes[i].width;
        }
        var y = 0.0;
        for (final i in col) {
          final cx = x + (colWidth - sizes[i].width) / 2;
          positions[i] = Offset(cx, y);
          y += sizes[i].height + gap;
        }
        x += colWidth + gap;
      }
    } else {
      var y = 0.0;
      for (final lv in levels) {
        final row = byLevel[lv]!;
        var rowHeight = 0.0;
        for (final i in row) {
          if (sizes[i].height > rowHeight) rowHeight = sizes[i].height;
        }
        var x = 0.0;
        for (final i in row) {
          final cy = y + (rowHeight - sizes[i].height) / 2;
          positions[i] = Offset(x, cy);
          x += sizes[i].width + gap;
        }
        y += rowHeight + gap;
      }
    }
    return positions;
  }
}

class _TopItem {
  final _LaidContainer? laid;
  final ComponentNode? freeNode;
  final Size size;
  final Set<String> owned;

  const _TopItem({
    this.laid,
    this.freeNode,
    required this.size,
    required this.owned,
  });
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

