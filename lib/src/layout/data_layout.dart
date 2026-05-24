import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class DataLayout implements DiagramLayout {
  static const _padding = 16.0;
  static const _cellPaddingX = 8.0;
  static const _cellPaddingY = 4.0;
  static const _minRowHeight = 22.0;
  static const _minKeyWidth = 40.0;
  static const _minValueWidth = 60.0;
  static const _columnGap = 40.0;
  static const _siblingGap = 16.0;
  static const _dotRadius = 3.0;
  static const _stroke = Color(0xFF6B7280);
  static const _fill = Color(0xFFFFFFFF);
  static const _headerFill = Color(0xFFF3F4F6);
  static const _connectorColor = Color(0xFF000000);
  static const _dotColor = Color(0xFF000000);

  static const _keyStyle = TextStyle(
    color: Color(0xFF1F2937),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _stringValueStyle = TextStyle(
    color: Color(0xFF15803D),
    fontSize: 12,
  );
  static const _numberValueStyle = TextStyle(
    color: Color(0xFF1D4ED8),
    fontSize: 12,
  );
  static const _boolValueStyle = TextStyle(
    color: Color(0xFF7E22CE),
    fontSize: 12,
  );
  static const _nullValueStyle = TextStyle(
    color: Color(0xFF6B7280),
    fontSize: 12,
    fontStyle: FontStyle.italic,
  );
  static const _indexStyle = TextStyle(
    color: Color(0xFF6B7280),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  const DataLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! DataDiagram) {
      throw ArgumentError('DataLayout expects DataDiagram');
    }
    final shapes = <SceneShape>[];
    final root = diagram.root;
    if (root is DataScalar) {
      final block = _measureScalar(root, measurer);
      shapes.add(SceneBox(
        rect: Rect.fromLTWH(_padding, _padding, block.width, block.height),
        textStyle: _keyStyle,
        fill: _fill,
        stroke: _stroke,
      ));
      shapes.add(SceneText(
        offset: Offset(_padding + _cellPaddingX, _padding + _cellPaddingY),
        text: block.display,
        textStyle: _scalarStyle(root.kind),
      ));
      final size = Size(
        block.width + _padding * 2,
        block.height + _padding * 2,
      );
      return wrapWithDecorations(
        Scene(
          size: size,
          shapes: shapes,
          background: diagram.decorations.skin.backgroundColor,
        ),
        diagram.decorations,
        measurer,
      );
    }

    final tables = <_Table>[];
    _collectTables(root, 0, null, -1, measurer, tables);
    if (tables.isEmpty) {
      return wrapWithDecorations(
        Scene(
          size: Size.zero,
          shapes: shapes,
          background: diagram.decorations.skin.backgroundColor,
        ),
        diagram.decorations,
        measurer,
      );
    }
    _assignPositions(tables);

    var maxRight = 0.0;
    var maxBottom = 0.0;
    for (final t in tables) {
      maxRight = math.max(maxRight, t.x + t.width);
      maxBottom = math.max(maxBottom, t.y + t.height);
    }

    for (final t in tables) {
      _emitTable(t, shapes);
    }
    for (final t in tables) {
      if (t.parent != null) {
        final parent = t.parent!;
        final row = parent.rows[t.parentRowIndex];
        final dotX = parent.x + parent.width - _cellPaddingX;
        final dotY = parent.y + row.y + row.height / 2;
        final targetX = t.x;
        final targetY = t.y + t.rows.first.height / 2;
        shapes.add(SceneLine(
          from: Offset(dotX, dotY),
          to: Offset(targetX, targetY),
          dashed: true,
          head: null,
          stroke: _connectorColor,
        ));
      }
    }

    final size = Size(
      maxRight + _padding,
      maxBottom + _padding,
    );
    return wrapWithDecorations(
      Scene(
        size: size,
        shapes: shapes,
        background: diagram.decorations.skin.backgroundColor,
      ),
      diagram.decorations,
      measurer,
    );
  }

  void _collectTables(
    DataNode node,
    int depth,
    _Table? parent,
    int parentRowIndex,
    TextMeasurer measurer,
    List<_Table> out,
  ) {
    if (node is! DataObject && node is! DataArray) return;
    final table = _buildTable(node, depth, parent, parentRowIndex, measurer);
    out.add(table);
    final tableIndex = out.length - 1;
    for (var i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final childNode = row.childNode;
      if (childNode != null) {
        final childIdxStart = out.length;
        _collectTables(childNode, depth + 1, table, i, measurer, out);
        if (out.length > childIdxStart) {
          out[tableIndex].children.add(out[childIdxStart]);
        }
      }
    }
  }

  _Table _buildTable(
    DataNode node,
    int depth,
    _Table? parent,
    int parentRowIndex,
    TextMeasurer measurer,
  ) {
    final isArray = node is DataArray;
    final entries = <_TableEntry>[];
    if (node is DataObject) {
      for (final e in node.entries) {
        entries.add(_TableEntry(label: e.key, value: e.value));
      }
    } else if (node is DataArray) {
      for (var i = 0; i < node.items.length; i++) {
        entries.add(_TableEntry(label: '$i:', value: node.items[i]));
      }
    }

    if (entries.isEmpty) {
      final placeholder = isArray ? '[]' : '{}';
      final ts = measurer.measure(placeholder, _keyStyle);
      final w = math.max(_minKeyWidth + _minValueWidth,
          ts.width + _cellPaddingX * 2);
      final h = math.max(_minRowHeight, ts.height + _cellPaddingY * 2);
      final row = _TableRow(
        keyText: placeholder,
        keyStyle: _keyStyle,
        valueText: null,
        valueStyle: null,
        childNode: null,
        height: h,
        y: 0,
      );
      return _Table(
        node: node,
        depth: depth,
        parent: parent,
        parentRowIndex: parentRowIndex,
        rows: [row],
        keyColWidth: w / 2,
        valueColWidth: w / 2,
        width: w,
        height: h,
      );
    }

    var keyColWidth = _minKeyWidth;
    var valueColWidth = _minValueWidth;
    final rows = <_TableRow>[];
    final keyStyle = isArray ? _indexStyle : _keyStyle;
    for (final entry in entries) {
      final keyTs = measurer.measure(entry.label, keyStyle);
      final keyW = keyTs.width + _cellPaddingX * 2;
      keyColWidth = math.max(keyColWidth, keyW);
      final value = entry.value;
      String? valueText;
      TextStyle? valueStyle;
      DataNode? childNode;
      double rowH = math.max(_minRowHeight, keyTs.height + _cellPaddingY * 2);
      if (value is DataScalar) {
        valueText = _scalarDisplay(value);
        valueStyle = _scalarStyle(value.kind);
        final vts = measurer.measure(valueText, valueStyle);
        valueColWidth =
            math.max(valueColWidth, vts.width + _cellPaddingX * 2);
        rowH = math.max(rowH, vts.height + _cellPaddingY * 2);
      } else if (value is DataObject || value is DataArray) {
        childNode = value;
        valueColWidth = math.max(valueColWidth, _minValueWidth);
      }
      rows.add(_TableRow(
        keyText: entry.label,
        keyStyle: keyStyle,
        valueText: valueText,
        valueStyle: valueStyle,
        childNode: childNode,
        height: rowH,
        y: 0,
      ));
    }
    var totalH = 0.0;
    for (final r in rows) {
      r.y = totalH;
      totalH += r.height;
    }
    final width = keyColWidth + valueColWidth;
    return _Table(
      node: node,
      depth: depth,
      parent: parent,
      parentRowIndex: parentRowIndex,
      rows: rows,
      keyColWidth: keyColWidth,
      valueColWidth: valueColWidth,
      width: width,
      height: totalH,
    );
  }

  void _assignPositions(List<_Table> tables) {
    final byDepth = <int, List<_Table>>{};
    for (final t in tables) {
      byDepth.putIfAbsent(t.depth, () => []).add(t);
    }
    final maxDepth =
        byDepth.keys.fold<int>(0, (a, b) => math.max(a, b));
    final colX = <int, double>{};
    var x = _padding;
    for (var d = 0; d <= maxDepth; d++) {
      final list = byDepth[d] ?? const <_Table>[];
      var w = 0.0;
      for (final t in list) {
        w = math.max(w, t.width);
      }
      colX[d] = x;
      x += w + _columnGap;
    }
    for (final t in tables) {
      t.x = colX[t.depth]!;
    }

    final roots = tables.where((t) => t.parent == null).toList();
    var cursorY = _padding;
    for (final root in roots) {
      final used = _placeSubtree(root, cursorY);
      cursorY = used + _siblingGap;
    }

    var minY = double.infinity;
    for (final t in tables) {
      if (t.y < minY) minY = t.y;
    }
    if (minY < _padding) {
      final delta = _padding - minY;
      for (final t in tables) {
        t.y += delta;
      }
    }
  }

  double _placeSubtree(_Table table, double topY) {
    if (table.children.isEmpty) {
      table.y = topY;
      return topY + table.height;
    }
    var childCursorY = topY;
    final firstStart = childCursorY;
    double lastEnd = childCursorY;
    for (var i = 0; i < table.children.length; i++) {
      final child = table.children[i];
      final end = _placeSubtree(child, childCursorY);
      lastEnd = end;
      childCursorY = end + _siblingGap;
    }
    final childrenCenter = (firstStart + lastEnd) / 2;
    table.y = childrenCenter - table.height / 2;
    if (table.y < topY) {
      final delta = topY - table.y;
      _shiftSubtree(table, delta);
    }
    return math.max(table.y + table.height, lastEnd);
  }

  void _shiftSubtree(_Table table, double delta) {
    table.y += delta;
    for (final c in table.children) {
      _shiftSubtree(c, delta);
    }
  }

  void _emitTable(_Table table, List<SceneShape> shapes) {
    final x = table.x;
    final y = table.y;
    final outer = Rect.fromLTWH(x, y, table.width, table.height);
    shapes.add(SceneBox(
      rect: outer,
      textStyle: _keyStyle,
      fill: _fill,
      stroke: _stroke,
    ));
    for (var i = 0; i < table.rows.length; i++) {
      final row = table.rows[i];
      final rowY = y + row.y;
      if (i > 0) {
        shapes.add(SceneLine(
          from: Offset(x, rowY),
          to: Offset(x + table.width, rowY),
          head: null,
          stroke: _stroke,
        ));
      }
      shapes.add(SceneBox(
        rect: Rect.fromLTWH(x, rowY, table.keyColWidth, row.height),
        textStyle: _keyStyle,
        fill: _headerFill,
        stroke: _stroke,
        strokeWidth: 0,
      ));
      shapes.add(SceneLine(
        from: Offset(x + table.keyColWidth, rowY),
        to: Offset(x + table.keyColWidth, rowY + row.height),
        head: null,
        stroke: _stroke,
      ));
      shapes.add(SceneText(
        offset: Offset(x + _cellPaddingX, rowY + _cellPaddingY),
        text: row.keyText,
        textStyle: row.keyStyle,
      ));
      if (row.valueText != null) {
        shapes.add(SceneText(
          offset: Offset(x + table.keyColWidth + _cellPaddingX,
              rowY + _cellPaddingY),
          text: row.valueText!,
          textStyle: row.valueStyle!,
        ));
      } else if (row.childNode != null) {
        shapes.add(SceneCircle(
          center: Offset(
            x + table.width - _cellPaddingX,
            rowY + row.height / 2,
          ),
          radius: _dotRadius,
          fill: _dotColor,
          stroke: _dotColor,
        ));
      }
    }
  }

  _ScalarBlock _measureScalar(DataScalar scalar, TextMeasurer measurer) {
    final display = _scalarDisplay(scalar);
    final ts = measurer.measure(display, _scalarStyle(scalar.kind));
    final w = math.max(_minValueWidth, ts.width + _cellPaddingX * 2);
    final h = math.max(_minRowHeight, ts.height + _cellPaddingY * 2);
    return _ScalarBlock(width: w, height: h, display: display);
  }

  String _scalarDisplay(DataScalar s) {
    switch (s.kind) {
      case ScalarKind.string:
        return '"${s.value}"';
      case ScalarKind.null_:
        return 'null';
      case ScalarKind.boolean:
      case ScalarKind.number:
        return s.value;
    }
  }

  TextStyle _scalarStyle(ScalarKind kind) {
    switch (kind) {
      case ScalarKind.string:
        return _stringValueStyle;
      case ScalarKind.number:
        return _numberValueStyle;
      case ScalarKind.boolean:
        return _boolValueStyle;
      case ScalarKind.null_:
        return _nullValueStyle;
    }
  }
}

class _TableEntry {
  final String label;
  final DataNode value;
  const _TableEntry({required this.label, required this.value});
}

class _TableRow {
  final String keyText;
  final TextStyle keyStyle;
  final String? valueText;
  final TextStyle? valueStyle;
  final DataNode? childNode;
  final double height;
  double y;

  _TableRow({
    required this.keyText,
    required this.keyStyle,
    required this.valueText,
    required this.valueStyle,
    required this.childNode,
    required this.height,
    required this.y,
  });
}

class _Table {
  final DataNode node;
  final int depth;
  final _Table? parent;
  final int parentRowIndex;
  final List<_TableRow> rows;
  final double keyColWidth;
  final double valueColWidth;
  final double width;
  final double height;
  final List<_Table> children = [];
  double x = 0;
  double y = 0;

  _Table({
    required this.node,
    required this.depth,
    required this.parent,
    required this.parentRowIndex,
    required this.rows,
    required this.keyColWidth,
    required this.valueColWidth,
    required this.width,
    required this.height,
  });
}

class _ScalarBlock {
  final double width;
  final double height;
  final String display;
  const _ScalarBlock({
    required this.width,
    required this.height,
    required this.display,
  });
}
