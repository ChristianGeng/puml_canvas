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
  static const _stroke = Color(0xFF6B7280);
  static const _fill = Color(0xFFFFFFFF);
  static const _headerFill = Color(0xFFF3F4F6);

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
    final block = _buildBlock(diagram.root, measurer);
    final shapes = <SceneShape>[];
    _emit(block, _padding, _padding, shapes);
    final size = Size(
      block.size.width + _padding * 2,
      block.size.height + _padding * 2,
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

  _Block _buildBlock(DataNode node, TextMeasurer measurer) {
    switch (node) {
      case DataObject():
        return _buildObjectBlock(node, measurer);
      case DataArray():
        return _buildArrayBlock(node, measurer);
      case DataScalar():
        return _buildScalarBlock(node, measurer);
    }
  }

  _Block _buildObjectBlock(DataObject obj, TextMeasurer measurer) {
    if (obj.entries.isEmpty) {
      final ts = measurer.measure('{}', _keyStyle);
      final w = math.max(_minKeyWidth, ts.width + _cellPaddingX * 2);
      final h = math.max(_minRowHeight, ts.height + _cellPaddingY * 2);
      return _Block(
        size: Size(w, h),
        kind: _BlockKind.emptyObject,
      );
    }
    final rows = <_Row>[];
    var keyColWidth = 0.0;
    var valueColWidth = 0.0;
    var totalHeight = 0.0;
    for (final entry in obj.entries) {
      final keyTs = measurer.measure(entry.key, _keyStyle);
      final keyWidth =
          math.max(_minKeyWidth, keyTs.width + _cellPaddingX * 2);
      final valueBlock = _buildBlock(entry.value, measurer);
      final rowHeight = math.max(
        math.max(_minRowHeight, keyTs.height + _cellPaddingY * 2),
        valueBlock.size.height,
      );
      rows.add(_Row(
        key: entry.key,
        valueBlock: valueBlock,
        keyWidth: keyWidth,
        rowHeight: rowHeight,
      ));
      keyColWidth = math.max(keyColWidth, keyWidth);
      valueColWidth = math.max(valueColWidth, valueBlock.size.width);
      totalHeight += rowHeight;
    }
    final width = keyColWidth + valueColWidth;
    return _Block(
      size: Size(width, totalHeight),
      kind: _BlockKind.object,
      rows: rows,
      keyColWidth: keyColWidth,
      valueColWidth: valueColWidth,
    );
  }

  _Block _buildArrayBlock(DataArray arr, TextMeasurer measurer) {
    if (arr.items.isEmpty) {
      final ts = measurer.measure('[]', _keyStyle);
      final w = math.max(_minKeyWidth, ts.width + _cellPaddingX * 2);
      final h = math.max(_minRowHeight, ts.height + _cellPaddingY * 2);
      return _Block(
        size: Size(w, h),
        kind: _BlockKind.emptyArray,
      );
    }
    final rows = <_Row>[];
    var indexColWidth = 0.0;
    var valueColWidth = 0.0;
    var totalHeight = 0.0;
    for (var i = 0; i < arr.items.length; i++) {
      final label = '$i';
      final keyTs = measurer.measure(label, _indexStyle);
      final keyWidth =
          math.max(_minKeyWidth, keyTs.width + _cellPaddingX * 2);
      final valueBlock = _buildBlock(arr.items[i], measurer);
      final rowHeight = math.max(
        math.max(_minRowHeight, keyTs.height + _cellPaddingY * 2),
        valueBlock.size.height,
      );
      rows.add(_Row(
        key: label,
        valueBlock: valueBlock,
        keyWidth: keyWidth,
        rowHeight: rowHeight,
      ));
      indexColWidth = math.max(indexColWidth, keyWidth);
      valueColWidth = math.max(valueColWidth, valueBlock.size.width);
      totalHeight += rowHeight;
    }
    final width = indexColWidth + valueColWidth;
    return _Block(
      size: Size(width, totalHeight),
      kind: _BlockKind.array,
      rows: rows,
      keyColWidth: indexColWidth,
      valueColWidth: valueColWidth,
    );
  }

  _Block _buildScalarBlock(DataScalar scalar, TextMeasurer measurer) {
    final display = _scalarDisplay(scalar);
    final style = _scalarStyle(scalar.kind);
    final ts = measurer.measure(display, style);
    final w = math.max(_minValueWidth, ts.width + _cellPaddingX * 2);
    final h = math.max(_minRowHeight, ts.height + _cellPaddingY * 2);
    return _Block(
      size: Size(w, h),
      kind: _BlockKind.scalar,
      scalar: scalar,
      scalarDisplay: display,
    );
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

  void _emit(
    _Block block,
    double x,
    double y,
    List<SceneShape> shapes,
  ) {
    switch (block.kind) {
      case _BlockKind.object:
      case _BlockKind.array:
        _emitTable(block, x, y, shapes);
      case _BlockKind.scalar:
        shapes.add(SceneText(
          offset: Offset(x + _cellPaddingX, y + _cellPaddingY),
          text: block.scalarDisplay!,
          textStyle: _scalarStyle(block.scalar!.kind),
        ));
      case _BlockKind.emptyObject:
        shapes.add(SceneBox(
          rect: Rect.fromLTWH(x, y, block.size.width, block.size.height),
          textStyle: _keyStyle,
          fill: _fill,
          stroke: _stroke,
        ));
        shapes.add(SceneText(
          offset: Offset(x + _cellPaddingX, y + _cellPaddingY),
          text: '{}',
          textStyle: _keyStyle,
        ));
      case _BlockKind.emptyArray:
        shapes.add(SceneBox(
          rect: Rect.fromLTWH(x, y, block.size.width, block.size.height),
          textStyle: _keyStyle,
          fill: _fill,
          stroke: _stroke,
        ));
        shapes.add(SceneText(
          offset: Offset(x + _cellPaddingX, y + _cellPaddingY),
          text: '[]',
          textStyle: _keyStyle,
        ));
    }
  }

  void _emitTable(
    _Block block,
    double x,
    double y,
    List<SceneShape> shapes,
  ) {
    final outerRect =
        Rect.fromLTWH(x, y, block.size.width, block.size.height);
    shapes.add(SceneBox(
      rect: outerRect,
      textStyle: _keyStyle,
      fill: _fill,
      stroke: _stroke,
    ));
    final keyColWidth = block.keyColWidth!;
    var rowY = y;
    final isArray = block.kind == _BlockKind.array;
    for (var i = 0; i < block.rows!.length; i++) {
      final row = block.rows![i];
      if (i > 0) {
        shapes.add(SceneLine(
          from: Offset(x, rowY),
          to: Offset(x + block.size.width, rowY),
          head: null,
          stroke: _stroke,
        ));
      }
      shapes.add(SceneBox(
        rect: Rect.fromLTWH(x, rowY, keyColWidth, row.rowHeight),
        textStyle: _keyStyle,
        fill: _headerFill,
        stroke: _stroke,
        strokeWidth: 0,
      ));
      shapes.add(SceneLine(
        from: Offset(x + keyColWidth, rowY),
        to: Offset(x + keyColWidth, rowY + row.rowHeight),
        head: null,
        stroke: _stroke,
      ));
      final keyStyle = isArray ? _indexStyle : _keyStyle;
      final keyLabel = isArray ? '${row.key}:' : row.key;
      shapes.add(SceneText(
        offset: Offset(x + _cellPaddingX, rowY + _cellPaddingY),
        text: keyLabel,
        textStyle: keyStyle,
      ));
      _emit(
        row.valueBlock,
        x + keyColWidth,
        rowY,
        shapes,
      );
      rowY += row.rowHeight;
    }
  }
}

enum _BlockKind { object, array, scalar, emptyObject, emptyArray }

class _Block {
  final Size size;
  final _BlockKind kind;
  final List<_Row>? rows;
  final double? keyColWidth;
  final double? valueColWidth;
  final DataScalar? scalar;
  final String? scalarDisplay;

  const _Block({
    required this.size,
    required this.kind,
    this.rows,
    this.keyColWidth,
    this.valueColWidth,
    this.scalar,
    this.scalarDisplay,
  });
}

class _Row {
  final String key;
  final _Block valueBlock;
  final double keyWidth;
  final double rowHeight;

  const _Row({
    required this.key,
    required this.valueBlock,
    required this.keyWidth,
    required this.rowHeight,
  });
}
