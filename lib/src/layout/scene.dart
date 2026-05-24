import 'package:flutter/painting.dart';

import '../ast/diagram.dart';

class Scene {
  final Size size;
  final List<SceneShape> shapes;
  final Color? background;
  const Scene({required this.size, required this.shapes, this.background});

  static const empty = Scene(size: Size.zero, shapes: []);
}

sealed class SceneShape {
  const SceneShape();
}

class SceneBox extends SceneShape {
  final Rect rect;
  final String? label;
  final TextStyle textStyle;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  const SceneBox({
    required this.rect,
    this.label,
    required this.textStyle,
    this.fill = const Color(0xFFFFFFFF),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
  });
}

class SceneNote extends SceneShape {
  final Rect rect;
  final String text;
  final TextStyle textStyle;
  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final double foldSize;

  const SceneNote({
    required this.rect,
    required this.text,
    required this.textStyle,
    this.fill = const Color(0xFFFEF9C3),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
    this.foldSize = 8.0,
  });
}

class SceneText extends SceneShape {
  final Offset offset;
  final String text;
  final TextStyle textStyle;
  final double maxWidth;

  const SceneText({
    required this.offset,
    required this.text,
    required this.textStyle,
    this.maxWidth = double.infinity,
  });
}

class SceneSymbol extends SceneShape {
  final Rect rect;
  final String label;
  final TextStyle labelStyle;
  final ParticipantKind kind;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  const SceneSymbol({
    required this.rect,
    required this.label,
    required this.labelStyle,
    required this.kind,
    this.fill = const Color(0xFFFFFFFF),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
  });
}

class SceneEllipse extends SceneShape {
  final Rect rect;
  final String label;
  final TextStyle textStyle;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  const SceneEllipse({
    required this.rect,
    required this.label,
    required this.textStyle,
    this.fill = const Color(0xFFFFFFFF),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
  });
}

class SceneDiamond extends SceneShape {
  final Rect rect;
  final String? label;
  final TextStyle textStyle;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  const SceneDiamond({
    required this.rect,
    this.label,
    required this.textStyle,
    this.fill = const Color(0xFFFFFFFF),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
  });
}

class SceneCircle extends SceneShape {
  final Offset center;
  final double radius;
  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final bool ring;

  const SceneCircle({
    required this.center,
    required this.radius,
    this.fill = const Color(0xFF000000),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
    this.ring = false,
  });
}

class SceneRoundedBox extends SceneShape {
  final Rect rect;
  final String? label;
  final TextStyle textStyle;
  final Color fill;
  final Color stroke;
  final double strokeWidth;
  final double cornerRadius;

  const SceneRoundedBox({
    required this.rect,
    this.label,
    required this.textStyle,
    this.fill = const Color(0xFFFFFFFF),
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
    this.cornerRadius = 8.0,
  });
}

class SceneCrowFoot extends SceneShape {
  final Offset position;
  final double angle;
  final CrowFoot kind;
  final Color stroke;
  final double strokeWidth;

  const SceneCrowFoot({
    required this.position,
    required this.angle,
    required this.kind,
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
  });
}

class SceneLine extends SceneShape {
  final Offset from;
  final Offset to;
  final bool dashed;
  final ArrowHead? head;
  final bool headAtFrom;
  final String? label;
  final TextStyle? labelStyle;
  final Color stroke;
  final double strokeWidth;

  const SceneLine({
    required this.from,
    required this.to,
    this.dashed = false,
    this.head = ArrowHead.filled,
    this.headAtFrom = false,
    this.label,
    this.labelStyle,
    this.stroke = const Color(0xFF000000),
    this.strokeWidth = 1.0,
  });
}
