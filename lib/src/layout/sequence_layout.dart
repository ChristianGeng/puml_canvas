import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import 'decoration_wrapper.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class SequenceLayout implements DiagramLayout {
  static const _padding = 16.0;
  static const _actorBoxPaddingX = 12.0;
  static const _actorBoxPaddingY = 8.0;
  static const _actorMinWidth = 80.0;
  static const _actorGap = 32.0;
  static const _messageGap = 40.0;
  static const _selfMessageWidth = 30.0;
  static const _selfMessageHeight = 25.0;
  static const _notePaddingX = 8.0;
  static const _notePaddingY = 6.0;
  static const _noteHorizontalGap = 8.0;
  static const _noteVerticalGap = 8.0;
  static const _noteMaxWidth = 200.0;
  static const _activationBarWidth = 10.0;
  static const _activationNestingOffset = 5.0;
  static const _groupPaddingTop = 6.0;
  static const _groupPaddingBottom = 8.0;
  static const _groupHorizontalPadding = 16.0;
  static const _groupLabelTabHeight = 18.0;
  static const _groupLabelTabPaddingX = 6.0;
  static const _groupBranchTopPadding = 6.0;
  static const _groupGapAfter = 8.0;
  static const _groupElseDividerGap = 10.0;
  static const _labelStyle = TextStyle(color: Color(0xFF000000), fontSize: 12);
  static const _noteStyle = TextStyle(color: Color(0xFF000000), fontSize: 11);
  static const _groupKindStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 10, fontWeight: FontWeight.w600);
  static const _groupBranchStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 11, fontStyle: FontStyle.italic);
  static const _groupBorder = Color(0xFF7E7E7E);
  static const _groupLabelTabFill = Color(0xFFE5E5E5);
  static const _refBoxPaddingX = 12.0;
  static const _refBoxPaddingY = 8.0;
  static const _refBoxVerticalGap = 8.0;
  static const _refBoxHorizontalPadding = 16.0;
  static const _refBoxTabHeight = 16.0;
  static const _refBoxTabPaddingX = 6.0;
  static const _refBoxBorder = Color(0xFF5C5C5C);
  static const _refBoxFill = Color(0xFFF5F5F5);
  static const _refBoxTabFill = Color(0xFFD9D9D9);
  static const _refBoxTabStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 10, fontWeight: FontWeight.w600);
  static const _refBoxBodyStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 11);
  static const _separatorTitleHeight = 30.0;
  static const _separatorTitlePaddingX = 8.0;
  static const _separatorTitlePaddingY = 3.0;
  static const _separatorSkipHeight = 24.0;
  static const _separatorDashHeight = 12.0;
  static const _separatorDelayMin = 20.0;
  static const _separatorDelayMax = 200.0;
  static const _separatorDelayDefault = 30.0;
  static const _separatorTitleStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 12, fontWeight: FontWeight.w600);
  static const _separatorSkipStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 14, fontWeight: FontWeight.w600);
  static const _separatorTitleFill = Color(0xFFE5E5E5);
  static const _separatorStroke = Color(0xFF000000);
  static const _newPageStrokeWidth = 2.5;
  static const _newPageTopPadding = 10.0;
  static const _newPageBottomPadding = 10.0;
  static const _newPageTitleGap = 4.0;
  static const _newPageTitleStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 11, fontWeight: FontWeight.w600);
  static const _participantBoxPaddingX = 8.0;
  static const _participantBoxLabelGap = 4.0;
  static const _participantBoxPaddingBottom = 6.0;
  static const _participantBoxDefaultFill = Color(0x33C0C0C0);
  static const _participantBoxDefaultStroke = Color(0xFF808080);
  static const _participantBoxLabelStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 11, fontWeight: FontWeight.w600);
  static const _actorIconHeight = 36.0;
  static const _smallIconHeight = 22.0;
  static const _databaseCapHeight = 6.0;
  static const _collectionsOffset = 6.0;
  static const _queueCapWidth = 8.0;

  const SequenceLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! SequenceDiagram) {
      throw ArgumentError('SequenceLayout expects SequenceDiagram');
    }

    final participants = diagram.participantsInOrder();
    if (participants.isEmpty) {
      final emptyInner = Scene(
        size: Size.zero,
        shapes: const [],
        background: diagram.decorations.skin.backgroundColor,
      );
      return wrapWithDecorations(emptyInner, diagram.decorations, measurer);
    }

    final skin = diagram.decorations.skin;
    final labelStyle = skin.defaultFontSize == null
        ? _labelStyle
        : _labelStyle.copyWith(fontSize: skin.defaultFontSize);
    final noteStyle = skin.defaultFontSize == null
        ? _noteStyle
        : _noteStyle.copyWith(fontSize: skin.defaultFontSize);
    final defaultArrowColor =
        skin.sequenceArrowColor ?? const Color(0xFF000000);
    final lifelineStroke =
        skin.sequenceLifeLineBackgroundColor ?? const Color(0xFF000000);
    final actorFill =
        skin.participantBackgroundColor ?? const Color(0xFFFFFFFF);
    final actorStroke =
        skin.participantBorderColor ?? const Color(0xFF000000);
    final noteFill = skin.noteBackgroundColor ?? const Color(0xFFFEF9C3);
    final noteStroke = skin.noteBorderColor ?? const Color(0xFF000000);

    final actorWidths = <String, double>{};
    final actorHeights = <String, double>{};
    var actorBoxHeight = 0.0;
    for (final p in participants) {
      final size = measurer.measure(p.label, labelStyle);
      final (w, h) = _symbolSize(p.kind, size);
      actorWidths[p.alias] = w;
      actorHeights[p.alias] = h;
      if (h > actorBoxHeight) actorBoxHeight = h;
    }

    final actorCenters = <String, double>{};
    var x = _padding;
    for (final p in participants) {
      final w = actorWidths[p.alias]!;
      actorCenters[p.alias] = x + w / 2;
      x += w + _actorGap;
    }
    var totalWidth = x - _actorGap + _padding;

    final diagramLeftX = participants.isEmpty
        ? _padding
        : actorCenters[participants.first.alias]! - _groupHorizontalPadding;
    final diagramRightX = participants.isEmpty
        ? totalWidth - _padding
        : actorCenters[participants.last.alias]! + _groupHorizontalPadding;

    final totalEventsHeight =
        _planHeight(diagram.events, measurer, noteStyle);

    final shapes = <SceneShape>[];
    final eventShapes = <SceneShape>[];

    final hasBoxes = diagram.boxes.isNotEmpty;
    final boxLabelReserve = hasBoxes
        ? measurer
                .measure('Ag', _participantBoxLabelStyle)
                .height +
            _participantBoxLabelGap * 2
        : 0.0;
    final topActorY = _padding + boxLabelReserve;
    final messagesStartY = topActorY + actorBoxHeight + _messageGap;
    final bottomActorY = messagesStartY + totalEventsHeight;

    final ctx = _Ctx(
      shapes: eventShapes,
      centers: actorCenters,
      measurer: measurer,
      diagramLeftX: diagramLeftX,
      diagramRightX: diagramRightX,
      diagramBottomY: bottomActorY,
      labelStyle: labelStyle,
      noteStyle: noteStyle,
      defaultArrowColor: defaultArrowColor,
      noteFill: noteFill,
      noteStroke: noteStroke,
    );

    _emitEvents(diagram.events, messagesStartY, ctx);

    for (final entry in ctx.activationStacks.entries) {
      final cx = actorCenters[entry.key];
      if (cx == null) continue;
      while (entry.value.isNotEmpty) {
        final startY = entry.value.removeLast();
        final endY = ctx.destroyY[entry.key] ?? bottomActorY;
        _emitActivationBar(
            eventShapes, cx, startY, endY, entry.value.length);
      }
    }

    for (final box in diagram.boxes) {
      if (box.participants.isEmpty) continue;
      var minLeft = double.infinity;
      var maxRight = double.negativeInfinity;
      for (final p in box.participants) {
        final cx = actorCenters[p.alias];
        final w = actorWidths[p.alias];
        if (cx == null || w == null) continue;
        final left = cx - w / 2;
        final right = cx + w / 2;
        if (left < minLeft) minLeft = left;
        if (right > maxRight) maxRight = right;
      }
      if (minLeft == double.infinity) continue;
      final boxLeft = minLeft - _participantBoxPaddingX;
      final boxRight = maxRight + _participantBoxPaddingX;
      final boxTop = _padding;
      final boxBottom =
          topActorY + actorBoxHeight + _participantBoxPaddingBottom;
      final fill = box.color ?? _participantBoxDefaultFill;
      final stroke = box.color ?? _participantBoxDefaultStroke;
      shapes.add(SceneBox(
        rect: Rect.fromLTRB(boxLeft, boxTop, boxRight, boxBottom),
        fill: fill,
        stroke: stroke,
        textStyle: _participantBoxLabelStyle,
      ));
      shapes.add(SceneText(
        offset: Offset(
          boxLeft + _participantBoxPaddingX,
          boxTop + _participantBoxLabelGap,
        ),
        text: box.label,
        textStyle: _participantBoxLabelStyle,
      ));
    }

    for (final p in participants) {
      final w = actorWidths[p.alias]!;
      final h = actorHeights[p.alias]!;
      final cx = actorCenters[p.alias]!;
      final createY = ctx.createY[p.alias];
      final destroyY = ctx.destroyY[p.alias];
      final topY = createY ?? topActorY;
      final topRect = Rect.fromLTWH(cx - w / 2, topY, w, h);
      if (p.kind == ParticipantKind.participant) {
        shapes.add(SceneBox(
          rect: topRect,
          label: p.label,
          textStyle: labelStyle,
          fill: actorFill,
          stroke: actorStroke,
        ));
        if (destroyY == null) {
          shapes.add(SceneBox(
            rect: Rect.fromLTWH(cx - w / 2, bottomActorY, w, h),
            label: p.label,
            textStyle: labelStyle,
            fill: actorFill,
            stroke: actorStroke,
          ));
        }
      } else {
        shapes.add(SceneSymbol(
          rect: topRect,
          label: p.label,
          labelStyle: labelStyle,
          kind: p.kind,
          fill: actorFill,
          stroke: actorStroke,
        ));
        if (destroyY == null) {
          shapes.add(SceneSymbol(
            rect: Rect.fromLTWH(cx - w / 2, bottomActorY, w, h),
            label: p.label,
            labelStyle: labelStyle,
            kind: p.kind,
            fill: actorFill,
            stroke: actorStroke,
          ));
        }
      }
      final lifelineStart = topY + h;
      final lifelineEnd = destroyY ?? bottomActorY;
      if (lifelineEnd > lifelineStart) {
        shapes.add(SceneLine(
          from: Offset(cx, lifelineStart),
          to: Offset(cx, lifelineEnd),
          dashed: true,
          head: null,
          strokeWidth: 0.5,
          stroke: lifelineStroke,
        ));
      }
      if (destroyY != null) {
        _emitDestroyMark(shapes, cx, destroyY);
      }
    }

    shapes.addAll(eventShapes);

    totalWidth = math.max(totalWidth, ctx.rightmost + _padding);
    final diagramBottomY = bottomActorY + actorBoxHeight;
    final totalHeight = diagramBottomY + _padding;

    final innerScene = Scene(
      size: Size(totalWidth, totalHeight),
      shapes: shapes,
      background: skin.backgroundColor,
    );
    return wrapWithDecorations(innerScene, diagram.decorations, measurer);
  }

  void _emitDestroyMark(List<SceneShape> shapes, double cx, double y) {
    const half = 5.0;
    final stroke = const Color(0xFF000000);
    shapes.add(SceneLine(
      from: Offset(cx - half, y - half),
      to: Offset(cx + half, y + half),
      dashed: false,
      head: null,
      stroke: stroke,
      strokeWidth: 1.5,
    ));
    shapes.add(SceneLine(
      from: Offset(cx - half, y + half),
      to: Offset(cx + half, y - half),
      dashed: false,
      head: null,
      stroke: stroke,
      strokeWidth: 1.5,
    ));
  }

  double _planHeight(List<SequenceEvent> events, TextMeasurer measurer,
      TextStyle noteStyle) {
    var total = 0.0;
    for (final e in events) {
      total += _planEventHeight(e, measurer, noteStyle);
    }
    return total;
  }

  double _planEventHeight(
      SequenceEvent event, TextMeasurer measurer, TextStyle noteStyle) {
    switch (event) {
      case Message():
        return event.from == event.to
            ? _messageGap + _selfMessageHeight
            : _messageGap;
      case Note():
        final size = _measureNoteText(event.text, measurer, noteStyle);
        return size.height + _notePaddingY * 2 + _noteVerticalGap * 2;
      case RefBox():
        final size = measurer.measure(event.text, _refBoxBodyStyle);
        return _refBoxTabHeight +
            size.height +
            _refBoxPaddingY * 2 +
            _refBoxVerticalGap * 2;
      case Activate():
      case Deactivate():
      case Create():
      case Destroy():
        return 0;
      case Group():
        var inner = 0.0;
        for (var i = 0; i < event.branches.length; i++) {
          if (i > 0) inner += _groupElseDividerGap * 2;
          inner += _planHeight(event.branches[i].events, measurer, noteStyle);
        }
        return _groupPaddingTop +
            _groupLabelTabHeight +
            _groupBranchTopPadding +
            inner +
            _groupPaddingBottom +
            _groupGapAfter;
      case Separator():
        return _separatorHeight(event);
      case NewPage():
        return _newPageHeight(event, measurer);
    }
  }

  double _newPageHeight(NewPage event, TextMeasurer measurer) {
    final titleHeight = event.title == null
        ? 0.0
        : measurer.measure(event.title!, _newPageTitleStyle).height +
            _newPageTitleGap;
    return _newPageTopPadding + titleHeight + _newPageBottomPadding;
  }

  double _separatorHeight(Separator s) {
    switch (s.kind) {
      case SeparatorKind.title:
        return _separatorTitleHeight;
      case SeparatorKind.delay:
        final px = (s.delayPixels ?? _separatorDelayDefault.toInt()).toDouble();
        return px.clamp(_separatorDelayMin, _separatorDelayMax);
      case SeparatorKind.skip:
        return _separatorSkipHeight;
      case SeparatorKind.dash:
        return _separatorDashHeight;
    }
  }

  double _emitEvents(
      List<SequenceEvent> events, double startY, _Ctx ctx) {
    var y = startY;
    for (final event in events) {
      switch (event) {
        case Message():
          if (event.from == event.to) {
            if (!event.hidden) {
              _emitSelfMessage(event, ctx.centers[event.from]!, y, ctx);
              final loopRight = ctx.centers[event.from]! + _selfMessageWidth;
              if (loopRight > ctx.rightmost) ctx.rightmost = loopRight;
            }
            y += _messageGap + _selfMessageHeight;
          } else {
            if (!event.hidden) {
              _emitStraightMessage(event, ctx.centers[event.from]!,
                  ctx.centers[event.to]!, y, ctx);
            }
            y += _messageGap;
          }
          ctx.lastMessageY = y - _messageGap;
        case Note():
          final size = _measureNoteText(event.text, ctx.measurer, ctx.noteStyle);
          final double innerWidth;
          if (event.text.contains('\n')) {
            innerWidth = size.width;
          } else {
            innerWidth = math
                .min(size.width, _noteMaxWidth - _notePaddingX * 2)
                .clamp(0.0, _noteMaxWidth - _notePaddingX * 2);
          }
          final boxSize = Size(innerWidth + _notePaddingX * 2,
              size.height + _notePaddingY * 2);
          final noteY = y + _noteVerticalGap;
          final rect = _resolveNoteRect(event, boxSize, noteY, ctx.centers);
          ctx.shapes.add(SceneNote(
            rect: rect,
            text: event.text,
            textStyle: ctx.noteStyle,
            fill: ctx.noteFill,
            stroke: ctx.noteStroke,
          ));
          if (rect.right > ctx.rightmost) ctx.rightmost = rect.right;
          y += boxSize.height + _noteVerticalGap * 2;
        case RefBox():
          y = _emitRefBox(event, y, ctx);
        case Activate():
          final stack = ctx.activationStacks
              .putIfAbsent(event.participant, () => <double>[]);
          stack.add(ctx.lastMessageY ?? y);
        case Deactivate():
          final stack = ctx.activationStacks[event.participant];
          if (stack != null && stack.isNotEmpty) {
            final s = stack.removeLast();
            final endY = ctx.lastMessageY ?? y;
            _emitActivationBar(ctx.shapes,
                ctx.centers[event.participant]!, s, endY, stack.length);
          }
        case Create():
          ctx.createY[event.participant] = ctx.lastMessageY ?? y;
        case Destroy():
          ctx.destroyY[event.participant] = ctx.lastMessageY ?? y;
        case Group():
          y = _emitGroup(event, y, ctx);
        case Separator():
          y = _emitSeparator(event, y, ctx);
        case NewPage():
          y = _emitNewPage(event, y, ctx);
      }
    }
    return y - startY;
  }

  double _emitNewPage(NewPage event, double startY, _Ctx ctx) {
    final height = _newPageHeight(event, ctx.measurer);
    var lineY = startY + _newPageTopPadding;
    if (event.title != null) {
      final titleSize = ctx.measurer.measure(event.title!, _newPageTitleStyle);
      final midX = (ctx.diagramLeftX + ctx.diagramRightX) / 2;
      ctx.shapes.add(SceneText(
        offset: Offset(midX - titleSize.width / 2, lineY),
        text: event.title!,
        textStyle: _newPageTitleStyle,
      ));
      lineY += titleSize.height + _newPageTitleGap;
    }
    ctx.shapes.add(SceneLine(
      from: Offset(ctx.diagramLeftX, lineY),
      to: Offset(ctx.diagramRightX, lineY),
      dashed: false,
      head: null,
      stroke: _separatorStroke,
      strokeWidth: _newPageStrokeWidth,
    ));
    if (ctx.diagramRightX > ctx.rightmost) ctx.rightmost = ctx.diagramRightX;
    return startY + height;
  }

  double _emitSeparator(Separator sep, double startY, _Ctx ctx) {
    final height = _separatorHeight(sep);
    final centerY = startY + height / 2;
    switch (sep.kind) {
      case SeparatorKind.title:
        final label = sep.label ?? '';
        final textSize = label.isEmpty
            ? const Size(0, 0)
            : ctx.measurer.measure(label, _separatorTitleStyle);
        final boxWidth =
            textSize.width + _separatorTitlePaddingX * 2;
        final boxHeight =
            textSize.height + _separatorTitlePaddingY * 2;
        final midX = (ctx.diagramLeftX + ctx.diagramRightX) / 2;
        final boxLeft = midX - boxWidth / 2;
        final boxRight = midX + boxWidth / 2;
        ctx.shapes.add(SceneLine(
          from: Offset(ctx.diagramLeftX, centerY),
          to: Offset(boxLeft, centerY),
          dashed: false,
          head: null,
          stroke: _separatorStroke,
        ));
        ctx.shapes.add(SceneLine(
          from: Offset(boxRight, centerY),
          to: Offset(ctx.diagramRightX, centerY),
          dashed: false,
          head: null,
          stroke: _separatorStroke,
        ));
        ctx.shapes.add(SceneBox(
          rect: Rect.fromLTWH(
              boxLeft, centerY - boxHeight / 2, boxWidth, boxHeight),
          fill: _separatorTitleFill,
          stroke: _separatorStroke,
          label: label.isEmpty ? null : label,
          textStyle: _separatorTitleStyle,
        ));
      case SeparatorKind.delay:
        for (final entry in ctx.centers.entries) {
          final cx = entry.value;
          const w = 6.0;
          ctx.shapes.add(SceneLine(
            from: Offset(cx - w, centerY - 2),
            to: Offset(cx + w, centerY - 2),
            dashed: false,
            head: null,
            stroke: _separatorStroke,
          ));
          ctx.shapes.add(SceneLine(
            from: Offset(cx - w, centerY + 2),
            to: Offset(cx + w, centerY + 2),
            dashed: false,
            head: null,
            stroke: _separatorStroke,
          ));
        }
      case SeparatorKind.skip:
        final textSize = ctx.measurer.measure('...', _separatorSkipStyle);
        final midX = (ctx.diagramLeftX + ctx.diagramRightX) / 2;
        ctx.shapes.add(SceneText(
          offset: Offset(
            midX - textSize.width / 2,
            centerY - textSize.height / 2,
          ),
          text: '...',
          textStyle: _separatorSkipStyle,
        ));
      case SeparatorKind.dash:
        ctx.shapes.add(SceneLine(
          from: Offset(ctx.diagramLeftX, centerY),
          to: Offset(ctx.diagramRightX, centerY),
          dashed: true,
          head: null,
          stroke: _separatorStroke,
        ));
    }
    if (ctx.diagramRightX > ctx.rightmost) ctx.rightmost = ctx.diagramRightX;
    return startY + height;
  }

  double _emitGroup(Group group, double startY, _Ctx ctx) {
    final groupTopY = startY + _groupPaddingTop;
    var contentY = groupTopY + _groupLabelTabHeight + _groupBranchTopPadding;

    for (var i = 0; i < group.branches.length; i++) {
      final branch = group.branches[i];
      if (i > 0) {
        final dividerY = contentY + _groupElseDividerGap;
        ctx.shapes.add(SceneLine(
          from: Offset(ctx.diagramLeftX, dividerY),
          to: Offset(ctx.diagramRightX, dividerY),
          dashed: true,
          head: null,
          stroke: _groupBorder,
        ));
        final elseLabel = branch.label == null
            ? '[else]'
            : '[${branch.label}]';
        ctx.shapes.add(SceneText(
          offset:
              Offset(ctx.diagramLeftX + 4, dividerY - _groupBranchStyle.fontSize! - 1),
          text: elseLabel,
          textStyle: _groupBranchStyle,
        ));
        contentY = dividerY + _groupElseDividerGap;
      }
      contentY += _emitEvents(branch.events, contentY, ctx);
    }

    final groupBottomY = contentY + _groupPaddingBottom;

    ctx.shapes.add(SceneBox(
      rect: Rect.fromLTRB(
        ctx.diagramLeftX,
        groupTopY,
        ctx.diagramRightX,
        groupBottomY,
      ),
      fill: const Color(0x00000000),
      stroke: _groupBorder,
      textStyle: ctx.labelStyle,
    ));

    final kindText = _kindLabel(group.kind);
    final kindSize = ctx.measurer.measure(kindText, _groupKindStyle);
    final tabWidth = kindSize.width + _groupLabelTabPaddingX * 2;
    ctx.shapes.add(SceneBox(
      rect: Rect.fromLTWH(
          ctx.diagramLeftX, groupTopY, tabWidth, _groupLabelTabHeight),
      fill: _groupLabelTabFill,
      stroke: _groupBorder,
      label: kindText,
      textStyle: _groupKindStyle,
    ));

    final firstLabel = group.branches.first.label;
    if (firstLabel != null && firstLabel.isNotEmpty) {
      ctx.shapes.add(SceneText(
        offset: Offset(ctx.diagramLeftX + tabWidth + 6,
            groupTopY + (_groupLabelTabHeight - _groupBranchStyle.fontSize!) / 2 - 1),
        text: '[$firstLabel]',
        textStyle: _groupBranchStyle,
      ));
    }

    if (ctx.diagramRightX > ctx.rightmost) ctx.rightmost = ctx.diagramRightX;
    return groupBottomY + _groupGapAfter;
  }

  double _emitRefBox(RefBox ref, double startY, _Ctx ctx) {
    final xs = ref.participants
        .map((a) => ctx.centers[a]!)
        .toList(growable: false);
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final bodySize = ctx.measurer.measure(ref.text, _refBoxBodyStyle);
    final bodyInnerHeight = bodySize.height + _refBoxPaddingY * 2;
    final spanWidth = (maxX - minX) + _refBoxHorizontalPadding * 2;
    final contentWidth = bodySize.width + _refBoxPaddingX * 2;
    final width = math.max(spanWidth, contentWidth);
    final spanCenter = (minX + maxX) / 2;
    final left = spanCenter - width / 2;
    final top = startY + _refBoxVerticalGap;
    final height = _refBoxTabHeight + bodyInnerHeight;
    final rect = Rect.fromLTWH(left, top, width, height);

    ctx.shapes.add(SceneBox(
      rect: rect,
      fill: _refBoxFill,
      stroke: _refBoxBorder,
      textStyle: _refBoxBodyStyle,
    ));

    final tabText = 'ref';
    final tabSize = ctx.measurer.measure(tabText, _refBoxTabStyle);
    final tabWidth = tabSize.width + _refBoxTabPaddingX * 2;
    ctx.shapes.add(SceneBox(
      rect: Rect.fromLTWH(left, top, tabWidth, _refBoxTabHeight),
      fill: _refBoxTabFill,
      stroke: _refBoxBorder,
      label: tabText,
      textStyle: _refBoxTabStyle,
    ));

    ctx.shapes.add(SceneText(
      offset: Offset(
        rect.center.dx - bodySize.width / 2,
        top + _refBoxTabHeight + (bodyInnerHeight - bodySize.height) / 2,
      ),
      text: ref.text,
      textStyle: _refBoxBodyStyle,
    ));

    if (rect.right > ctx.rightmost) ctx.rightmost = rect.right;
    return top + height + _refBoxVerticalGap;
  }

  (double, double) _symbolSize(ParticipantKind kind, Size labelSize) {
    switch (kind) {
      case ParticipantKind.participant:
        final w = (labelSize.width + _actorBoxPaddingX * 2)
            .clamp(_actorMinWidth, double.infinity);
        final h = labelSize.height + _actorBoxPaddingY * 2;
        return (w, h);
      case ParticipantKind.actor:
        final w = math.max(labelSize.width + _actorBoxPaddingX * 2,
            _actorMinWidth);
        final h = _actorIconHeight + labelSize.height + _actorBoxPaddingY;
        return (w, h);
      case ParticipantKind.boundary:
      case ParticipantKind.control:
      case ParticipantKind.entity:
        final w = math.max(labelSize.width + _actorBoxPaddingX * 2,
            _actorMinWidth);
        final h = _smallIconHeight + labelSize.height + _actorBoxPaddingY;
        return (w, h);
      case ParticipantKind.database:
        final w = (labelSize.width + _actorBoxPaddingX * 2)
            .clamp(_actorMinWidth, double.infinity);
        final h =
            labelSize.height + _actorBoxPaddingY * 2 + _databaseCapHeight * 2;
        return (w, h);
      case ParticipantKind.collections:
        final w = (labelSize.width + _actorBoxPaddingX * 2 + _collectionsOffset)
            .clamp(_actorMinWidth + _collectionsOffset, double.infinity);
        final h =
            labelSize.height + _actorBoxPaddingY * 2 + _collectionsOffset;
        return (w, h);
      case ParticipantKind.queue:
        final w = (labelSize.width + _actorBoxPaddingX * 2 + _queueCapWidth * 2)
            .clamp(_actorMinWidth, double.infinity);
        final h = labelSize.height + _actorBoxPaddingY * 2;
        return (w, h);
    }
  }

  String _kindLabel(GroupKind kind) {
    switch (kind) {
      case GroupKind.alt:
        return 'alt';
      case GroupKind.opt:
        return 'opt';
      case GroupKind.loop:
        return 'loop';
      case GroupKind.par:
        return 'par';
    }
  }

  Size _measureNoteText(String text, TextMeasurer measurer,
      [TextStyle style = _noteStyle]) {
    if (!text.contains('\n')) {
      return measurer.measure(text, style);
    }
    final lines = text.split('\n');
    var maxWidth = 0.0;
    var totalHeight = 0.0;
    for (final line in lines) {
      final size = measurer.measure(line.isEmpty ? ' ' : line, style);
      if (size.width > maxWidth) maxWidth = size.width;
      totalHeight += size.height;
    }
    return Size(maxWidth, totalHeight);
  }

  Rect _resolveNoteRect(
      Note note, Size size, double y, Map<String, double> centers) {
    final firstCx = centers[note.participants.first]!;
    switch (note.position) {
      case NotePosition.leftOf:
        return Rect.fromLTWH(firstCx - _noteHorizontalGap - size.width, y,
            size.width, size.height);
      case NotePosition.rightOf:
        return Rect.fromLTWH(
            firstCx + _noteHorizontalGap, y, size.width, size.height);
      case NotePosition.over:
        if (note.participants.length == 1) {
          return Rect.fromLTWH(
              firstCx - size.width / 2, y, size.width, size.height);
        }
        final xs =
            note.participants.map((a) => centers[a]!).toList(growable: false);
        final minX = xs.reduce(math.min);
        final maxX = xs.reduce(math.max);
        final spanCenter = (minX + maxX) / 2;
        final width = math.max(size.width, (maxX - minX) + _notePaddingX * 2);
        return Rect.fromLTWH(
            spanCenter - width / 2, y, width, size.height);
    }
  }

  void _emitStraightMessage(
      Message m, double fx, double tx, double y, _Ctx ctx) {
    final stroke = m.color ?? ctx.defaultArrowColor;
    ctx.shapes.add(SceneLine(
      from: Offset(fx, y),
      to: Offset(tx, y),
      dashed: m.lineStyle == LineStyle.dashed,
      head: m.head,
      headAtFrom: m.direction == MessageDirection.backward,
      label: m.label,
      labelStyle: ctx.labelStyle,
      stroke: stroke,
    ));
  }

  void _emitSelfMessage(Message m, double cx, double y, _Ctx ctx) {
    final dashed = m.lineStyle == LineStyle.dashed;
    final loopRight = cx + _selfMessageWidth;
    final loopBottomY = y + _selfMessageHeight;
    final stroke = m.color ?? ctx.defaultArrowColor;

    ctx.shapes.add(SceneLine(
      from: Offset(cx, y),
      to: Offset(loopRight, y),
      dashed: dashed,
      head: null,
      label: m.label,
      labelStyle: ctx.labelStyle,
      stroke: stroke,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(loopRight, y),
      to: Offset(loopRight, loopBottomY),
      dashed: dashed,
      head: null,
      stroke: stroke,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(loopRight, loopBottomY),
      to: Offset(cx, loopBottomY),
      dashed: dashed,
      head: m.head,
      stroke: stroke,
    ));
  }

  void _emitActivationBar(List<SceneShape> shapes, double cx, double startY,
      double endY, int nestingDepth) {
    if (endY <= startY) return;
    final offset = nestingDepth * _activationNestingOffset;
    shapes.add(SceneBox(
      rect: Rect.fromLTWH(
        cx - _activationBarWidth / 2 + offset,
        startY,
        _activationBarWidth,
        endY - startY,
      ),
      textStyle: _labelStyle,
      fill: const Color(0xFFFFFFFF),
      stroke: const Color(0xFF000000),
    ));
  }
}

class _Ctx {
  final List<SceneShape> shapes;
  final Map<String, double> centers;
  final TextMeasurer measurer;
  final double diagramLeftX;
  final double diagramRightX;
  final double diagramBottomY;
  final TextStyle labelStyle;
  final TextStyle noteStyle;
  final Color defaultArrowColor;
  final Color noteFill;
  final Color noteStroke;
  final Map<String, List<double>> activationStacks = {};
  final Map<String, double> createY = {};
  final Map<String, double> destroyY = {};
  double? lastMessageY;
  double rightmost;

  _Ctx({
    required this.shapes,
    required this.centers,
    required this.measurer,
    required this.diagramLeftX,
    required this.diagramRightX,
    required this.diagramBottomY,
    required this.labelStyle,
    required this.noteStyle,
    required this.defaultArrowColor,
    required this.noteFill,
    required this.noteStroke,
  }) : rightmost = diagramRightX;
}
