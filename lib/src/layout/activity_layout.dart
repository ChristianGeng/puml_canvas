import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
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
  static const _minBranchWidth = 100.0;
  static const _interBranchGap = 30.0;
  static const _mergeDiamondSize = 24.0;
  static const _killSize = 14.0;

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

    final shapes = <SceneShape>[];
    final ctx = _LayoutContext(measurer: measurer, shapes: shapes);
    final centerX = _padding + 200.0;
    final result = _layoutSequence(diagram.nodes, ctx, centerX, _padding);

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
      case SplitBlock():
        // `split` shares the multi-branch geometry of `fork`; reuse the same
        // layout pass.
        return _layoutFork(
            ForkBlock(branches: node.branches), ctx, centerX, topY);
      case Partition():
        return _layoutPartition(node, ctx, centerX, topY);
      case Detach():
      case Break():
        return _layoutSilentTerminator(ctx, centerX, topY);
      case Kill():
        return _layoutKill(ctx, centerX, topY);
    }
  }

  Size _measureNode(ActivityNode node, TextMeasurer measurer) {
    switch (node) {
      case StartNode():
      case StopNode():
      case EndNode():
        return const Size(_startStopRadius * 2, _startStopRadius * 2);
      case Action():
        final s = measurer.measure(node.text, _actionStyle);
        final w = math.max(_actionMinWidth, s.width + _actionPaddingX * 2);
        final h = math.max(_actionMinHeight, s.height + _actionPaddingY * 2);
        return Size(w, h);
      case IfBlock():
        return _measureIf(node, measurer);
      case WhileBlock():
        final s = measurer.measure(node.condition, _diamondStyle);
        final dw = math.max(_diamondMinWidth, s.width + _diamondPaddingX * 2);
        final dh =
            math.max(_diamondMinHeight, s.height + _diamondPaddingY * 2);
        final bodySize = _measureSubtree(node.body, measurer);
        final w = math.max(dw, bodySize.width);
        final h = dh +
            (node.body.isEmpty ? 0 : _vGap + bodySize.height);
        return Size(w, h);
      case RepeatBlock():
        final entryH = 28.0;
        final bodySize = _measureSubtree(node.body, measurer);
        final wText = measurer.measure(
            node.whileCondition ?? '', _diamondStyle);
        final ww =
            math.max(_diamondMinWidth, wText.width + _diamondPaddingX * 2);
        final wh =
            math.max(_diamondMinHeight, wText.height + _diamondPaddingY * 2);
        final w = math.max(math.max(50.0, bodySize.width), ww);
        final h = entryH +
            (node.body.isEmpty ? 0 : _vGap + bodySize.height) +
            _vGap +
            wh;
        return Size(w, h);
      case ForkBlock():
        return _measureFork(node, measurer);
      case SplitBlock():
        return _measureFork(ForkBlock(branches: node.branches), measurer);
      case Partition():
        final bodySize = _measureSubtree(node.body, measurer);
        final w = bodySize.width + _partitionPadding * 2;
        final h = bodySize.height +
            _partitionLabelHeight +
            _partitionPadding * 2;
        return Size(w, h);
      case Detach():
      case Break():
        return Size.zero;
      case Kill():
        return const Size(_killSize, _killSize);
    }
  }

  Size _measureSubtree(List<ActivityNode> body, TextMeasurer measurer) {
    if (body.isEmpty) return Size.zero;
    var maxW = 0.0;
    var totalH = 0.0;
    for (var i = 0; i < body.length; i++) {
      final s = _measureNode(body[i], measurer);
      if (s.width > maxW) maxW = s.width;
      totalH += s.height;
      if (i > 0) totalH += _vGap;
    }
    return Size(maxW, totalH);
  }

  Size _measureIf(IfBlock block, TextMeasurer measurer) {
    final condSize =
        measurer.measure(block.branches.isNotEmpty
            ? block.branches.first.condition
            : '', _diamondStyle);
    final dw = math.max(_diamondMinWidth, condSize.width + _diamondPaddingX * 2);
    final dh =
        math.max(_diamondMinHeight, condSize.height + _diamondPaddingY * 2);

    final branchSizes = <Size>[];
    var maxBranchH = 0.0;
    var totalBranchW = 0.0;
    for (final br in block.branches) {
      final s = _measureSubtree(br.body, measurer);
      final w = math.max(_minBranchWidth, s.width);
      final h = s.height;
      branchSizes.add(Size(w, h));
      if (h > maxBranchH) maxBranchH = h;
      totalBranchW += w;
    }
    if (block.elseBody.isNotEmpty || block.elseLabel != null) {
      final s = _measureSubtree(block.elseBody, measurer);
      final w = math.max(_minBranchWidth, s.width);
      final h = s.height;
      branchSizes.add(Size(w, h));
      if (h > maxBranchH) maxBranchH = h;
      totalBranchW += w;
    }
    final branchCount = branchSizes.length;
    final totalW = math.max(
      dw,
      totalBranchW + _interBranchGap * math.max(0, branchCount - 1),
    );
    final totalH = dh +
        _vGap +
        maxBranchH +
        _vGap +
        _mergeDiamondSize;
    return Size(totalW, totalH);
  }

  Size _measureFork(ForkBlock block, TextMeasurer measurer) {
    final branchSizes = <Size>[];
    var maxBranchH = 0.0;
    var totalBranchW = 0.0;
    for (final br in block.branches) {
      final s = _measureSubtree(br, measurer);
      final w = math.max(_minBranchWidth, s.width);
      final h = s.height;
      branchSizes.add(Size(w, h));
      if (h > maxBranchH) maxBranchH = h;
      totalBranchW += w;
    }
    final branchCount = branchSizes.length;
    final totalW =
        totalBranchW + _interBranchGap * math.max(0, branchCount - 1);
    final totalH = _forkBarHeight +
        _vGap +
        maxBranchH +
        _vGap +
        _forkBarHeight;
    return Size(totalW, totalH);
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

  _Flow _layoutSilentTerminator(
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    return _Flow(
      topY: topY,
      bottomY: topY,
      hasEntry: false,
      hasExit: false,
      left: centerX,
      right: centerX,
    );
  }

  _Flow _layoutKill(
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
    final half = _killSize / 2;
    final center = Offset(centerX, topY + half);
    ctx.shapes.add(SceneLine(
      from: Offset(center.dx - half, center.dy - half),
      to: Offset(center.dx + half, center.dy + half),
      head: null,
      stroke: _strokeColor,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(center.dx + half, center.dy - half),
      to: Offset(center.dx - half, center.dy + half),
      head: null,
      stroke: _strokeColor,
    ));
    return _Flow(
      topY: topY,
      bottomY: topY + _killSize,
      hasEntry: true,
      hasExit: false,
      left: center.dx - half,
      right: center.dx + half,
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
    final firstCondition = block.branches.isNotEmpty
        ? block.branches.first.condition
        : '';
    final diamondSize = ctx.measurer.measure(firstCondition, _diamondStyle);
    final dWidth = math.max(
        _diamondMinWidth, diamondSize.width + _diamondPaddingX * 2);
    final dHeight = math.max(
        _diamondMinHeight, diamondSize.height + _diamondPaddingY * 2);

    final branches = <_BranchSpec>[];
    for (var i = 0; i < block.branches.length; i++) {
      final br = block.branches[i];
      final size = _measureSubtree(br.body, ctx.measurer);
      final w = math.max(_minBranchWidth, size.width);
      branches.add(_BranchSpec(
        body: br.body,
        width: w,
        height: size.height,
        label: br.thenLabel,
      ));
    }
    final hasElse =
        block.elseBody.isNotEmpty || block.elseLabel != null;
    if (hasElse) {
      final size = _measureSubtree(block.elseBody, ctx.measurer);
      final w = math.max(_minBranchWidth, size.width);
      branches.add(_BranchSpec(
        body: block.elseBody,
        width: w,
        height: size.height,
        label: block.elseLabel,
      ));
    }

    final branchCount = branches.length;
    final totalBranchW = branches.fold<double>(0, (a, b) => a + b.width);
    final span = totalBranchW +
        _interBranchGap * math.max(0, branchCount - 1);
    final spanLeft = centerX - span / 2;

    final diamondRect = Rect.fromLTWH(
      centerX - dWidth / 2,
      topY,
      dWidth,
      dHeight,
    );
    ctx.shapes.add(SceneDiamond(
      rect: diamondRect,
      label: firstCondition,
      textStyle: _diamondStyle,
      fill: _diamondFill,
      stroke: _strokeColor,
    ));

    final branchTopY = diamondRect.bottom + _vGap;
    var maxBranchBottom = branchTopY;
    var minLeft = math.min(diamondRect.left, spanLeft);
    var maxRight = math.max(diamondRect.right, spanLeft + span);

    var cursor = spanLeft;
    for (var i = 0; i < branchCount; i++) {
      final br = branches[i];
      final colLeft = cursor;
      final colCenter = colLeft + br.width / 2;
      cursor += br.width + _interBranchGap;

      if (br.body.isNotEmpty) {
        final flow =
            _layoutSequence(br.body, ctx, colCenter, branchTopY);
        _emitConnector(
          ctx,
          from: Offset(diamondRect.center.dx, diamondRect.bottom),
          toCenterX: colCenter,
          toY: flow.topY,
          label: br.label,
        );
        br.exits = flow.hasExit;
        if (flow.bottomY > maxBranchBottom) maxBranchBottom = flow.bottomY;
        if (flow.left < minLeft) minLeft = flow.left;
        if (flow.right > maxRight) maxRight = flow.right;
      } else {
        if (br.label != null && br.label!.isNotEmpty) {
          ctx.shapes.add(SceneText(
            offset: Offset(
              colCenter + _branchLabelGap,
              diamondRect.bottom + 2,
            ),
            text: br.label!,
            textStyle: _branchLabelStyle,
          ));
        }
      }
    }

    final mergeTopY = maxBranchBottom + _vGap;
    final mergeRect = Rect.fromCenter(
      center: Offset(centerX, mergeTopY + _mergeDiamondSize / 2),
      width: _mergeDiamondSize * 1.4,
      height: _mergeDiamondSize,
    );
    ctx.shapes.add(SceneDiamond(
      rect: mergeRect,
      textStyle: _diamondStyle,
      fill: _diamondFill,
      stroke: _strokeColor,
    ));

    cursor = spanLeft;
    for (var i = 0; i < branchCount; i++) {
      final br = branches[i];
      final colLeft = cursor;
      final colCenter = colLeft + br.width / 2;
      cursor += br.width + _interBranchGap;

      if (br.body.isEmpty) continue;
      if (!br.exits) continue;
      final lastBottomY = branchTopY + br.height;
      _emitTail(
        ctx,
        fromCenterX: colCenter,
        fromY: lastBottomY,
        to: Offset(mergeRect.center.dx, mergeRect.top),
      );
    }

    if (mergeRect.left < minLeft) minLeft = mergeRect.left;
    if (mergeRect.right > maxRight) maxRight = mergeRect.right;

    return _Flow(
      topY: topY,
      bottomY: mergeRect.bottom,
      hasEntry: true,
      hasExit: true,
      left: minLeft,
      right: maxRight,
    );
  }

  void _emitConnector(
    _LayoutContext ctx, {
    required Offset from,
    required double toCenterX,
    required double toY,
    String? label,
  }) {
    final midY = (from.dy + toY) / 2;
    if ((toCenterX - from.dx).abs() < 0.5) {
      ctx.shapes.add(SceneLine(
        from: from,
        to: Offset(toCenterX, toY),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
    } else {
      ctx.shapes.add(SceneLine(
        from: from,
        to: Offset(from.dx, midY),
        head: null,
        stroke: _strokeColor,
      ));
      ctx.shapes.add(SceneLine(
        from: Offset(from.dx, midY),
        to: Offset(toCenterX, midY),
        head: null,
        stroke: _strokeColor,
      ));
      ctx.shapes.add(SceneLine(
        from: Offset(toCenterX, midY),
        to: Offset(toCenterX, toY),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
    }
    if (label != null && label.isNotEmpty) {
      final labelX = (from.dx < toCenterX)
          ? from.dx + _branchLabelGap
          : toCenterX + _branchLabelGap;
      ctx.shapes.add(SceneText(
        offset: Offset(labelX, midY - 12),
        text: label,
        textStyle: _branchLabelStyle,
      ));
    }
  }

  void _emitTail(
    _LayoutContext ctx, {
    required double fromCenterX,
    required double fromY,
    required Offset to,
  }) {
    final midY = math.max(fromY + 1, to.dy - _vGap / 2);
    if ((fromCenterX - to.dx).abs() < 0.5) {
      ctx.shapes.add(SceneLine(
        from: Offset(fromCenterX, fromY),
        to: to,
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
    } else {
      ctx.shapes.add(SceneLine(
        from: Offset(fromCenterX, fromY),
        to: Offset(fromCenterX, midY),
        head: null,
        stroke: _strokeColor,
      ));
      ctx.shapes.add(SceneLine(
        from: Offset(fromCenterX, midY),
        to: Offset(to.dx, midY),
        head: null,
        stroke: _strokeColor,
      ));
      ctx.shapes.add(SceneLine(
        from: Offset(to.dx, midY),
        to: to,
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
    }
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
    if (block.body.isEmpty || flow.hasExit) {
      ctx.shapes.add(SceneLine(
        from: Offset(centerX, flow.bottomY),
        to: Offset(centerX, whileRect.top),
        head: ArrowHead.filled,
        stroke: _strokeColor,
      ));
    }
    if (block.isLabel != null && block.isLabel!.isNotEmpty) {
      ctx.shapes.add(SceneText(
        offset: Offset(
          whileRect.right + _branchLabelGap,
          whileRect.center.dy - 6,
        ),
        text: block.isLabel!,
        textStyle: _branchLabelStyle,
      ));
    }
    if (block.notLabel != null && block.notLabel!.isNotEmpty) {
      ctx.shapes.add(SceneText(
        offset: Offset(
          centerX + _branchLabelGap,
          whileRect.bottom + 2,
        ),
        text: block.notLabel!,
        textStyle: _branchLabelStyle,
      ));
    }
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
    final branches = <_BranchSpec>[];
    for (final br in block.branches) {
      final size = _measureSubtree(br, ctx.measurer);
      final w = math.max(_minBranchWidth, size.width);
      branches.add(_BranchSpec(
        body: br,
        width: w,
        height: size.height,
        label: null,
      ));
    }

    final branchCount = branches.length;
    final totalBranchW = branches.fold<double>(0, (a, b) => a + b.width);
    final span = totalBranchW +
        _interBranchGap * math.max(0, branchCount - 1);
    final spanLeft = centerX - span / 2;

    final topBarRect = Rect.fromLTWH(
      spanLeft,
      topY,
      span,
      _forkBarHeight,
    );
    ctx.shapes.add(SceneBox(
      rect: topBarRect,
      fill: _strokeColor,
      stroke: _strokeColor,
      textStyle: _actionStyle,
    ));

    final branchTopY = topBarRect.bottom + _vGap;
    var maxBranchBottom = branchTopY;
    var minLeft = topBarRect.left;
    var maxRight = topBarRect.right;

    var cursor = spanLeft;
    for (var i = 0; i < branchCount; i++) {
      final br = branches[i];
      final colLeft = cursor;
      final colCenter = colLeft + br.width / 2;
      cursor += br.width + _interBranchGap;

      if (br.body.isNotEmpty) {
        final flow =
            _layoutSequence(br.body, ctx, colCenter, branchTopY);
        _emitConnector(
          ctx,
          from: Offset(colCenter, topBarRect.bottom),
          toCenterX: colCenter,
          toY: flow.topY,
        );
        br.exits = flow.hasExit;
        if (flow.bottomY > maxBranchBottom) maxBranchBottom = flow.bottomY;
        if (flow.left < minLeft) minLeft = flow.left;
        if (flow.right > maxRight) maxRight = flow.right;
      }
    }

    final bottomBarY = maxBranchBottom + _vGap;
    final bottomBarRect = Rect.fromLTWH(
      spanLeft,
      bottomBarY,
      span,
      _forkBarHeight,
    );
    ctx.shapes.add(SceneBox(
      rect: bottomBarRect,
      fill: _strokeColor,
      stroke: _strokeColor,
      textStyle: _actionStyle,
    ));

    cursor = spanLeft;
    for (var i = 0; i < branchCount; i++) {
      final br = branches[i];
      final colLeft = cursor;
      final colCenter = colLeft + br.width / 2;
      cursor += br.width + _interBranchGap;

      if (br.body.isEmpty) continue;
      if (!br.exits) continue;
      final lastBottomY = branchTopY + br.height;
      _emitTail(
        ctx,
        fromCenterX: colCenter,
        fromY: lastBottomY,
        to: Offset(colCenter, bottomBarRect.top),
      );
    }

    return _Flow(
      topY: topY,
      bottomY: bottomBarRect.bottom,
      hasEntry: true,
      hasExit: true,
      left: minLeft,
      right: maxRight,
    );
  }

  _Flow _layoutPartition(
    Partition partition,
    _LayoutContext ctx,
    double centerX,
    double topY,
  ) {
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

class _BranchSpec {
  final List<ActivityNode> body;
  final double width;
  final double height;
  final String? label;
  bool exits = true;

  _BranchSpec({
    required this.body,
    required this.width,
    required this.height,
    required this.label,
  });
}
