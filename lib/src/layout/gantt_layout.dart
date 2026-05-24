import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class GanttLayout implements DiagramLayout {
  static const _padding = 16.0;
  static const _nameColumnPaddingX = 12.0;
  static const _minNameColumnWidth = 80.0;
  static const _rowHeight = 28.0;
  static const _rowGap = 6.0;
  static const _axisHeight = 24.0;
  static const _axisGap = 8.0;
  static const _barHeight = 18.0;
  static const _barPaddingY = 5.0;
  static const _pxPerDay = 14.0;
  static const _minPlotWidth = 200.0;
  static const _milestoneSize = 14.0;
  static const _sectionStrokeWidth = 1.0;

  static const _axisColor = Color(0xFF6B7280);
  static const _axisTickColor = Color(0xFF9CA3AF);
  static const _barFill = Color(0xFF60A5FA);
  static const _barStroke = Color(0xFF1D4ED8);
  static const _milestoneFill = Color(0xFFFBBF24);
  static const _milestoneStroke = Color(0xFF92400E);
  static const _sectionColor = Color(0xFF374151);

  static const _nameStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
  );
  static const _axisStyle = TextStyle(
    color: Color(0xFF374151),
    fontSize: 11,
  );
  static const _sectionStyle = TextStyle(
    color: Color(0xFF111827),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  const GanttLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! GanttDiagram) {
      throw ArgumentError('GanttLayout expects GanttDiagram');
    }
    if (diagram.items.isEmpty) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    var minDate = diagram.projectStart;
    var maxDate = diagram.projectStart;
    for (final item in diagram.items) {
      switch (item) {
        case GanttTask():
          final end = item.start.add(item.duration);
          if (item.start.isBefore(minDate)) minDate = item.start;
          if (end.isAfter(maxDate)) maxDate = end;
        case GanttMilestone():
          if (item.date.isBefore(minDate)) minDate = item.date;
          if (item.date.isAfter(maxDate)) maxDate = item.date;
        case GanttSection():
          break;
      }
    }
    final totalDays = math.max(1, _daysBetween(minDate, maxDate));
    final plotWidth = math.max(_minPlotWidth, totalDays * _pxPerDay);

    var nameColumnWidth = _minNameColumnWidth;
    for (final item in diagram.items) {
      switch (item) {
        case GanttTask():
          final ts = measurer.measure(item.name, _nameStyle);
          nameColumnWidth = math.max(
              nameColumnWidth, ts.width + _nameColumnPaddingX * 2);
        case GanttMilestone():
          final ts = measurer.measure(item.name, _nameStyle);
          nameColumnWidth = math.max(
              nameColumnWidth, ts.width + _nameColumnPaddingX * 2);
        case GanttSection():
          break;
      }
    }

    final shapes = <SceneShape>[];
    final plotLeft = _padding + nameColumnWidth;
    final axisTop = _padding.toDouble();
    final axisBottom = axisTop + _axisHeight;
    final rowsTop = axisBottom + _axisGap;

    shapes.add(SceneLine(
      from: Offset(plotLeft, axisBottom),
      to: Offset(plotLeft + plotWidth, axisBottom),
      head: null,
      stroke: _axisColor,
    ));
    final tickStep = _chooseTickStep(totalDays);
    for (var d = 0; d <= totalDays; d += tickStep) {
      final x = plotLeft + d * _pxPerDay;
      shapes.add(SceneLine(
        from: Offset(x, axisBottom - 4),
        to: Offset(x, axisBottom),
        head: null,
        stroke: _axisTickColor,
      ));
      final date = minDate.add(Duration(days: d));
      shapes.add(SceneText(
        offset: Offset(x + 2, axisTop + 4),
        text: _formatDate(date),
        textStyle: _axisStyle,
      ));
    }

    var y = rowsTop;
    for (final item in diagram.items) {
      switch (item) {
        case GanttTask():
          final startDays = _daysBetween(minDate, item.start);
          final durDays = math.max(1, item.duration.inDays);
          final barX = plotLeft + startDays * _pxPerDay;
          final barW = durDays * _pxPerDay;
          shapes.add(SceneText(
            offset: Offset(_padding, y + (_rowHeight - 14) / 2),
            text: item.name,
            textStyle: _nameStyle,
          ));
          shapes.add(SceneBox(
            rect: Rect.fromLTWH(
                barX, y + _barPaddingY, barW, _barHeight),
            textStyle: _nameStyle,
            fill: item.color ?? _barFill,
            stroke: _barStroke,
          ));
          y += _rowHeight + _rowGap;
        case GanttMilestone():
          final days = _daysBetween(minDate, item.date);
          final cx = plotLeft + days * _pxPerDay;
          final cy = y + _rowHeight / 2;
          shapes.add(SceneText(
            offset: Offset(_padding, y + (_rowHeight - 14) / 2),
            text: item.name,
            textStyle: _nameStyle,
          ));
          shapes.add(SceneDiamond(
            rect: Rect.fromCenter(
              center: Offset(cx, cy),
              width: _milestoneSize,
              height: _milestoneSize,
            ),
            textStyle: _nameStyle,
            fill: _milestoneFill,
            stroke: _milestoneStroke,
          ));
          y += _rowHeight + _rowGap;
        case GanttSection():
          final midY = y + _rowHeight / 2;
          shapes.add(SceneLine(
            from: Offset(_padding, midY),
            to: Offset(plotLeft + plotWidth, midY),
            head: null,
            stroke: _sectionColor,
            strokeWidth: _sectionStrokeWidth,
          ));
          shapes.add(SceneText(
            offset: Offset(_padding, y),
            text: item.title,
            textStyle: _sectionStyle,
          ));
          y += _rowHeight + _rowGap;
      }
    }

    final totalWidth = plotLeft + plotWidth + _padding;
    final totalHeight = y + _padding;
    return Scene(
      size: Size(totalWidth, totalHeight),
      shapes: List.unmodifiable(shapes),
      background: diagram.skin.backgroundColor,
    );
  }

  static int _daysBetween(DateTime a, DateTime b) {
    final aUtc = DateTime.utc(a.year, a.month, a.day);
    final bUtc = DateTime.utc(b.year, b.month, b.day);
    return bUtc.difference(aUtc).inDays;
  }

  static int _chooseTickStep(int totalDays) {
    if (totalDays <= 14) return 1;
    if (totalDays <= 30) return 2;
    if (totalDays <= 90) return 7;
    if (totalDays <= 365) return 30;
    return 90;
  }

  static String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}
