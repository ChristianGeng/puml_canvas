import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/diagram.dart';
import '../graph_layout/edge_routing.dart';
import '../graph_layout/graph.dart';
import '../graph_layout/layered_layout.dart';
import 'decoration_wrapper.dart';
import 'layout.dart';
import 'scene.dart';
import 'text_measurer.dart';

class ClassLayout implements DiagramLayout {
  static const _padding = 24.0;
  static const _classPaddingX = 12.0;
  static const _classHeaderPaddingY = 6.0;
  static const _memberPaddingY = 4.0;
  static const _memberLineGap = 2.0;
  static const _stereotypeGap = 2.0;
  static const _colGap = 60.0;
  static const _rowGap = 60.0;
  static const _minClassWidth = 90.0;
  static const _headerStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
  static const _abstractHeaderStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    fontStyle: FontStyle.italic,
  );
  static const _instanceHeaderStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
  );
  static const _stereotypeStyle = TextStyle(
    color: Color(0xFF555555),
    fontSize: 10,
    fontStyle: FontStyle.italic,
  );
  static const _memberStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
  );
  static const _abstractMemberStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
    fontStyle: FontStyle.italic,
  );
  static const _staticMemberStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
    decoration: TextDecoration.underline,
  );
  static const _enumValueStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
  );
  static const _relationshipLabelStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 10,
  );
  static const _multiplicityStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 10,
  );
  static const _noteTextStyle = TextStyle(
    color: Color(0xFF000000),
    fontSize: 11,
  );

  static const _classFill = Color(0xFFFFFFCC);
  static const _classStroke = Color(0xFF000000);
  static const _headerFill = Color(0xFFFFFFBB);

  static const _publicColor = Color(0xFF1B7F1B);
  static const _privateColor = Color(0xFFC62828);
  static const _protectedColor = Color(0xFFEF6C00);
  static const _packageColor = Color(0xFF6A1B9A);
  static const _edgeRouter = OrthogonalEdgeRouter();

  const ClassLayout();

  @override
  Scene layout(Diagram diagram, TextMeasurer measurer) {
    if (diagram is! ClassDiagram) {
      throw ArgumentError('ClassLayout expects ClassDiagram');
    }

    if (diagram.classes.isEmpty && diagram.freeNotes.isEmpty) {
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

    final boxes = <String, _ClassBox>{};
    for (final c in diagram.classes) {
      boxes[c.name] = _measureClass(c, measurer);
    }

    final graphResult = const LayeredGraphLayout(
      options: LayeredLayoutOptions(
        padding: _padding,
        nodeGap: _colGap,
        layerGap: _rowGap,
      ),
    ).layout(LayoutGraph(
      nodes: [
        for (final box in boxes.values)
          LayoutNode(
            id: box.decl.name,
            size: Size(box.width, box.height),
          ),
      ],
      edges: [
        for (final rel in diagram.relationships)
          if (boxes.containsKey(rel.from) && boxes.containsKey(rel.to))
            LayoutEdge(
              from: rel.from,
              to: rel.to,
              directed: rel.kind != RelationshipKind.association &&
                  rel.kind != RelationshipKind.link,
            ),
      ],
    ));
    for (final entry in graphResult.nodeRects.entries) {
      boxes[entry.key]!.rect = entry.value;
    }

    var width = 0.0;
    var height = 0.0;
    for (final b in boxes.values) {
      if (b.rect.right > width) width = b.rect.right;
      if (b.rect.bottom > height) height = b.rect.bottom;
    }

    final noteRects = <String, Rect>{};
    if (diagram.freeNotes.isNotEmpty) {
      var nx = _padding;
      var ny = (height > 0 ? height + _rowGap : _padding);
      var rowMaxHeight = 0.0;
      for (final note in diagram.freeNotes) {
        final size = _measureNote(note.text, measurer);
        if (nx > _padding && nx + size.width > width) {
          nx = _padding;
          ny += rowMaxHeight + _rowGap;
          rowMaxHeight = 0.0;
        }
        noteRects[note.alias] = Rect.fromLTWH(nx, ny, size.width, size.height);
        nx += size.width + _colGap;
        if (size.height > rowMaxHeight) rowMaxHeight = size.height;
      }
      for (final r in noteRects.values) {
        if (r.right > width) width = r.right;
        if (r.bottom > height) height = r.bottom;
      }
    }

    width += _padding;
    height += _padding;

    final shapes = <SceneShape>[];

    for (final box in boxes.values) {
      _emitClassBox(shapes, box);
    }

    final notesByAlias = <String, FreeNote>{
      for (final n in diagram.freeNotes) n.alias: n,
    };
    final relationGroupSizes =
        _relationGroupSizes(diagram.relationships, boxes);
    final relationGroupSeen = <String, int>{};
    final obstacleRects = boxes.values.map((box) => box.rect).toList();

    for (final rel in diagram.relationships) {
      final a = boxes[rel.from];
      final b = boxes[rel.to];
      if (a != null && b != null) {
        final groupKey = _relationGroupKey(rel.from, rel.to);
        final groupSize = relationGroupSizes[groupKey] ?? 1;
        final groupIndex = relationGroupSeen[groupKey] ?? 0;
        relationGroupSeen[groupKey] = groupIndex + 1;
        _emitRelationship(
          shapes,
          rel,
          a,
          b,
          measurer,
          laneOffset: _laneOffset(groupIndex, groupSize),
          obstacles: [
            for (final rect in obstacleRects)
              if (rect != a.rect && rect != b.rect) rect,
          ],
        );
        continue;
      }
      final fromIsNote = notesByAlias.containsKey(rel.from);
      final toIsNote = notesByAlias.containsKey(rel.to);
      if (fromIsNote || toIsNote) {
        final fromRect = a?.rect ?? noteRects[rel.from];
        final toRect = b?.rect ?? noteRects[rel.to];
        if (fromRect != null && toRect != null) {
          _emitNoteConnector(shapes, fromRect, toRect);
        }
      }
    }

    for (final note in diagram.freeNotes) {
      final rect = noteRects[note.alias];
      if (rect == null) continue;
      shapes.add(SceneNote(
        rect: rect,
        text: note.text,
        textStyle: _noteTextStyle,
      ));
      final attached = note.attachedTo;
      if (attached != null) {
        final target = boxes[attached];
        if (target != null) {
          _emitNoteConnector(shapes, rect, target.rect);
        }
      }
    }

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

  Size _measureNote(String text, TextMeasurer measurer) {
    final lines = text.split('\n');
    var maxW = 0.0;
    var sumH = 0.0;
    for (final l in lines) {
      final s = measurer.measure(l.isEmpty ? ' ' : l, _noteTextStyle);
      if (s.width > maxW) maxW = s.width;
      sumH += s.height;
    }
    return Size(maxW + 16, sumH + 12);
  }

  void _emitNoteConnector(List<SceneShape> shapes, Rect a, Rect b) {
    final fromEdge = _edgePoint(a, b.center);
    final toEdge = _edgePoint(b, a.center);
    shapes.add(SceneLine(
      from: fromEdge,
      to: toEdge,
      dashed: true,
      head: null,
      stroke: const Color(0xFF000000),
      strokeWidth: 1.0,
    ));
  }

  _ClassBox _measureClass(ClassDecl c, TextMeasurer measurer) {
    TextStyle headerStyle;
    if (c.kind == ClassKind.abstractClass) {
      headerStyle = _abstractHeaderStyle;
    } else if (c.kind == ClassKind.object_ || c.kind == ClassKind.map_) {
      headerStyle = _instanceHeaderStyle;
    } else {
      headerStyle = _headerStyle;
    }
    final baseName = c.generics == null ? c.name : '${c.name}<${c.generics}>';
    final headerText =
        c.instanceOf == null ? baseName : '$baseName : ${c.instanceOf}';
    final nameSize = measurer.measure(headerText, headerStyle);
    final stereotype =
        c.stereotype != null ? '<<${c.stereotype}>>' : _stereotype(c.kind);
    final stereotypeSize = stereotype == null
        ? Size.zero
        : measurer.measure(stereotype, _stereotypeStyle);
    var maxMemberWidth = 0.0;
    var memberHeightSum = 0.0;
    final memberLines = <_MemberLine>[];
    for (final m in c.members) {
      final line = _renderMember(m, measurer);
      memberLines.add(line);
      if (line.width > maxMemberWidth) maxMemberWidth = line.width;
      memberHeightSum += line.height + _memberLineGap;
    }
    final headerHeight = _classHeaderPaddingY +
        (stereotype != null ? stereotypeSize.height + _stereotypeGap : 0) +
        nameSize.height +
        _classHeaderPaddingY;
    final memberAreaHeight =
        memberLines.isEmpty ? 0.0 : memberHeightSum + _memberPaddingY * 2;
    final width = math.max(
      _minClassWidth,
      math.max(
            math.max(nameSize.width, stereotypeSize.width),
            maxMemberWidth,
          ) +
          _classPaddingX * 2,
    );
    final totalHeight = headerHeight + memberAreaHeight;
    return _ClassBox(
      decl: c,
      headerStyle: headerStyle,
      headerText: headerText,
      stereotype: stereotype,
      stereotypeSize: stereotypeSize,
      nameSize: nameSize,
      memberLines: memberLines,
      headerHeight: headerHeight,
      width: width,
      height: totalHeight,
    );
  }

  _MemberLine _renderMember(ClassMember m, TextMeasurer measurer) {
    switch (m) {
      case Field():
        final visChar = _visibilityChar(m.visibility);
        final visColor = _visibilityColor(m.visibility);
        final requiredPrefix = m.required ? '* ' : '';
        final stereotypeSuffix =
            m.stereotype == null ? '' : ' <<${m.stereotype}>>';
        final core = m.type == null ? m.name : '${m.name}: ${m.type}';
        final body = '$requiredPrefix$core$stereotypeSuffix';
        final style = m.isStatic ? _staticMemberStyle : _memberStyle;
        final visSize =
            measurer.measure(visChar, style.copyWith(color: visColor));
        final bodySize = measurer.measure(' $body', style);
        return _MemberLine(
          visibilityChar: visChar,
          visibilityColor: visColor,
          body: ' $body',
          bodyStyle: style,
          width: visSize.width + bodySize.width,
          height: math.max(visSize.height, bodySize.height),
          visWidth: visSize.width,
        );
      case Method():
        final visChar = _visibilityChar(m.visibility);
        final visColor = _visibilityColor(m.visibility);
        final body = m.signature ?? '${m.name}()';
        final suffix = m.returnType == null ? '' : ': ${m.returnType}';
        final fullBody = ' $body$suffix';
        TextStyle style;
        if (m.isAbstract) {
          style = _abstractMemberStyle;
        } else if (m.isStatic) {
          style = _staticMemberStyle;
        } else {
          style = _memberStyle;
        }
        final visSize =
            measurer.measure(visChar, style.copyWith(color: visColor));
        final bodySize = measurer.measure(fullBody, style);
        return _MemberLine(
          visibilityChar: visChar,
          visibilityColor: visColor,
          body: fullBody,
          bodyStyle: style,
          width: visSize.width + bodySize.width,
          height: math.max(visSize.height, bodySize.height),
          visWidth: visSize.width,
        );
      case EnumValue():
        final size = measurer.measure(m.name, _enumValueStyle);
        return _MemberLine(
          visibilityChar: '',
          visibilityColor: const Color(0xFF000000),
          body: m.name,
          bodyStyle: _enumValueStyle,
          width: size.width,
          height: size.height,
          visWidth: 0.0,
        );
      case MemberDivider():
        return _MemberLine(
          visibilityChar: '',
          visibilityColor: const Color(0xFF000000),
          body: '',
          bodyStyle: _memberStyle,
          width: 0.0,
          height: 6.0,
          visWidth: 0.0,
          divider: m.kind,
        );
      case Attribute():
        final sep = m.isMap ? ' => ' : ' = ';
        final body = '${m.name}$sep${m.value}';
        final size = measurer.measure(body, _memberStyle);
        return _MemberLine(
          visibilityChar: '',
          visibilityColor: const Color(0xFF000000),
          body: body,
          bodyStyle: _memberStyle,
          width: size.width,
          height: size.height,
          visWidth: 0.0,
        );
    }
  }

  void _emitClassBox(List<SceneShape> shapes, _ClassBox box) {
    final rect = box.rect;
    shapes.add(SceneBox(
      rect: rect,
      fill: _classFill,
      stroke: _classStroke,
      textStyle: box.headerStyle,
    ));
    final headerRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      box.headerHeight,
    );
    shapes.add(SceneBox(
      rect: headerRect,
      fill: _headerFill,
      stroke: _classStroke,
      textStyle: box.headerStyle,
    ));
    var ty = rect.top + _classHeaderPaddingY;
    if (box.stereotype != null) {
      shapes.add(SceneText(
        offset: Offset(
          rect.center.dx - box.stereotypeSize.width / 2,
          ty,
        ),
        text: box.stereotype!,
        textStyle: _stereotypeStyle,
      ));
      ty += box.stereotypeSize.height + _stereotypeGap;
    }
    shapes.add(SceneText(
      offset: Offset(
        rect.center.dx - box.nameSize.width / 2,
        ty,
      ),
      text: box.headerText,
      textStyle: box.headerStyle,
    ));

    if (box.memberLines.isEmpty) return;
    var my = rect.top + box.headerHeight + _memberPaddingY;
    for (final line in box.memberLines) {
      if (line.divider != null) {
        final lineY = my + line.height / 2;
        shapes.add(SceneLine(
          from: Offset(rect.left + 4, lineY),
          to: Offset(rect.right - 4, lineY),
          dashed: line.divider == DividerKind.dashed,
          head: null,
          stroke: _classStroke,
          strokeWidth: line.divider == DividerKind.doubleLine ? 1.5 : 1.0,
        ));
        my += line.height + _memberLineGap;
        continue;
      }
      final x = rect.left + _classPaddingX;
      if (line.visibilityChar.isNotEmpty) {
        shapes.add(SceneText(
          offset: Offset(x, my),
          text: line.visibilityChar,
          textStyle: line.bodyStyle.copyWith(color: line.visibilityColor),
        ));
      }
      shapes.add(SceneText(
        offset: Offset(x + line.visWidth, my),
        text: line.body,
        textStyle: line.bodyStyle,
      ));
      my += line.height + _memberLineGap;
    }
  }

  Map<String, int> _relationGroupSizes(
    List<Relationship> relationships,
    Map<String, _ClassBox> boxes,
  ) {
    final result = <String, int>{};
    for (final rel in relationships) {
      if (!boxes.containsKey(rel.from) || !boxes.containsKey(rel.to)) {
        continue;
      }
      final key = _relationGroupKey(rel.from, rel.to);
      result[key] = (result[key] ?? 0) + 1;
    }
    return result;
  }

  String _relationGroupKey(String a, String b) {
    return a.compareTo(b) <= 0 ? '$a\u0000$b' : '$b\u0000$a';
  }

  double _laneOffset(int index, int total) {
    if (total <= 1) return 0.0;
    return (index - (total - 1) / 2) * 14.0;
  }

  void _emitRelationship(
    List<SceneShape> shapes,
    Relationship rel,
    _ClassBox a,
    _ClassBox b,
    TextMeasurer measurer, {
    required double laneOffset,
    required List<Rect> obstacles,
  }) {
    final path = _edgeRouter.route(
      a.rect,
      b.rect,
      obstacles: obstacles,
      laneOffset: laneOffset,
    );
    final fromEdge = path.first;
    final toEdge = path.last;
    final hasCrow = rel.fromCrowFoot != null || rel.toCrowFoot != null;
    final style = _styleFor(rel.kind);
    _emitEdgePath(shapes, path, style, suppressHead: hasCrow);
    if (rel.fromCrowFoot != null) {
      final next = path.length > 1 ? path[1] : toEdge;
      final angle = math.atan2(next.dy - fromEdge.dy, next.dx - fromEdge.dx);
      shapes.add(SceneCrowFoot(
        position: fromEdge,
        angle: angle,
        kind: rel.fromCrowFoot!,
      ));
    }
    if (rel.toCrowFoot != null) {
      final prev = path.length > 1 ? path[path.length - 2] : fromEdge;
      final angle = math.atan2(prev.dy - toEdge.dy, prev.dx - toEdge.dx);
      shapes.add(SceneCrowFoot(
        position: toEdge,
        angle: angle,
        kind: rel.toCrowFoot!,
      ));
    }
    if (rel.label != null && rel.label!.isNotEmpty) {
      final mid = _pathMidpoint(path);
      final size = measurer.measure(rel.label!, _relationshipLabelStyle);
      shapes.add(SceneText(
        offset: Offset(mid.dx - size.width / 2, mid.dy - size.height - 2),
        text: rel.label!,
        textStyle: _relationshipLabelStyle,
      ));
    }
    if (rel.fromMultiplicity != null) {
      final size = measurer.measure(rel.fromMultiplicity!, _multiplicityStyle);
      shapes.add(SceneText(
        offset: _multiplicityOffset(path, size, atFrom: true),
        text: rel.fromMultiplicity!,
        textStyle: _multiplicityStyle,
      ));
    }
    if (rel.toMultiplicity != null) {
      final size = measurer.measure(rel.toMultiplicity!, _multiplicityStyle);
      shapes.add(SceneText(
        offset: _multiplicityOffset(path, size, atFrom: false),
        text: rel.toMultiplicity!,
        textStyle: _multiplicityStyle,
      ));
    }
  }

  void _emitEdgePath(
    List<SceneShape> shapes,
    List<Offset> path,
    _RelStyle style, {
    required bool suppressHead,
  }) {
    if (path.length < 2) return;
    for (var i = 0; i < path.length - 1; i++) {
      final first = i == 0;
      final last = i == path.length - 2;
      final carriesHead = !suppressHead && (style.headAtFrom ? first : last);
      shapes.add(SceneLine(
        from: path[i],
        to: path[i + 1],
        dashed: style.dashed,
        head: carriesHead ? style.head : null,
        headAtFrom: carriesHead && style.headAtFrom,
        stroke: const Color(0xFF000000),
        strokeWidth: 1.0,
      ));
    }
  }

  Offset _pathMidpoint(List<Offset> path) {
    if (path.length == 1) return path.single;
    var total = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      total += (path[i + 1] - path[i]).distance;
    }
    if (total == 0) return path.first;
    var walked = 0.0;
    final target = total / 2;
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      final segment = (b - a).distance;
      if (walked + segment >= target) {
        final t = (target - walked) / segment;
        return Offset(
          a.dx + (b.dx - a.dx) * t,
          a.dy + (b.dy - a.dy) * t,
        );
      }
      walked += segment;
    }
    return path.last;
  }

  Offset _multiplicityOffset(
    List<Offset> path,
    Size size, {
    required bool atFrom,
  }) {
    final anchor = atFrom ? path.first : path.last;
    final other = atFrom
        ? (path.length > 1 ? path[1] : path.first)
        : (path.length > 1 ? path[path.length - 2] : path.last);
    final dx = other.dx - anchor.dx;
    final dy = other.dy - anchor.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) return Offset(anchor.dx, anchor.dy - size.height);
    final ux = dx / len;
    final uy = dy / len;
    final tx = anchor.dx + ux * 16;
    final ty = anchor.dy + uy * 16;
    return Offset(tx - size.width / 2, ty - size.height / 2);
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

  _RelStyle _styleFor(RelationshipKind kind) {
    switch (kind) {
      case RelationshipKind.inheritance:
        return const _RelStyle(
          dashed: false,
          head: ArrowHead.triangle,
          headAtFrom: true,
        );
      case RelationshipKind.realization:
        return const _RelStyle(
          dashed: true,
          head: ArrowHead.triangle,
          headAtFrom: true,
        );
      case RelationshipKind.composition:
        return const _RelStyle(
          dashed: false,
          head: ArrowHead.filledDiamond,
          headAtFrom: true,
        );
      case RelationshipKind.aggregation:
        return const _RelStyle(
          dashed: false,
          head: ArrowHead.hollowDiamond,
          headAtFrom: true,
        );
      case RelationshipKind.association:
        return const _RelStyle(dashed: false, head: null, headAtFrom: false);
      case RelationshipKind.directedAssociation:
        return const _RelStyle(
          dashed: false,
          head: ArrowHead.open,
          headAtFrom: false,
        );
      case RelationshipKind.dependency:
        return const _RelStyle(
          dashed: true,
          head: ArrowHead.open,
          headAtFrom: false,
        );
      case RelationshipKind.link:
        return const _RelStyle(dashed: true, head: null, headAtFrom: false);
    }
  }

  String? _stereotype(ClassKind kind) {
    switch (kind) {
      case ClassKind.class_:
      case ClassKind.abstractClass:
      case ClassKind.object_:
        return null;
      case ClassKind.interface:
        return '<<interface>>';
      case ClassKind.enum_:
        return '<<enum>>';
      case ClassKind.annotation:
        return '<<annotation>>';
      case ClassKind.exception:
        return '<<exception>>';
      case ClassKind.map_:
        return '<<map>>';
      case ClassKind.entity_:
        return '<<entity>>';
      case ClassKind.record_:
        return '<<record>>';
    }
  }

  static String _visibilityChar(Visibility v) {
    switch (v) {
      case Visibility.public:
        return '+';
      case Visibility.private:
        return '-';
      case Visibility.protected:
        return '#';
      case Visibility.packagePrivate:
        return '~';
    }
  }

  static Color _visibilityColor(Visibility v) {
    switch (v) {
      case Visibility.public:
        return _publicColor;
      case Visibility.private:
        return _privateColor;
      case Visibility.protected:
        return _protectedColor;
      case Visibility.packagePrivate:
        return _packageColor;
    }
  }
}

class _ClassBox {
  final ClassDecl decl;
  final TextStyle headerStyle;
  final String headerText;
  final String? stereotype;
  final Size stereotypeSize;
  final Size nameSize;
  final List<_MemberLine> memberLines;
  final double headerHeight;
  final double width;
  final double height;
  Rect rect = Rect.zero;

  _ClassBox({
    required this.decl,
    required this.headerStyle,
    required this.headerText,
    required this.stereotype,
    required this.stereotypeSize,
    required this.nameSize,
    required this.memberLines,
    required this.headerHeight,
    required this.width,
    required this.height,
  });
}

class _MemberLine {
  final String visibilityChar;
  final Color visibilityColor;
  final String body;
  final TextStyle bodyStyle;
  final double width;
  final double height;
  final double visWidth;
  final DividerKind? divider;

  const _MemberLine({
    required this.visibilityChar,
    required this.visibilityColor,
    required this.body,
    required this.bodyStyle,
    required this.width,
    required this.height,
    required this.visWidth,
    this.divider,
  });
}

class _RelStyle {
  final bool dashed;
  final ArrowHead? head;
  final bool headAtFrom;
  const _RelStyle({
    required this.dashed,
    required this.head,
    required this.headAtFrom,
  });
}
