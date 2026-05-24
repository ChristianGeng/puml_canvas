import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class NetworkLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _segmentGap = 56.0;
  static const _busHeight = 22.0;
  static const _busToNodeGap = 36.0;
  static const _nodeWidth = 110.0;
  static const _nodeHeight = 44.0;
  static const _nodeGap = 28.0;
  static const _labelGap = 8.0;
  static const _minBusWidth = 320.0;

  static const _busFill = Color(0xFFCFE9FF);
  static const _busStroke = Color(0xFF1D4ED8);
  static const _nodeFill = Color(0xFFFFFFFF);
  static const _nodeStroke = Color(0xFF000000);
  static const _connectorColor = Color(0xFF374151);

  static const _busLabelStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _busAddressStyle = TextStyle(
    color: Color(0xFF6B7280),
    fontSize: 11,
  );
  static const _nodeNameStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _nodeAddressStyle = TextStyle(
    color: Color(0xFF374151),
    fontSize: 10,
  );

  const NetworkLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! NetworkDiagram) {
      throw ArgumentError('NetworkLayout expects NetworkDiagram');
    }
    if (diagram.networks.isEmpty) {
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

    var labelColumnWidth = 0.0;
    for (final seg in diagram.networks) {
      final nameSize = measurer.measure(seg.name, _busLabelStyle);
      labelColumnWidth = math.max(labelColumnWidth, nameSize.width);
      if (seg.address != null) {
        final addrSize = measurer.measure(seg.address!, _busAddressStyle);
        labelColumnWidth = math.max(labelColumnWidth, addrSize.width);
      }
    }
    labelColumnWidth = math.max(60.0, labelColumnWidth);

    final shapes = <SceneShape>[];
    final segmentLeft = _padding + labelColumnWidth + _labelGap;
    var maxBusWidth = _minBusWidth;
    for (final seg in diagram.networks) {
      final n = seg.nodes.length;
      final neededWidth = n == 0
          ? _minBusWidth
          : (n * _nodeWidth) + ((n - 1) * _nodeGap) + 2 * _nodeGap;
      maxBusWidth = math.max(maxBusWidth, neededWidth);
    }

    var y = _padding.toDouble();
    for (final seg in diagram.networks) {
      final busTop = y;
      final busRect =
          Rect.fromLTWH(segmentLeft, busTop, maxBusWidth, _busHeight);
      shapes.add(SceneBox(
        rect: busRect,
        textStyle: _busLabelStyle,
        fill: _busFill,
        stroke: _busStroke,
      ));

      final nameSize = measurer.measure(seg.name, _busLabelStyle);
      shapes.add(SceneText(
        offset: Offset(
          _padding + (labelColumnWidth - nameSize.width),
          busTop + (_busHeight - nameSize.height) / 2,
        ),
        text: seg.name,
        textStyle: _busLabelStyle,
      ));
      if (seg.address != null) {
        final addrSize = measurer.measure(seg.address!, _busAddressStyle);
        shapes.add(SceneText(
          offset: Offset(
            _padding + (labelColumnWidth - addrSize.width),
            busTop + _busHeight + 2,
          ),
          text: seg.address!,
          textStyle: _busAddressStyle,
        ));
      }

      final nodeTop = busTop + _busHeight + _busToNodeGap;
      final n = seg.nodes.length;
      if (n > 0) {
        final totalNodesWidth =
            (n * _nodeWidth) + ((n - 1) * _nodeGap);
        final startX = segmentLeft + (maxBusWidth - totalNodesWidth) / 2;
        for (var idx = 0; idx < n; idx++) {
          final node = seg.nodes[idx];
          final nodeLeft = startX + idx * (_nodeWidth + _nodeGap);
          final nodeRect = Rect.fromLTWH(
            nodeLeft,
            nodeTop,
            _nodeWidth,
            _nodeHeight,
          );
          final nodeCenterX = nodeLeft + _nodeWidth / 2;
          shapes.add(SceneLine(
            from: Offset(nodeCenterX, busTop + _busHeight),
            to: Offset(nodeCenterX, nodeTop),
            head: null,
            stroke: _connectorColor,
          ));
          shapes.add(SceneBox(
            rect: nodeRect,
            textStyle: _nodeNameStyle,
            fill: _nodeFill,
            stroke: _nodeStroke,
          ));
          final nameSize = measurer.measure(node.name, _nodeNameStyle);
          final addressSize = node.address != null
              ? measurer.measure(node.address!, _nodeAddressStyle)
              : Size.zero;
          final hasAddress = node.address != null;
          final totalTextHeight = hasAddress
              ? nameSize.height + 2 + addressSize.height
              : nameSize.height;
          final nameY =
              nodeTop + (_nodeHeight - totalTextHeight) / 2;
          shapes.add(SceneText(
            offset: Offset(
              nodeCenterX - nameSize.width / 2,
              nameY,
            ),
            text: node.name,
            textStyle: _nodeNameStyle,
          ));
          if (hasAddress) {
            shapes.add(SceneText(
              offset: Offset(
                nodeCenterX - addressSize.width / 2,
                nameY + nameSize.height + 2,
              ),
              text: node.address!,
              textStyle: _nodeAddressStyle,
            ));
          }
        }
      }

      y = nodeTop + _nodeHeight + _segmentGap;
    }

    final totalWidth = segmentLeft + maxBusWidth + _padding;
    final totalHeight = (y - _segmentGap) + _padding;
    return wrapWithDecorations(
      Scene(
        size: Size(totalWidth, totalHeight),
        shapes: List.unmodifiable(shapes),
        background: diagram.decorations.skin.backgroundColor,
      ),
      diagram.decorations,
      measurer,
    );
  }
}
