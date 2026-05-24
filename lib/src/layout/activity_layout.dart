import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class ActivityLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _vGap = 18.0;
  static const _actionPaddingX = 14.0;
  static const _actionPaddingY = 8.0;
  static const _actionMinWidth = 80.0;
  static const _actionMinHeight = 28.0;
  static const _diamondPaddingX = 24.0;
  static const _diamondPaddingY = 12.0;
  static const _diamondMinWidth = 100.0;
  static const _diamondMinHeight = 44.0;
  static const _startStopRadius = 10.0;
  static const _branchLabelGap = 4.0;
  static const _partitionPadding = 12.0;
  static const _partitionLabelHeight = 18.0;
  static const _forkBarHeight = 6.0;

  static const _actionStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
  );
  static const _diamondStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
  );
  static const _branchLabelStyle = TextStyle(
    color: Color(0xFF333333),
    fontSize: 10,
  );
  static const _partitionLabelStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const _actionFill = Color(0xFFFFFFCC);
  static const _diamondFill = Color(0xFFFFFFCC);
  static const _strokeColor = Color(0xFF000000);
  static const _partitionStroke = Color(0xFF606060);

  const ActivityLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! ActivityDiagram) {
      throw ArgumentError('ActivityLayout expects ActivityDiagram');
    }
    if (diagram.nodes.isEmpty) {
      return Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.skin.backgroundColor,
      );
    }

    final shapes = <SceneShape>[];
    final ctx = _LayoutContext(measurer: measurer, shapes: shapes);
    final centerX = _padding + 200.0;
    final result = _layoutSequence(diagram.nodes, ctx, centerX, _padding);

    // Compute scene size based on emitted shapes.
    var maxRight = 0.0;
    var maxBottom = 0.0;
    for (final s in shapes) {
      final r = _shapeBounds(s);
      if (r != null) {
        if (r.right > maxRight) maxRight = r.right;
        if (r.bottom > maxBottom) maxBottom = r.bottom;
      }
    }
    final width = math.max(maxRight, result.right) + _padding;
    final height = math.max(maxBottom, result.bottomY) + _padding;

    return Scene(
      size: Size(width, height),
      shapes: shapes,
      background: diagram.skin.backgroundColor,
    );
  }

  Rect? _shapeBounds(SceneShape s) {
    switch (s) {
      case SceneBox():
        return s.rect;
      case SceneNote():
        return s.rect;
      case SceneSymbol():
        return s.rect;
      case SceneEllipse():
        return s.rect;
      case SceneDiamond():
        return s.rect;
      case SceneRoundedBox():
        return s.rect;
      case SceneCircle():
        final r = s.radius;
        return Rect.fromLTRB(
            s.center.dx - r, s.center.dy - r, s.center.dx + r, s.center.dy + r);
      case SceneText():
        return null;
      case SceneLine():
        final left = math.min(s.from.dx, s.to.dx);
        final top = math.min(s.from.dy, s.to.dy);
        final right = math.max(s.from.dx, s.to.dx);
        final bottom = math.max(s.from.dy, s.to.dy);
        return Rect.fromLTRB(left, top, right, bottom);
      case SceneCrowFoot():
        return Rect.fromCircle(center: s.position, radius: 16);
    }
  }

  _Flow _layoutSequence(
    List<ActivityNode> nodes,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    var y = topY;
    var entryY = topY;
    var exitY = topY;
    var hasEntry = false;
    var hasExit = false;
    var left = centerX;
    var right = centerX;

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final flow = _layoutNode(node, ctx, centerX, y);

      if (i == 0) {
        entryY = flow.topY;
        hasEntry = flow.hasEntry;
      }
      if (i > 0 && hasExit && flow.hasEntry) {
        ctx.shapes.add(SceneLine(
          from: Offset(centerX, exitY),
          to: Offset(centerX, flow.topY),
          head: ArrowHead.filled,
          stroke: _strokeColor,
        ));
      }
      exitY = flow.bottomY;
      hasExit = flow.hasExit;
      y = flow.bottomY + _vGap;
      if (flow.left < left) left = flow.left;
      if (flow.right > right) right = flow.right;
    }

    return _Flow(
      topY: entryY,
      bottomY: exitY,
      hasEntry: hasEntry,
      hasExit: hasExit,
      left: left,
      right: right,
    );
  }

  _Flow _layoutNode(
    ActivityNode node,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    switch (node) {
      case StartNode():
      case StopNode():
      case EndNode():
        return _layoutTerminator(node, ctx, centerX, topY);
      case Action():
        return _layoutAction(node, ctx, centerX, topY);
      case IfBlock():
        return _layoutIf(node, ctx, centerX, topY);
      case WhileBlock():
        return _layoutWhile(node, ctx, centerX, topY);
      case RepeatBlock():
        return _layoutRepeat(node, ctx, centerX, topY);
      case ForkBlock():
        return _layoutFork(node, ctx, centerX, topY);
      case Partition():
        return _layoutPartition(node, ctx, centerX, topY);
    }
  }

  _Flow _layoutTerminator(
    ActivityNode node,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    final center = Offset(centerX, topY + _startStopRadius);
    ctx.shapes.add(SceneCircle(
      center: center,
      radius: _startStopRadius,
      fill: _strokeColor,
      stroke: _strokeColor,
      ring: node is StopNode || node is EndNode,
    ));
    final bottomY = topY + _startStopRadius * 2;
    return _Flow(
      topY: topY,
      bottomY: bottomY,
      hasEntry: node is! StartNode,
      hasExit: node is StartNode,
      left: center.dx - _startStopRadius,
      right: center.dx + _startStopRadius,
    );
  }

  _Flow _layoutAction(
    Action action,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    final size = ctx.measurer.measure(action.text, _actionStyle);
    final width = math.max(_actionMinWidth, size.width + _actionPaddingX * 2);
    final height = math.max(_actionMinHeight, size.height + _actionPaddingY * 2);
    final rect = Rect.fromLTWH(centerX - width / 2, topY, width, height);
    ctx.shapes.add(SceneRoundedBox(
      rect: rect,
      label: action.text,
      textStyle: _actionStyle,
      fill: _actionFill,
      stroke: _strokeColor,
    ));
    return _Flow(
      topY: topY,
      bottomY: rect.bottom,
      hasEntry: true,
      hasExit: true,
      left: rect.left,
      right: rect.right,
    );
  }

  _Flow _layoutIf(
    IfBlock block,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    // Single decision diamond at top, then a single combined body below
    // (rather than parallel columns) for v1 simplicity.
    final firstCondition = block.branches.isNotEmpty
        ? block.branches.first.condition
        : '';
    final diamondSize = ctx.measurer.measure(firstCondition, _diamondStyle);
    final width = math.max(
        _diamondMinWidth, diamondSize.width + _diamondPaddingX * 2);
    final height = math.max(
        _diamondMinHeight, diamondSize.height + _diamondPaddingY * 2);
    final diamondRect =
        Rect.fromLTWH(centerX - width / 2, topY, width, height);
    ctx.shapes.add(SceneDiamond(
      rect: diamondRect,
      label: firstCondition,
      textStyle: _diamondStyle,
      fill: _diamondFill,
      stroke: _strokeColor,
    ));

    var minLeft = diamondRect.left;
    var maxRight = diamondRect.right;
    var y = diamondRect.bottom + _vGap;

    // Optional "then" branch label inline next to the down arrow.
    if (block.branches.isNotEmpty &&
        block.branches.first.thenLabel != null &&
        block.branches.first.thenLabel!.isNotEmpty) {
      ctx.shapes.add(SceneText(
        offset: Offset(
          diamondRect.right + _branchLabelGap,
          diamondRect.bottom - 12,
        ),
        text: block.branches.first.thenLabel!,
        textStyle: _branchLabelStyle,
      ));
    }

    // Render each branch's body sequentially down the spine. This is the
    // v1 simplification documented in README.
    for (var i = 0; i < block.branches.length; i++) {
      final branch = block.branches[i];
      if (branch.body.isEmpty) continue;
      final flow = _layoutSequence(branch.body, ctx, centerX, y);
      ctx.shapes.add(SceneLine(
        from: Offset(centerX, y - _vGap),
        to: Offset(centerX, flow.topY),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
      y = flow.bottomY + _vGap;
      if (flow.left < minLeft) minLeft = flow.left;
      if (flow.right > maxRight) maxRight = flow.right;
    }

    if (block.elseBody.isNotEmpty) {
      if (block.elseLabel != null && block.elseLabel!.isNotEmpty) {
        ctx.shapes.add(SceneText(
          offset: Offset(
            diamondRect.left - 40,
            diamondRect.center.dy - 6,
          ),
          text: block.elseLabel!,
          textStyle: _branchLabelStyle,
        ));
      }
      final flow = _layoutSequence(block.elseBody, ctx, centerX, y);
      ctx.shapes.add(SceneLine(
        from: Offset(centerX, y - _vGap),
        to: Offset(centerX, flow.topY),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
      y = flow.bottomY + _vGap;
      if (flow.left < minLeft) minLeft = flow.left;
      if (flow.right > maxRight) maxRight = flow.right;
    }

    // Merge diamond at the bottom.
    final mergeSize = math.min(_diamondMinHeight, 24.0);
    final mergeRect = Rect.fromCenter(
      center: Offset(centerX, y + mergeSize / 2),
      width: mergeSize * 1.4,
      height: mergeSize,
    );
    ctx.shapes.add(SceneDiamond(
      rect: mergeRect,
      textStyle: _diamondStyle,
      fill: _diamondFill,
      stroke: _strokeColor,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(centerX, y - _vGap),
      to: Offset(centerX, mergeRect.top),
      head: ArrowHead.filled,
      stroke: _strokeColor,
    ));
    return _Flow(
      topY: topY,
      bottomY: mergeRect.bottom,
      hasEntry: true,
      hasExit: true,
      left: minLeft,
      right: maxRight,
    );
  }

  _Flow _layoutWhile(
    WhileBlock block,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    final size = ctx.measurer.measure(block.condition, _diamondStyle);
    final width = math.max(_diamondMinWidth, size.width + _diamondPaddingX * 2);
    final height = math.max(_diamondMinHeight, size.height + _diamondPaddingY * 2);
    final diamondRect =
        Rect.fromLTWH(centerX - width / 2, topY, width, height);
    ctx.shapes.add(SceneDiamond(
      rect: diamondRect,
      label: block.condition,
      textStyle: _diamondStyle,
      fill: _diamondFill,
      stroke: _strokeColor,
    ));
    if (block.isLabel != null && block.isLabel!.isNotEmpty) {
      ctx.shapes.add(SceneText(
        offset: Offset(
          diamondRect.right + _branchLabelGap,
          diamondRect.bottom - 14,
        ),
        text: block.isLabel!,
        textStyle: _branchLabelStyle,
      ));
    }
    if (block.endLabel != null && block.endLabel!.isNotEmpty) {
      ctx.shapes.add(SceneText(
        offset: Offset(
          diamondRect.left - 40,
          diamondRect.center.dy - 6,
        ),
        text: block.endLabel!,
        textStyle: _branchLabelStyle,
      ));
    }
    final bodyTop = diamondRect.bottom + _vGap;
    final flow = _layoutSequence(block.body, ctx, centerX, bodyTop);
    if (block.body.isNotEmpty) {
      ctx.shapes.add(SceneLine(
        from: Offset(centerX, diamondRect.bottom),
        to: Offset(centerX, flow.topY),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
    }
    final bottomY = block.body.isEmpty ? diamondRect.bottom : flow.bottomY;
    return _Flow(
      topY: topY,
      bottomY: bottomY,
      hasEntry: true,
      hasExit: true,
      left: math.min(diamondRect.left, flow.left),
      right: math.max(diamondRect.right, flow.right),
    );
  }

  _Flow _layoutRepeat(
    RepeatBlock block,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    final entryRect = Rect.fromCenter(
      center: Offset(centerX, topY + 14),
      width: 50,
      height: 28,
    );
    ctx.shapes.add(SceneDiamond(
      rect: entryRect,
      label: '',
      textStyle: _diamondStyle,
      fill: _diamondFill,
      stroke: _strokeColor,
    ));
    final bodyTop = entryRect.bottom + _vGap;
    final flow = _layoutSequence(block.body, ctx, centerX, bodyTop);
    if (block.body.isNotEmpty) {
      ctx.shapes.add(SceneLine(
        from: Offset(centerX, entryRect.bottom),
        to: Offset(centerX, flow.topY),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
    }
    final whileText = block.whileCondition ?? '';
    final wSize = ctx.measurer.measure(whileText, _diamondStyle);
    final wWidth = math.max(_diamondMinWidth, wSize.width + _diamondPaddingX * 2);
    final wHeight =
        math.max(_diamondMinHeight, wSize.height + _diamondPaddingY * 2);
    final whileRect = Rect.fromLTWH(
        centerX - wWidth / 2, flow.bottomY + _vGap, wWidth, wHeight);
    ctx.shapes.add(SceneDiamond(
      rect: whileRect,
      label: whileText,
      textStyle: _diamondStyle,
      fill: _diamondFill,
      stroke: _strokeColor,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(centerX, flow.bottomY),
      to: Offset(centerX, whileRect.top),
      head: ArrowHead.filled,
      stroke: _strokeColor,
    ));
    return _Flow(
      topY: topY,
      bottomY: whileRect.bottom,
      hasEntry: true,
      hasExit: true,
      left: math.min(entryRect.left, math.min(whileRect.left, flow.left)),
      right: math.max(entryRect.right, math.max(whileRect.right, flow.right)),
    );
  }

  _Flow _layoutFork(
    ForkBlock block,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    // For v1 we stack fork branches vertically rather than side-by-side,
    // separated by thick bars.
    final topBarY = topY;
    final forkLeftPlaceholder = centerX - 60;
    final forkRightPlaceholder = centerX + 60;
    final topBarRect = Rect.fromLTWH(
      forkLeftPlaceholder,
      topBarY,
      forkRightPlaceholder - forkLeftPlaceholder,
      _forkBarHeight,
    );
    ctx.shapes.add(SceneBox(
      rect: topBarRect,
      fill: _strokeColor,
      stroke: _strokeColor,
      textStyle: _actionStyle,
    ));
    var y = topBarRect.bottom + _vGap;
    var minLeft = topBarRect.left;
    var maxRight = topBarRect.right;
    for (final branch in block.branches) {
      final flow = _layoutSequence(branch, ctx, centerX, y);
      ctx.shapes.add(SceneLine(
        from: Offset(centerX, y - _vGap),
        to: Offset(centerX, flow.topY),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
      y = flow.bottomY + _vGap;
      if (flow.left < minLeft) minLeft = flow.left;
      if (flow.right > maxRight) maxRight = flow.right;
    }
    final bottomBarRect = Rect.fromLTWH(
      minLeft - 8,
      y,
      maxRight - minLeft + 16,
      _forkBarHeight,
    );
    ctx.shapes.add(SceneBox(
      rect: bottomBarRect,
      fill: _strokeColor,
      stroke: _strokeColor,
      textStyle: _actionStyle,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(centerX, y - _vGap),
      to: Offset(centerX, bottomBarRect.top),
      head: ArrowHead.filled,
      stroke: _strokeColor,
    ));
    return _Flow(
      topY: topY,
      bottomY: bottomBarRect.bottom,
      hasEntry: true,
      hasExit: true,
      left: bottomBarRect.left,
      right: bottomBarRect.right,
    );
  }

  _Flow _layoutPartition(
    Partition partition,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    // Reserve label space and lay out body inside; then emit a wrapping box.
    final innerTop = topY + _partitionLabelHeight + _partitionPadding;
    final innerStart = ctx.shapes.length;
    final flow = _layoutSequence(partition.body, ctx, centerX, innerTop);
    final innerLeft = flow.left;
    final innerRight = flow.right;
    final boxRect = Rect.fromLTRB(
      innerLeft - _partitionPadding,
      topY,
      innerRight + _partitionPadding,
      flow.bottomY + _partitionPadding,
    );
    final boxShape = SceneBox(
      rect: boxRect,
      fill: const Color(0x00000000),
      stroke: _partitionStroke,
      textStyle: _partitionLabelStyle,
    );
    final labelShape = SceneText(
      offset: Offset(boxRect.left + _partitionPadding, boxRect.top + 4),
      text: partition.name,
      textStyle: _partitionLabelStyle,
    );
    ctx.shapes.insert(innerStart, boxShape);
    ctx.shapes.insert(innerStart + 1, labelShape);
    return _Flow(
      topY: topY,
      bottomY: boxRect.bottom,
      hasEntry: true,
      hasExit: true,
      left: boxRect.left,
      right: boxRect.right,
    );
  }
}

class _LayoutContext {
  final TextMeasurer measurer;
  final List<SceneShape> shapes;
  _LayoutContext({required this.measurer, required this.shapes});
}

class _Flow {
  final double topY;
  final double bottomY;
  final bool hasEntry;
  final bool hasExit;
  final double left;
  final double right;

  const _Flow({
    required this.topY,
    required this.bottomY,
    required this.hasEntry,
    required this.hasExit,
    required this.left,
    required this.right,
  });
}
