import 'dart:math' as math;

import 'package:flutter/painting.dart';

class OrthogonalEdgeRouter {
  static const _epsilon = 0.001;
  static const _obstacleClearance = 18.0;

  const OrthogonalEdgeRouter();

  List<Offset> route(
    Rect from,
    Rect to, {
    List<Rect> obstacles = const [],
    double laneOffset = 0.0,
  }) {
    if (_hasVerticalGap(from, to)) {
      final fromAbove = from.center.dy < to.center.dy;
      final start = Offset(from.center.dx, fromAbove ? from.bottom : from.top);
      final end = Offset(to.center.dx, fromAbove ? to.top : to.bottom);
      if (laneOffset != 0 && (start.dx - end.dx).abs() < _epsilon) {
        final detourX = start.dx + laneOffset;
        return _simplify([
          start,
          Offset(detourX, start.dy),
          Offset(detourX, end.dy),
          end,
        ]);
      }
      final midY = (start.dy + end.dy) / 2 + laneOffset;
      return _simplify([
        start,
        Offset(start.dx, midY),
        Offset(end.dx, midY),
        end,
      ]);
    }

    if (_hasHorizontalGap(from, to)) {
      final fromLeft = from.center.dx < to.center.dx;
      final start = Offset(fromLeft ? from.right : from.left, from.center.dy);
      final end = Offset(fromLeft ? to.left : to.right, to.center.dy);
      final blockers = _horizontalBlockers(start, end, obstacles);
      if (laneOffset != 0 || blockers.isNotEmpty) {
        final detourY = blockers.isEmpty
            ? start.dy + laneOffset
            : _horizontalDetourY(blockers, start.dy, laneOffset);
        return _simplify([
          start,
          Offset(start.dx, detourY),
          Offset(end.dx, detourY),
          end,
        ]);
      }
      final midX = (start.dx + end.dx) / 2;
      return _simplify([
        start,
        Offset(midX, start.dy),
        Offset(midX, end.dy),
        end,
      ]);
    }

    return _simplify([
      _edgePoint(from, to.center),
      _edgePoint(to, from.center),
    ]);
  }

  List<Rect> _horizontalBlockers(
    Offset start,
    Offset end,
    List<Rect> obstacles,
  ) {
    final corridor = Rect.fromLTRB(
      math.min(start.dx, end.dx),
      start.dy - 2,
      math.max(start.dx, end.dx),
      start.dy + 2,
    );
    return [
      for (final obstacle in obstacles)
        if (obstacle.overlaps(corridor)) obstacle,
    ];
  }

  double _horizontalDetourY(
    List<Rect> blockers,
    double centerY,
    double laneOffset,
  ) {
    var top = double.infinity;
    var bottom = double.negativeInfinity;
    for (final blocker in blockers) {
      top = math.min(top, blocker.top);
      bottom = math.max(bottom, blocker.bottom);
    }
    final above = top - _obstacleClearance - laneOffset.abs();
    final below = bottom + _obstacleClearance + laneOffset.abs();
    if (above >= 0 && (centerY - above).abs() <= (below - centerY).abs()) {
      return above;
    }
    return below;
  }

  bool _hasVerticalGap(Rect from, Rect to) {
    return from.bottom <= to.top || to.bottom <= from.top;
  }

  bool _hasHorizontalGap(Rect from, Rect to) {
    return from.right <= to.left || to.right <= from.left;
  }

  List<Offset> _simplify(List<Offset> points) {
    final unique = <Offset>[];
    for (final point in points) {
      if (unique.isEmpty || !_samePoint(unique.last, point)) {
        unique.add(point);
      }
    }

    var i = 1;
    while (i < unique.length - 1) {
      final a = unique[i - 1];
      final b = unique[i];
      final c = unique[i + 1];
      if (_collinear(a, b, c)) {
        unique.removeAt(i);
      } else {
        i++;
      }
    }
    return List.unmodifiable(unique);
  }

  bool _samePoint(Offset a, Offset b) {
    return (a.dx - b.dx).abs() < _epsilon && (a.dy - b.dy).abs() < _epsilon;
  }

  bool _collinear(Offset a, Offset b, Offset c) {
    final abx = b.dx - a.dx;
    final aby = b.dy - a.dy;
    final bcx = c.dx - b.dx;
    final bcy = c.dy - b.dy;
    return (abx * bcy - aby * bcx).abs() < _epsilon;
  }

  Offset _edgePoint(Rect rect, Offset toward) {
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
