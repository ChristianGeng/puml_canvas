import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class TimingLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _laneLabelGap = 12.0;
  static const _laneLabelMinWidth = 80.0;
  static const _laneGap = 16.0;
  static const _laneTopPadding = 14.0;
  static const _laneBottomPadding = 14.0;
  static const _robustStatePadding = 18.0;
  static const _robustMinHeight = 80.0;
  static const _conciseMinHeight = 60.0;
  static const _clockMinHeight = 36.0;
  static const _axisHeight = 22.0;
  static const _axisTickHeight = 4.0;
  static const _axisGap = 8.0;
  static const _segmentMinWidth = 60.0;
  static const _conciseLabelGap = 4.0;
  static const _arrowHeadGap = 0.0;

  static const _laneLabelStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 12, fontWeight: FontWeight.w600);
  static const _stateLabelStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 11);
  static const _axisLabelStyle =
      TextStyle(color: Color(0xFF505050), fontSize: 10);
  static const _arrowLabelStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 10);

  static const _laneStroke = Color(0xFF000000);
  static const _laneFill = Color(0x11000000);
  static const _axisStroke = Color(0xFF606060);
  static const _arrowStroke = Color(0xFF000000);

  const TimingLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! TimingDiagram) {
      throw ArgumentError('TimingLayout expects TimingDiagram');
    }
    if (diagram.lanes.isEmpty) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    final times = <int>{0};
    for (final e in diagram.events) {
      times.add(e.time);
    }
    final sortedTimes = times.toList()..sort();

    final statesByLane = <String, List<String>>{};
    for (final lane in diagram.lanes) {
      statesByLane[lane.alias] = <String>[];
    }
    for (final e in diagram.events) {
      if (e is StateChange) {
        final list = statesByLane[e.lane];
        if (list != null && !list.contains(e.state)) {
          list.add(e.state);
        }
      }
    }
    for (final entry in statesByLane.entries) {
      entry.value.sort();
    }

    var labelWidth = _laneLabelMinWidth;
    for (final lane in diagram.lanes) {
      final size = measurer.measure(lane.label, _laneLabelStyle);
      if (size.width > labelWidth) labelWidth = size.width;
    }

    final laneHeights = <String, double>{};
    for (final lane in diagram.lanes) {
      double bodyHeight;
      switch (lane.kind) {
        case TimingLaneKind.robust:
          final stateCount = math.max(1, statesByLane[lane.alias]!.length);
          bodyHeight = math.max(
            _robustMinHeight,
            (stateCount - 1) * 20.0 + 40.0,
          );
        case TimingLaneKind.concise:
          bodyHeight = _conciseMinHeight;
        case TimingLaneKind.clock:
          bodyHeight = _clockMinHeight;
      }
      laneHeights[lane.alias] =
          bodyHeight + _laneTopPadding + _laneBottomPadding;
    }

    final segmentCount = math.max(1, sortedTimes.length);
    final plotWidth = _segmentMinWidth * segmentCount;

    final plotLeft = _padding + labelWidth + _laneLabelGap;
    final axisTop = _padding;
    final plotTop = axisTop + _axisHeight + _axisGap;

    final timeToX = <int, double>{};
    if (sortedTimes.length == 1) {
      timeToX[sortedTimes.first] = plotLeft;
    } else {
      final maxTime = sortedTimes.last;
      final minTime = sortedTimes.first;
      final span = math.max(1, maxTime - minTime);
      for (final t in sortedTimes) {
        timeToX[t] =
            plotLeft + (t - minTime) / span * plotWidth;
      }
    }
    final plotRight = plotLeft + plotWidth;

    final laneTops = <String, double>{};
    var y = plotTop;
    for (final lane in diagram.lanes) {
      laneTops[lane.alias] = y;
      y += laneHeights[lane.alias]! + _laneGap;
    }
    final bottomY = y - _laneGap;

    final shapes = <SceneShape>[];

    shapes.add(SceneLine(
      from: Offset(plotLeft, axisTop + _axisHeight),
      to: Offset(plotRight, axisTop + _axisHeight),
      head: null,
      stroke: _axisStroke,
    ));
    for (final t in sortedTimes) {
      final x = timeToX[t]!;
      shapes.add(SceneLine(
        from: Offset(x, axisTop + _axisHeight - _axisTickHeight),
        to: Offset(x, axisTop + _axisHeight),
        head: null,
        stroke: _axisStroke,
      ));
      shapes.add(SceneText(
        offset: Offset(x + 2, axisTop),
        text: '@$t',
        textStyle: _axisLabelStyle,
      ));
    }

    for (final lane in diagram.lanes) {
      final top = laneTops[lane.alias]!;
      final height = laneHeights[lane.alias]!;
      shapes.add(SceneText(
        offset: Offset(_padding, top + height / 2 - 7),
        text: lane.label,
        textStyle: _laneLabelStyle,
      ));
      shapes.add(SceneBox(
        rect: Rect.fromLTWH(plotLeft, top, plotWidth, height),
        textStyle: _laneLabelStyle,
        fill: _laneFill,
        stroke: _laneStroke,
        strokeWidth: 0.5,
      ));
    }

    final laneCenters = <String, double>{};
    for (final lane in diagram.lanes) {
      laneCenters[lane.alias] =
          laneTops[lane.alias]! + laneHeights[lane.alias]! / 2;
    }

    for (final lane in diagram.lanes) {
      final laneEvents = <StateChange>[];
      for (final e in diagram.events) {
        if (e is StateChange && e.lane == lane.alias) {
          laneEvents.add(e);
        }
      }
      laneEvents.sort((a, b) => a.time.compareTo(b.time));
      if (laneEvents.isEmpty) continue;
      switch (lane.kind) {
        case TimingLaneKind.robust:
          _renderRobustLane(
            shapes: shapes,
            lane: lane,
            laneEvents: laneEvents,
            states: statesByLane[lane.alias]!,
            top: laneTops[lane.alias]!,
            height: laneHeights[lane.alias]!,
            plotRight: plotRight,
            timeToX: timeToX,
            measurer: measurer,
          );
        case TimingLaneKind.concise:
          _renderConciseLane(
            shapes: shapes,
            laneEvents: laneEvents,
            top: laneTops[lane.alias]!,
            height: laneHeights[lane.alias]!,
            plotRight: plotRight,
            timeToX: timeToX,
          );
        case TimingLaneKind.clock:
          break;
      }
    }

    for (final e in diagram.events) {
      if (e is! TimingArrow) continue;
      final fromY = laneCenters[e.from];
      final toY = laneCenters[e.to];
      if (fromY == null || toY == null) continue;
      final x = timeToX[e.time];
      if (x == null) continue;
      shapes.add(SceneLine(
        from: Offset(x, fromY),
        to: Offset(x, toY - _arrowHeadGap),
        head: ArrowHead.filled,
        stroke: _arrowStroke,
        label: e.label,
        labelStyle: e.label == null ? null : _arrowLabelStyle,
      ));
    }

    final width = plotRight + _padding;
    final height = bottomY + _padding;
    return Scene(
      size: Size(width, height),
      shapes: shapes,
      background: diagram.skin.backgroundColor,
    );
  }

  void _renderRobustLane({
    required List<SceneShape> shapes,
    required TimingLane lane,
    required List<StateChange> laneEvents,
    required List<String> states,
    required double top,
    required double height,
    required double plotRight,
    required Map<int, double> timeToX,
    required TextMeasurer measurer,
  }) {
    final inner = height - _laneTopPadding - _laneBottomPadding;
    final stateCount = math.max(1, states.length);
    double yForState(String state) {
      if (states.isEmpty) return top + height / 2;
      final idx = states.indexOf(state);
      if (idx < 0) return top + height / 2;
      if (stateCount == 1) return top + height / 2;
      final step = inner / (stateCount - 1);
      return top + _laneTopPadding + step * (stateCount - 1 - idx);
    }

    for (var i = 0; i < laneEvents.length; i++) {
      final e = laneEvents[i];
      final x1 = timeToX[e.time]!;
      final x2 =
          i + 1 < laneEvents.length ? timeToX[laneEvents[i + 1].time]! : plotRight;
      final y = yForState(e.state);
      shapes.add(SceneLine(
        from: Offset(x1, y),
        to: Offset(x2, y),
        head: null,
        stroke: _arrowStroke,
        strokeWidth: 1.5,
      ));
      shapes.add(SceneText(
        offset: Offset(x1 + _robustStatePadding / 4, y - 14),
        text: e.state,
        textStyle: _stateLabelStyle,
      ));
      if (i + 1 < laneEvents.length) {
        final next = laneEvents[i + 1];
        if (next.state != e.state) {
          final yNext = yForState(next.state);
          shapes.add(SceneLine(
            from: Offset(x2, y),
            to: Offset(x2, yNext),
            head: null,
            stroke: _arrowStroke,
            strokeWidth: 1.5,
          ));
        }
      }
    }
  }

  void _renderConciseLane({
    required List<SceneShape> shapes,
    required List<StateChange> laneEvents,
    required double top,
    required double height,
    required double plotRight,
    required Map<int, double> timeToX,
  }) {
    final midY = top + height / 2 + 6;
    for (var i = 0; i < laneEvents.length; i++) {
      final e = laneEvents[i];
      final x1 = timeToX[e.time]!;
      final x2 =
          i + 1 < laneEvents.length ? timeToX[laneEvents[i + 1].time]! : plotRight;
      shapes.add(SceneLine(
        from: Offset(x1, midY),
        to: Offset(x2, midY),
        head: null,
        stroke: _arrowStroke,
        strokeWidth: 1.5,
      ));
      shapes.add(SceneText(
        offset: Offset(x1 + 4, midY - 14 - _conciseLabelGap),
        text: e.state,
        textStyle: _stateLabelStyle,
      ));
      if (i + 1 < laneEvents.length) {
        final next = laneEvents[i + 1];
        if (next.state != e.state) {
          shapes.add(SceneLine(
            from: Offset(x2, midY - 6),
            to: Offset(x2, midY + 6),
            head: null,
            stroke: _arrowStroke,
            strokeWidth: 1.5,
          ));
        }
      }
    }
  }
}
