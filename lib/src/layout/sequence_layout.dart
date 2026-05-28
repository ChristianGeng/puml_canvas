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
  // PlantUML "transmission duration" annotation (`->(N)` / `(N)<-`): each
  // unit of N translates to this many vertical pixels between the message's
  // tail Y and its head Y. The exact ratio doesn't have to match PlantUML's
  // server output — small constant keeps the diagonal visible without
  // ballooning the diagram height.
  static const _durationPixelsPerUnit = 0.5;
  static const _selfMessageWidth = 30.0;
  static const _selfMessageHeight = 25.0;
  // Horizontal stub length for "found" / "lost" short-form messages
  // (`?->` / `->?`). The arrow extends this distance from the participant
  // lifeline to a notional anonymous endpoint.
  static const _externalShortOffset = 30.0;
  // Padding from the diagram edge for full edge-form arrows (`[->` / `->]`).
  static const _externalEdgePadding = 8.0;
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
  static const _groupBranchTopPadding = 22.0;
  static const _groupGapAfter = 8.0;
  static const _groupElseDividerGap = 16.0;
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
  static const _richLabelNormalStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 12);
  static const _richLabelTitleStyle = TextStyle(
      color: Color(0xFF000000), fontSize: 13, fontWeight: FontWeight.w700);
  static const _richLabelCodeStyle = TextStyle(
      color: Color(0xFF000000), fontSize: 11, fontFamily: 'monospace');
  static const _richLabelLineGap = 2.0;
  static const _richLabelSectionGap = 4.0;
  static const _actorIconHeight = 36.0;
  static const _smallIconHeight = 22.0;
  static const _databaseCapHeight = 6.0;
  static const _collectionsOffset = 6.0;
  static const _queueCapWidth = 8.0;
  // `mainframe <label>` directive — outer UML frame with a folded-corner
  // label tab in the top-left. The tab is a small rectangle whose bottom-
  // right corner is clipped diagonally so it reads as a folded-paper notch.
  static const _mainframeOuterPadding = 12.0;
  static const _mainframeTabPaddingX = 8.0;
  static const _mainframeTabPaddingY = 4.0;
  static const _mainframeTabFoldSize = 8.0;
  static const _mainframeTabGap = 6.0;
  static const _mainframeStroke = Color(0xFF000000);
  static const _mainframeTabStyle =
      TextStyle(color: Color(0xFF000000), fontSize: 12);

  const SequenceLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! SequenceDiagram) {
      throw ArgumentError('SequenceLayout expects SequenceDiagram');
    }

    final allParticipants = diagram.participantsInOrder();
    // `hide unlinked`: drop participants that no Message references as
    // source or target. Activate/Note/RefBox references do NOT count. Empty
    // boxes (whose every member was filtered out) are also dropped so we
    // don't render a phantom rectangle.
    final List<Participant> participants;
    final List<ParticipantBox> boxes;
    if (diagram.hideUnlinked) {
      final visible = diagram.linkedAliases();
      participants = [
        for (final p in allParticipants)
          if (visible.contains(p.alias)) p,
      ];
      boxes = _filterBoxes(diagram.boxes, visible);
    } else {
      participants = allParticipants;
      boxes = diagram.boxes;
    }
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
    final richSectionSizes = <String, List<Size>>{};
    var actorBoxHeight = 0.0;
    for (final p in participants) {
      final Size size;
      if (p.labelSections != null &&
          p.kind == ParticipantKind.participant) {
        final sizes = _richSectionSizes(p.labelSections!, measurer);
        richSectionSizes[p.alias] = sizes;
        size = _richLabelTotalSize(sizes);
      } else {
        size = measurer.measure(p.label, labelStyle);
      }
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

    // Use min/max of actual assigned centers (not declaration order) so groups
    // span the rendered leftmost..rightmost lifeline regardless of ordering.
    final double diagramLeftX;
    final double diagramRightX;
    if (actorCenters.isEmpty) {
      diagramLeftX = _padding;
      diagramRightX = totalWidth - _padding;
    } else {
      var minCx = double.infinity;
      var maxCx = double.negativeInfinity;
      for (final p in participants) {
        final cx = actorCenters[p.alias];
        if (cx == null) continue;
        if (cx < minCx) minCx = cx;
        if (cx > maxCx) maxCx = cx;
      }
      diagramLeftX = minCx - _groupHorizontalPadding;
      diagramRightX = maxCx + _groupHorizontalPadding;
    }

    final totalEventsHeight =
        _planHeight(diagram.events, measurer, noteStyle);

    final shapes = <SceneShape>[];
    final eventShapes = <SceneShape>[];
    final eventBackgrounds = <SceneShape>[];

    final hasBoxes = boxes.isNotEmpty;
    int maxBoxDepth(ParticipantBox b) {
      var d = 1;
      for (final c in b.children) {
        final cd = 1 + maxBoxDepth(c);
        if (cd > d) d = cd;
      }
      return d;
    }

    var boxDepth = 0;
    for (final b in boxes) {
      final d = maxBoxDepth(b);
      if (d > boxDepth) boxDepth = d;
    }
    final boxLabelReserve = hasBoxes
        ? (measurer
                    .measure('Ag', _participantBoxLabelStyle)
                    .height +
                _participantBoxLabelGap * 2) *
            boxDepth
        : 0.0;
    final topActorY = _padding + boxLabelReserve;
    final messagesStartY = topActorY + actorBoxHeight + _messageGap;
    final bottomActorY = messagesStartY + totalEventsHeight;

    final ctx = _Ctx(
      shapes: eventShapes,
      backgrounds: eventBackgrounds,
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
        final tuple = entry.value.removeLast();
        final endY = ctx.destroyY[entry.key] ?? bottomActorY;
        _emitActivationBar(
            eventShapes, cx, tuple.$1, endY, entry.value.length,
            color: tuple.$2);
      }
    }

    final labelLineHeight =
        measurer.measure('Ag', _participantBoxLabelStyle).height;
    void emitBox(ParticipantBox box, int depth) {
      final memberAliases = box.allParticipants().map((p) => p.alias).toList();
      if (memberAliases.isEmpty) {
        for (final child in box.children) {
          emitBox(child, depth);
        }
        return;
      }
      var minLeft = double.infinity;
      var maxRight = double.negativeInfinity;
      for (final alias in memberAliases) {
        final cx = actorCenters[alias];
        final w = actorWidths[alias];
        if (cx == null || w == null) continue;
        final left = cx - w / 2;
        final right = cx + w / 2;
        if (left < minLeft) minLeft = left;
        if (right > maxRight) maxRight = right;
      }
      if (minLeft == double.infinity) {
        for (final child in box.children) {
          emitBox(child, depth);
        }
        return;
      }
      // Each level shrinks the rectangle inward so nested boxes nest visually
      // and each parent's label has room above the child's edge.
      final inset = depth *
          (_participantBoxPaddingX / 2);
      final labelInsetTop = depth *
          (labelLineHeight + _participantBoxLabelGap);
      final boxLeft = minLeft - _participantBoxPaddingX + inset;
      final boxRight = maxRight + _participantBoxPaddingX - inset;
      final boxTop = _padding + labelInsetTop;
      final boxBottom =
          topActorY + actorBoxHeight + _participantBoxPaddingBottom - inset;
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
      for (final child in box.children) {
        emitBox(child, depth + 1);
      }
    }

    for (final box in boxes) {
      emitBox(box, 0);
    }

    // Coloured `alt`/`else` branch fills must sit behind lifelines and
    // message arrows but above the participant frames, so insert them after
    // the participant boxes and before the participants/lifelines.
    shapes.addAll(eventBackgrounds);

    for (final p in participants) {
      final w = actorWidths[p.alias]!;
      final h = actorHeights[p.alias]!;
      final cx = actorCenters[p.alias]!;
      final createY = ctx.createY[p.alias];
      final destroyY = ctx.destroyY[p.alias];
      final topY = createY ?? topActorY;
      final topRect = Rect.fromLTWH(cx - w / 2, topY, w, h);
      final pFill = p.color ?? actorFill;
      if (p.kind == ParticipantKind.participant) {
        final sectionSizes = richSectionSizes[p.alias];
        if (sectionSizes != null && p.labelSections != null) {
          _emitRichParticipant(shapes, topRect, p.labelSections!,
              sectionSizes, pFill, actorStroke, labelStyle, measurer);
          if (destroyY == null) {
            _emitRichParticipant(
                shapes,
                Rect.fromLTWH(cx - w / 2, bottomActorY, w, h),
                p.labelSections!,
                sectionSizes,
                pFill,
                actorStroke,
                labelStyle,
                measurer);
          }
        } else {
          shapes.add(SceneBox(
            rect: topRect,
            label: p.label,
            textStyle: labelStyle,
            fill: pFill,
            stroke: actorStroke,
          ));
          if (destroyY == null) {
            shapes.add(SceneBox(
              rect: Rect.fromLTWH(cx - w / 2, bottomActorY, w, h),
              label: p.label,
              textStyle: labelStyle,
              fill: pFill,
              stroke: actorStroke,
            ));
          }
        }
      } else {
        shapes.add(SceneSymbol(
          rect: topRect,
          label: p.label,
          labelStyle: labelStyle,
          kind: p.kind,
          fill: pFill,
          stroke: actorStroke,
        ));
        if (destroyY == null) {
          shapes.add(SceneSymbol(
            rect: Rect.fromLTWH(cx - w / 2, bottomActorY, w, h),
            label: p.label,
            labelStyle: labelStyle,
            kind: p.kind,
            fill: pFill,
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

    // Shift everything right when notes / labels extend past the left margin
    // so left-of notes don't get clipped off-canvas.
    final leftShift = ctx.leftmost < _padding ? _padding - ctx.leftmost : 0.0;
    if (leftShift > 0) {
      for (var i = 0; i < shapes.length; i++) {
        shapes[i] = _translateShape(shapes[i], leftShift, 0);
      }
    }

    totalWidth = math.max(totalWidth, ctx.rightmost + _padding) + leftShift;
    final diagramBottomY = bottomActorY + actorBoxHeight;
    var totalHeight = diagramBottomY + _padding;

    final mainframeLabel = diagram.mainframeLabel;
    if (mainframeLabel != null) {
      // Measure the label as rich text (inline markup like `**bold**`).
      final labelSize = measurer.measure(
        mainframeLabel.isEmpty ? 'A' : mainframeLabel,
        _mainframeTabStyle,
      );
      final hasLabel = mainframeLabel.isNotEmpty;
      final tabHeight = (hasLabel ? labelSize.height : 0.0) +
          _mainframeTabPaddingY * 2;
      final tabWidth = (hasLabel ? labelSize.width : 0.0) +
          _mainframeTabPaddingX * 2;
      final dx = _mainframeOuterPadding;
      final dy = _mainframeOuterPadding + tabHeight + _mainframeTabGap;
      for (var i = 0; i < shapes.length; i++) {
        shapes[i] = _translateShape(shapes[i], dx, dy);
      }
      totalWidth += dx + _mainframeOuterPadding;
      totalHeight += dy + _mainframeOuterPadding;

      final frameRect = Rect.fromLTWH(
        _mainframeOuterPadding / 2,
        _mainframeOuterPadding / 2,
        totalWidth - _mainframeOuterPadding,
        totalHeight - _mainframeOuterPadding,
      );
      final framed = <SceneShape>[
        SceneBox(
          rect: frameRect,
          fill: const Color(0x00000000),
          stroke: _mainframeStroke,
          textStyle: _mainframeTabStyle,
        ),
        ...shapes,
        // Tab rectangle (top-left, just inside the outer frame).
        SceneBox(
          rect: Rect.fromLTWH(
            frameRect.left,
            frameRect.top,
            tabWidth,
            tabHeight,
          ),
          fill: skin.backgroundColor ?? const Color(0xFFFFFFFF),
          stroke: _mainframeStroke,
          textStyle: _mainframeTabStyle,
        ),
        // Diagonal fold line clipping the bottom-right corner of the tab so
        // the tab reads as a "folded paper" notch. Drawn as a stroke line on
        // top of the (already drawn) tab fill+border.
        SceneLine(
          from: Offset(
            frameRect.left + tabWidth - _mainframeTabFoldSize,
            frameRect.top + tabHeight,
          ),
          to: Offset(
            frameRect.left + tabWidth,
            frameRect.top + tabHeight - _mainframeTabFoldSize,
          ),
          head: null,
          stroke: _mainframeStroke,
        ),
      ];
      if (hasLabel) {
        framed.add(SceneText(
          offset: Offset(
            frameRect.left + _mainframeTabPaddingX,
            frameRect.top + _mainframeTabPaddingY,
          ),
          text: mainframeLabel,
          textStyle: _mainframeTabStyle,
        ));
      }
      shapes
        ..clear()
        ..addAll(framed);
    }

    final innerScene = Scene(
      size: Size(totalWidth, totalHeight),
      shapes: shapes,
      background: skin.backgroundColor,
    );
    return wrapWithDecorations(innerScene, diagram.decorations, measurer);
  }

  /// Returns a copy of [boxes] with every participant whose alias is not in
  /// [visible] dropped. A box whose `participants` list AND nested children
  /// all become empty is omitted entirely so we don't render an empty
  /// rectangle when `hide unlinked` filters out every box member.
  List<ParticipantBox> _filterBoxes(
    List<ParticipantBox> boxes,
    Set<String> visible,
  ) {
    final out = <ParticipantBox>[];
    for (final b in boxes) {
      final filteredParticipants = [
        for (final p in b.participants)
          if (visible.contains(p.alias)) p,
      ];
      final filteredChildren = _filterBoxes(b.children, visible);
      if (filteredParticipants.isEmpty && filteredChildren.isEmpty) {
        continue;
      }
      out.add(ParticipantBox(
        label: b.label,
        color: b.color,
        participants: filteredParticipants,
        children: filteredChildren,
      ));
    }
    return out;
  }

  SceneShape _translateShape(SceneShape s, double dx, double dy) {
    if (s is SceneBox) {
      return SceneBox(
        rect: s.rect.shift(Offset(dx, dy)),
        fill: s.fill,
        stroke: s.stroke,
        strokeWidth: s.strokeWidth,
        label: s.label,
        textStyle: s.textStyle,
      );
    }
    if (s is SceneLine) {
      return SceneLine(
        from: s.from + Offset(dx, dy),
        to: s.to + Offset(dx, dy),
        dashed: s.dashed,
        head: s.head,
        headAtFrom: s.headAtFrom,
        stroke: s.stroke,
        strokeWidth: s.strokeWidth,
        label: s.label,
        labelStyle: s.labelStyle,
      );
    }
    if (s is SceneText) {
      return SceneText(
        offset: s.offset + Offset(dx, dy),
        text: s.text,
        textStyle: s.textStyle,
        maxWidth: s.maxWidth,
      );
    }
    if (s is SceneNote) {
      return SceneNote(
        rect: s.rect.shift(Offset(dx, dy)),
        text: s.text,
        textStyle: s.textStyle,
        fill: s.fill,
        stroke: s.stroke,
      );
    }
    if (s is SceneSymbol) {
      return SceneSymbol(
        rect: s.rect.shift(Offset(dx, dy)),
        label: s.label,
        labelStyle: s.labelStyle,
        kind: s.kind,
        fill: s.fill,
        stroke: s.stroke,
      );
    }
    return s;
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

  void _emitRichParticipant(
      List<SceneShape> shapes,
      Rect rect,
      List<ParticipantLabelSection> sections,
      List<Size> sectionSizes,
      Color fill,
      Color stroke,
      TextStyle fallbackStyle,
      TextMeasurer measurer) {
    shapes.add(SceneBox(
      rect: rect,
      textStyle: fallbackStyle,
      fill: fill,
      stroke: stroke,
    ));
    // Section block is centered vertically inside the rect.
    final total = _richLabelTotalSize(sectionSizes);
    var y = rect.top + (rect.height - total.height) / 2;
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      var lineY = y;
      for (var j = 0; j < section.lines.length; j++) {
        final line = section.lines[j];
        final style = _richLabelStyle(line.style);
        final text = line.text.isEmpty ? ' ' : line.text;
        final size = measurer.measure(text, style);
        shapes.add(SceneText(
          offset: Offset(rect.center.dx - size.width / 2, lineY),
          text: text,
          textStyle: style,
        ));
        lineY += size.height;
        if (j < section.lines.length - 1) lineY += _richLabelLineGap;
      }
      y += sectionSizes[i].height;
      if (i < sections.length - 1) {
        final dividerY = y + _richLabelSectionGap;
        shapes.add(SceneLine(
          from: Offset(rect.left, dividerY),
          to: Offset(rect.right, dividerY),
          head: null,
          stroke: stroke,
        ));
        y += _richLabelSectionGap * 2;
      }
    }
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
        if (event.from == event.to) {
          final labelH = event.label == null || event.label!.isEmpty
              ? 0.0
              : _measureMultilineText(event.label!, measurer, _labelStyle)
                  .height;
          return _messageGap + _selfMessageHeight + labelH;
        }
        // Synchronized messages (`& A -> B`) share their start Y with the
        // previous event, so their nominal vertical contribution is the
        // INCREMENT over the previous message's advance. The actual layout
        // pass handles the rewind precisely; for planning purposes we model
        // a sync'd message as consuming only its duration delta so the
        // overall height estimate stays conservative.
        final durationPx = event.duration == null
            ? 0.0
            : event.duration! * _durationPixelsPerUnit;
        if (event.synchronized) {
          return durationPx;
        }
        return _messageGap + durationPx;
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
          // `&` parallel/sync marker: rewind to the previous message's tail Y
          // so this message shares the same start coordinate. The group's
          // overall Y advance becomes `max(previousAdvance, thisAdvance)` so
          // subsequent events clear the tallest slant in the group.
          double rewoundBy = 0.0;
          if (event.synchronized && ctx.previousMessageStartY != null) {
            rewoundBy = y - ctx.previousMessageStartY!;
            y = ctx.previousMessageStartY!;
          }
          final messageStartY = y;
          if (event.fromExternal == null &&
              event.toExternal == null &&
              event.from == event.to) {
            final labelH = event.label == null || event.label!.isEmpty
                ? 0.0
                : _measureMultilineText(event.label!, ctx.measurer,
                        ctx.labelStyle)
                    .height;
            if (!event.hidden) {
              _emitSelfMessage(event, ctx.centers[event.from]!, y, ctx);
              final cx = ctx.centers[event.from]!;
              final loopRight = cx + _selfMessageWidth;
              if (loopRight > ctx.rightmost) ctx.rightmost = loopRight;
            }
            final advance = _messageGap + _selfMessageHeight + labelH;
            y += advance;
            ctx.previousMessageAdvance = advance;
          } else {
            if (!event.hidden) {
              // Resolve X coordinates, substituting computed values for any
              // anonymous "found" / "lost" endpoints. The fixed-participant
              // endpoint anchors the calculation for short-form arrows.
              final double fx;
              final double tx;
              if (event.fromExternal != null) {
                // Source is anonymous; target must be a real participant.
                final targetX = ctx.centers[event.to]!;
                fx = event.fromExternal == MessageExternal.fromEdge
                    ? ctx.diagramLeftX - _externalEdgePadding
                    : targetX - _externalShortOffset;
                tx = targetX;
              } else if (event.toExternal != null) {
                // Target is anonymous; source must be a real participant.
                final sourceX = ctx.centers[event.from]!;
                fx = sourceX;
                tx = event.toExternal == MessageExternal.toEdge
                    ? ctx.diagramRightX + _externalEdgePadding
                    : sourceX + _externalShortOffset;
              } else {
                fx = ctx.centers[event.from]!;
                tx = ctx.centers[event.to]!;
              }
              _emitStraightMessage(event, fx, tx, y, ctx);
              if (fx < ctx.leftmost) ctx.leftmost = fx;
              if (tx > ctx.rightmost) ctx.rightmost = tx;
            }
            // Per-message duration adds extra vertical space so the slanted
            // head endpoint doesn't overlap the next event.
            final durationPx = event.duration == null
                ? 0.0
                : event.duration! * _durationPixelsPerUnit;
            final advance = _messageGap + durationPx;
            y += advance;
            ctx.previousMessageAdvance = advance;
          }
          // When this message synchronized onto the previous one, the group's
          // effective advance is the max of all member messages' advances.
          if (event.synchronized) {
            final groupAdvance = math.max(rewoundBy, ctx.previousMessageAdvance);
            if (groupAdvance > ctx.previousMessageAdvance) {
              y += groupAdvance - ctx.previousMessageAdvance;
            }
            ctx.previousMessageAdvance = groupAdvance;
          } else {
            ctx.previousMessageStartY = messageStartY;
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
            fill: event.color ?? ctx.noteFill,
            stroke: ctx.noteStroke,
          ));
          if (rect.right > ctx.rightmost) ctx.rightmost = rect.right;
          if (rect.left < ctx.leftmost) ctx.leftmost = rect.left;
          y += boxSize.height + _noteVerticalGap * 2;
        case RefBox():
          y = _emitRefBox(event, y, ctx);
        case Activate():
          final stack = ctx.activationStacks
              .putIfAbsent(event.participant, () => <(double, Color?)>[]);
          stack.add((ctx.lastMessageY ?? y, event.color));
        case Deactivate():
          final stack = ctx.activationStacks[event.participant];
          if (stack != null && stack.isNotEmpty) {
            final entry = stack.removeLast();
            final endY = ctx.lastMessageY ?? y;
            _emitActivationBar(ctx.shapes,
                ctx.centers[event.participant]!,
                entry.$1, endY, stack.length,
                color: entry.$2);
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

    // Track each branch's vertical span so coloured fills can be emitted into
    // `ctx.backgrounds` after layout completes. Spans extend from the bottom
    // of the previous separator (or the group's top border for branch 0) to
    // the top of the next separator (or the group's bottom border for the
    // last branch).
    final branchSpans = <(double, double, Color?)>[];
    var branchSpanStart = groupTopY;
    for (var i = 0; i < group.branches.length; i++) {
      final branch = group.branches[i];
      if (i > 0) {
        final dividerY = contentY + _groupElseDividerGap;
        // Close out the previous branch's span at the divider.
        branchSpans
            .add((branchSpanStart, dividerY, group.branches[i - 1].bodyColor));
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
        branchSpanStart = dividerY;
      }
      contentY += _emitEvents(branch.events, contentY, ctx);
    }

    final groupBottomY = contentY + _groupPaddingBottom;
    // Close out the last branch's span at the group's bottom border.
    branchSpans
        .add((branchSpanStart, groupBottomY, group.branches.last.bodyColor));

    // Emit per-branch background fills behind lifelines. Skipping branches
    // without a colour preserves the previous transparent default.
    for (final span in branchSpans) {
      final colour = span.$3;
      if (colour == null) continue;
      ctx.backgrounds.add(SceneBox(
        rect: Rect.fromLTRB(
          ctx.diagramLeftX,
          span.$1,
          ctx.diagramRightX,
          span.$2,
        ),
        fill: colour,
        stroke: const Color(0x00000000),
        strokeWidth: 0,
        textStyle: ctx.labelStyle,
      ));
    }

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
      fill: group.tabColor ?? _groupLabelTabFill,
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

  TextStyle _richLabelStyle(ParticipantLabelStyle style) {
    switch (style) {
      case ParticipantLabelStyle.title:
        return _richLabelTitleStyle;
      case ParticipantLabelStyle.code:
        return _richLabelCodeStyle;
      case ParticipantLabelStyle.normal:
        return _richLabelNormalStyle;
    }
  }

  // Per-section dimensions (max line width, sum of line heights with gaps).
  List<Size> _richSectionSizes(
      List<ParticipantLabelSection> sections, TextMeasurer measurer) {
    return [
      for (final section in sections)
        () {
          var maxW = 0.0;
          var totalH = 0.0;
          for (var i = 0; i < section.lines.length; i++) {
            final line = section.lines[i];
            final text = line.text.isEmpty ? ' ' : line.text;
            final s = measurer.measure(text, _richLabelStyle(line.style));
            if (s.width > maxW) maxW = s.width;
            totalH += s.height;
            if (i < section.lines.length - 1) totalH += _richLabelLineGap;
          }
          return Size(maxW, totalH);
        }(),
    ];
  }

  Size _richLabelTotalSize(List<Size> sectionSizes) {
    var w = 0.0;
    var h = 0.0;
    for (var i = 0; i < sectionSizes.length; i++) {
      final s = sectionSizes[i];
      if (s.width > w) w = s.width;
      h += s.height;
      if (i < sectionSizes.length - 1) h += _richLabelSectionGap * 2;
    }
    return Size(w, h);
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
      case GroupKind.group:
        return 'group';
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
    // `note right` / `note left` without `of X` defaults to the leftmost
    // (or rightmost) participant so the note has somewhere to anchor.
    final String anchor;
    if (note.participants.isEmpty) {
      if (centers.isEmpty) {
        return Rect.fromLTWH(_padding, y, size.width, size.height);
      }
      switch (note.position) {
        case NotePosition.leftOf:
          anchor = centers.entries
              .reduce((a, b) => a.value <= b.value ? a : b)
              .key;
        case NotePosition.rightOf:
          anchor = centers.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;
        case NotePosition.over:
          anchor = centers.entries.first.key;
      }
    } else {
      anchor = note.participants.first;
    }
    final firstCx = centers[anchor]!;
    switch (note.position) {
      case NotePosition.leftOf:
        return Rect.fromLTWH(firstCx - _noteHorizontalGap - size.width, y,
            size.width, size.height);
      case NotePosition.rightOf:
        return Rect.fromLTWH(
            firstCx + _noteHorizontalGap, y, size.width, size.height);
      case NotePosition.over:
        if (note.participants.length <= 1) {
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
    final bidirectional = m.direction == MessageDirection.bidirectional;
    // PlantUML `->(N)` / `(N)<-` transmission-duration annotation: the head
    // endpoint sits BELOW the tail endpoint by `N * _durationPixelsPerUnit`,
    // drawing the arrow as a slanted/diagonal line. The slant direction
    // mirrors the arrow direction: forward arrows go down-and-right (head
    // ends at the right), backward arrows go down-and-left (head ends at the
    // left). Tail Y always stays at `y`; head Y is offset by `durationOffset`.
    final isBackward = m.direction == MessageDirection.backward;
    final durationOffset = m.duration == null
        ? 0.0
        : m.duration! * _durationPixelsPerUnit;
    final fromY = isBackward ? y + durationOffset : y;
    final toY = isBackward ? y : y + durationOffset;
    ctx.shapes.add(SceneLine(
      from: Offset(fx, fromY),
      to: Offset(tx, toY),
      dashed: m.lineStyle == LineStyle.dashed,
      head: m.head,
      headAtFrom: isBackward,
      label: m.label,
      labelStyle: ctx.labelStyle,
      stroke: stroke,
    ));
    if (bidirectional) {
      // Tail-only stub so the renderer draws an arrowhead at the FROM side
      // without duplicating the body stroke. The tail-side shape mirrors the
      // explicit `tailDecoration` when present (`o<->o`, `x<->x`); otherwise
      // it defaults to the filled triangle that matches plain `<->`. The
      // asymmetric form `<->o` (no leading `o`) keeps a filled tail and an
      // open-circle head.
      final tailHead = m.tailDecoration == EndpointDecoration.openCircle
          ? ArrowHead.openCircle
          : m.tailDecoration == EndpointDecoration.cross
              ? ArrowHead.cross
              : ArrowHead.filled;
      final dx = (tx - fx).abs();
      final delta = dx > 0.01 ? (tx > fx ? 0.5 : -0.5) : 0.0;
      ctx.shapes.add(SceneLine(
        from: Offset(fx + delta, fromY),
        to: Offset(fx, fromY),
        dashed: false,
        head: tailHead,
        headAtFrom: false,
        stroke: stroke,
      ));
    }
    // Tail decoration (`o->`, `x->`, `x->o`, `o->o`). For bidirectional
    // arrows the head shape is already mirrored above; the tail decoration
    // would draw an identical shape on top, so skip it. We draw the
    // decoration by emitting a tiny zero-stroke SceneLine whose "head" is
    // the decoration shape — the line itself is collapsed so it doesn't
    // double the main body stroke, but the head call still draws.
    if (!bidirectional && m.tailDecoration != null) {
      // Tail point: the endpoint OPPOSITE the head triangle.
      final tailX = isBackward ? tx : fx;
      final headX = isBackward ? fx : tx;
      final tailPointY = isBackward ? toY : fromY;
      // Tiny offset toward the head — the renderer computes the head angle
      // from (from → to), so we need `from` slightly toward the head and
      // `to` at the tail so the decoration sits exactly on the tail point.
      final dir = headX >= tailX ? 1.0 : -1.0;
      final decoHead = m.tailDecoration == EndpointDecoration.openCircle
          ? ArrowHead.openCircle
          : ArrowHead.cross;
      ctx.shapes.add(SceneLine(
        from: Offset(tailX + dir * 0.5, tailPointY),
        to: Offset(tailX, tailPointY),
        dashed: false,
        head: decoHead,
        headAtFrom: false,
        stroke: stroke,
      ));
    }
  }

  void _emitSelfMessage(Message m, double cx, double y, _Ctx ctx) {
    final dashed = m.lineStyle == LineStyle.dashed;
    final label = m.label;
    final labelSize = label == null || label.isEmpty
        ? Size.zero
        : _measureMultilineText(label, ctx.measurer, ctx.labelStyle);
    final loopTop = y + labelSize.height;
    final mirrored = m.direction == MessageDirection.backward;
    final loopFar = mirrored ? cx - _selfMessageWidth : cx + _selfMessageWidth;
    final loopBottomY = loopTop + _selfMessageHeight;
    final stroke = m.color ?? ctx.defaultArrowColor;

    if (label != null && label.isNotEmpty) {
      final lx = mirrored
          ? loopFar - 6 - labelSize.width
          : loopFar + 6;
      ctx.shapes.add(SceneText(
        offset: Offset(lx, y),
        text: label,
        textStyle: ctx.labelStyle,
      ));
    }
    ctx.shapes.add(SceneLine(
      from: Offset(cx, loopTop),
      to: Offset(loopFar, loopTop),
      dashed: dashed,
      head: null,
      stroke: stroke,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(loopFar, loopTop),
      to: Offset(loopFar, loopBottomY),
      dashed: dashed,
      head: null,
      stroke: stroke,
    ));
    ctx.shapes.add(SceneLine(
      from: Offset(loopFar, loopBottomY),
      to: Offset(cx, loopBottomY),
      dashed: dashed,
      head: m.head,
      stroke: stroke,
    ));
  }

  Size _measureMultilineText(String text, TextMeasurer measurer, TextStyle s) {
    var width = 0.0;
    var height = 0.0;
    for (final line in text.split('\n')) {
      final size = measurer.measure(line.isEmpty ? ' ' : line, s);
      if (size.width > width) width = size.width;
      height += size.height;
    }
    return Size(width, height);
  }

  void _emitActivationBar(List<SceneShape> shapes, double cx, double startY,
      double endY, int nestingDepth,
      {Color? color}) {
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
      fill: color ?? const Color(0xFFFFFFFF),
      stroke: const Color(0xFF000000),
    ));
  }
}

class _Ctx {
  final List<SceneShape> shapes;
  // Background fills (e.g. coloured `alt`/`else` branch bodies) that must
  // render behind lifelines and message arrows. Drained into `shapes` before
  // participants/lifelines are added.
  final List<SceneShape> backgrounds;
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
  final Map<String, List<(double, Color?)>> activationStacks = {};
  final Map<String, double> createY = {};
  final Map<String, double> destroyY = {};
  double? lastMessageY;
  // Y coordinate of the most-recently-emitted message's TAIL endpoint. Used
  // by the `&` parallel/sync marker so a `synchronized` message rewinds its
  // start to share the same tail Y as the immediately preceding message.
  double? previousMessageStartY;
  // Y delta consumed by the most-recently-emitted message (`_messageGap` plus
  // any diagonal duration offset). When a synchronized message rewinds, the
  // group's overall Y advance must be `max(previousAdvance, currentAdvance)`
  // so the next event clears the tallest slant in the group.
  double previousMessageAdvance = 0.0;
  double rightmost;
  double leftmost;

  _Ctx({
    required this.shapes,
    required this.backgrounds,
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
  })  : rightmost = diagramRightX,
        leftmost = diagramLeftX;
}
