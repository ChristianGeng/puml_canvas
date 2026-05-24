import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class SaltLayout implements DiagramLayout {
  static const _outerPadding = 12.0;
  static const _cellPaddingX = 8.0;
  static const _cellPaddingY = 6.0;
  static const _columnGap = 6.0;
  static const _rowGap = 4.0;
  static const _minCellHeight = 22.0;
  static const _minCellWidth = 40.0;
  static const _radioRadius = 6.0;
  static const _checkboxSize = 12.0;
  static const _markerGap = 6.0;
  static const _buttonRadius = 4.0;
  static const _dividerStroke = 1.0;

  static const _outerFill = Color(0xFFFFFFFF);
  static const _outerStroke = Color(0xFF000000);
  static const _buttonFill = Color(0xFFE5E7EB);
  static const _buttonStroke = Color(0xFF374151);
  static const _fieldFill = Color(0xFFFFFFFF);
  static const _fieldStroke = Color(0xFF6B7280);
  static const _markerStroke = Color(0xFF000000);
  static const _markerFill = Color(0xFF000000);
  static const _dividerStrokeColor = Color(0xFF6B7280);

  static const _labelStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
  );
  static const _buttonStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
  static const _fieldStyle = TextStyle(
    color: Color(0xFF374151),
    fontSize: 12,
    fontStyle: FontStyle.italic,
  );

  const SaltLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! SaltDiagram) {
      throw ArgumentError('SaltLayout expects SaltDiagram');
    }
    if (diagram.rows.isEmpty) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    var columnCount = 0;
    for (final row in diagram.rows) {
      if (!row.isDivider) {
        columnCount = math.max(columnCount, row.cells.length);
      }
    }
    if (columnCount == 0) columnCount = 1;

    final cellSizes = <List<Size>>[];
    final rowHeights = <double>[];
    final colWidths = List<double>.filled(columnCount, _minCellWidth);

    for (final row in diagram.rows) {
      if (row.isDivider) {
        cellSizes.add(const []);
        rowHeights.add(_minCellHeight / 2);
        continue;
      }
      final sizes = <Size>[];
      var rowH = _minCellHeight;
      for (var c = 0; c < row.cells.length; c++) {
        final size = _measureCell(row.cells[c], measurer);
        sizes.add(size);
        if (size.width > colWidths[c]) colWidths[c] = size.width;
        if (size.height > rowH) rowH = size.height;
      }
      cellSizes.add(sizes);
      rowHeights.add(rowH);
    }

    var contentWidth = 0.0;
    for (var c = 0; c < columnCount; c++) {
      contentWidth += colWidths[c];
      if (c < columnCount - 1) contentWidth += _columnGap;
    }
    var contentHeight = 0.0;
    for (var r = 0; r < diagram.rows.length; r++) {
      contentHeight += rowHeights[r];
      if (r < diagram.rows.length - 1) contentHeight += _rowGap;
    }

    final innerLeft = _outerPadding;
    final innerTop = _outerPadding;
    final innerWidth = contentWidth;
    final innerHeight = contentHeight;
    final totalWidth = innerWidth + _outerPadding * 2;
    final totalHeight = innerHeight + _outerPadding * 2;

    final shapes = <SceneShape>[];
    shapes.add(SceneBox(
      rect: Rect.fromLTWH(0, 0, totalWidth, totalHeight),
      textStyle: _labelStyle,
      fill: _outerFill,
      stroke: _outerStroke,
    ));

    var y = innerTop;
    for (var r = 0; r < diagram.rows.length; r++) {
      final row = diagram.rows[r];
      final h = rowHeights[r];
      if (row.isDivider) {
        final midY = y + h / 2;
        shapes.add(SceneLine(
          from: Offset(innerLeft, midY),
          to: Offset(innerLeft + innerWidth, midY),
          head: null,
          stroke: _dividerStrokeColor,
          strokeWidth: _dividerStroke,
        ));
      } else {
        var x = innerLeft;
        for (var c = 0; c < row.cells.length; c++) {
          final cellW = colWidths[c];
          _emitCell(
            row.cells[c],
            Rect.fromLTWH(x, y, cellW, h),
            shapes,
          );
          x += cellW + _columnGap;
        }
      }
      y += h;
      if (r < diagram.rows.length - 1) y += _rowGap;
    }

    return Scene(
      size: Size(totalWidth, totalHeight),
      shapes: List.unmodifiable(shapes),
      background: diagram.skin.backgroundColor,
    );
  }

  Size _measureCell(SaltCell cell, TextMeasurer measurer) {
    switch (cell) {
      case SaltLabel(text: final t):
        final ts = measurer.measure(t, _labelStyle);
        return Size(
          math.max(_minCellWidth, ts.width + _cellPaddingX * 2),
          math.max(_minCellHeight, ts.height + _cellPaddingY * 2),
        );
      case SaltButton(label: final t):
        final ts = measurer.measure(t, _buttonStyle);
        return Size(
          math.max(_minCellWidth, ts.width + _cellPaddingX * 2),
          math.max(_minCellHeight, ts.height + _cellPaddingY * 2),
        );
      case SaltTextField(value: final v):
        final ts = measurer.measure(v, _fieldStyle);
        return Size(
          math.max(_minCellWidth, ts.width + _cellPaddingX * 2),
          math.max(_minCellHeight, ts.height + _cellPaddingY * 2),
        );
      case SaltRadio(label: final t):
        final ts = measurer.measure(t, _labelStyle);
        final w = _radioRadius * 2 + _markerGap + ts.width + _cellPaddingX * 2;
        final h = math.max(
          _minCellHeight,
          math.max(_radioRadius * 2, ts.height) + _cellPaddingY * 2,
        );
        return Size(math.max(_minCellWidth, w), h);
      case SaltCheckbox(label: final t):
        final ts = measurer.measure(t, _labelStyle);
        final w = _checkboxSize + _markerGap + ts.width + _cellPaddingX * 2;
        final h = math.max(
          _minCellHeight,
          math.max(_checkboxSize, ts.height) + _cellPaddingY * 2,
        );
        return Size(math.max(_minCellWidth, w), h);
    }
  }

  void _emitCell(SaltCell cell, Rect rect, List<SceneShape> shapes) {
    switch (cell) {
      case SaltLabel(text: final t):
        shapes.add(SceneText(
          offset: Offset(rect.left + _cellPaddingX, rect.top + _cellPaddingY),
          text: t,
          textStyle: _labelStyle,
        ));
      case SaltButton(label: final t):
        shapes.add(SceneRoundedBox(
          rect: rect,
          label: t,
          textStyle: _buttonStyle,
          fill: _buttonFill,
          stroke: _buttonStroke,
          cornerRadius: _buttonRadius,
        ));
      case SaltTextField(value: final v):
        shapes.add(SceneRoundedBox(
          rect: rect,
          textStyle: _fieldStyle,
          fill: _fieldFill,
          stroke: _fieldStroke,
          cornerRadius: _buttonRadius,
        ));
        shapes.add(SceneText(
          offset: Offset(rect.left + _cellPaddingX, rect.top + _cellPaddingY),
          text: v,
          textStyle: _fieldStyle,
        ));
      case SaltRadio(selected: final sel, label: final t):
        final cx = rect.left + _cellPaddingX + _radioRadius;
        final cy = rect.top + rect.height / 2;
        shapes.add(SceneCircle(
          center: Offset(cx, cy),
          radius: _radioRadius,
          fill: sel ? _markerFill : _outerFill,
          stroke: _markerStroke,
          ring: !sel,
        ));
        shapes.add(SceneText(
          offset: Offset(
            cx + _radioRadius + _markerGap,
            rect.top + _cellPaddingY,
          ),
          text: t,
          textStyle: _labelStyle,
        ));
      case SaltCheckbox(checked: final chk, label: final t):
        final bx = rect.left + _cellPaddingX;
        final by = rect.top + (rect.height - _checkboxSize) / 2;
        final boxRect = Rect.fromLTWH(bx, by, _checkboxSize, _checkboxSize);
        shapes.add(SceneBox(
          rect: boxRect,
          textStyle: _labelStyle,
          fill: _outerFill,
          stroke: _markerStroke,
        ));
        if (chk) {
          shapes.add(SceneLine(
            from: Offset(bx + 2, by + _checkboxSize / 2),
            to: Offset(bx + _checkboxSize / 2 - 1, by + _checkboxSize - 2),
            head: null,
            stroke: _markerStroke,
            strokeWidth: 1.5,
          ));
          shapes.add(SceneLine(
            from: Offset(bx + _checkboxSize / 2 - 1, by + _checkboxSize - 2),
            to: Offset(bx + _checkboxSize - 1, by + 2),
            head: null,
            stroke: _markerStroke,
            strokeWidth: 1.5,
          ));
        }
        shapes.add(SceneText(
          offset: Offset(
            bx + _checkboxSize + _markerGap,
            rect.top + _cellPaddingY,
          ),
          text: t,
          textStyle: _labelStyle,
        ));
    }
  }
}
