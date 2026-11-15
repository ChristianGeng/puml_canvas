import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

class _FixedTextMeasurer implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) => Size(text.length * 7.0, 14);
}

Scene _layout(String source) {
  final diagram = Parser().parse(Lexer().tokenize(source)) as ActivityDiagram;
  return const ActivityLayout().layout(diagram, _FixedTextMeasurer());
}

const _repro = '''
@startuml
start
while (More?) is (yes)
  :Process;
endwhile (no)
stop
@enduml
''';

bool _near(double a, double b) => (a - b).abs() < 0.5;

bool _isPoint(Offset p, double x, double y) => _near(p.dx, x) && _near(p.dy, y);

void main() {
  group('activity while loop edges (ChristianGeng/puml_canvas#2)', () {
    late Scene scene;
    late Rect diamond;
    late Rect body;
    late List<SceneLine> lines;

    setUp(() {
      scene = _layout(_repro);
      diamond = scene.shapes.whereType<SceneDiamond>().single.rect;
      body = scene.shapes
          .whereType<SceneRoundedBox>()
          .singleWhere((b) => b.label == 'Process')
          .rect;
      lines = scene.shapes.whereType<SceneLine>().toList();
    });

    test('loop-back runs right of the body into the diamond right corner', () {
      final into = lines.where((l) =>
          _isPoint(l.to, diamond.right, diamond.center.dy) &&
          l.head == ArrowHead.filled);
      expect(into, hasLength(1), reason: 'arrow into the right corner');
      final loopX = into.single.from.dx;
      expect(loopX, greaterThan(body.right));
      expect(loopX, greaterThan(diamond.right));

      // A vertical segment at loopX climbs from below the body up to the
      // diamond's centre line.
      final up = lines.where((l) =>
          _near(l.from.dx, loopX) &&
          _near(l.to.dx, loopX) &&
          l.from.dy > body.bottom &&
          _near(l.to.dy, diamond.center.dy));
      expect(up, hasLength(1));

      // And it is fed from the body's bottom.
      final down = lines.where((l) =>
          _isPoint(l.from, body.center.dx, body.bottom) &&
          _near(l.to.dx, body.center.dx) &&
          l.to.dy > body.bottom);
      expect(down, isNotEmpty);
    });

    test('exit leaves the left corner and rejoins below the body', () {
      final out =
          lines.where((l) => _isPoint(l.from, diamond.left, diamond.center.dy));
      expect(out, hasLength(1), reason: 'edge out of the left corner');
      final exitX = out.single.to.dx;
      expect(exitX, lessThan(body.left));
      expect(exitX, lessThan(diamond.left));

      final drop = lines.singleWhere((l) =>
          _near(l.from.dx, exitX) &&
          _near(l.to.dx, exitX) &&
          _near(l.from.dy, diamond.center.dy));
      final joinY = drop.to.dy;
      expect(joinY, greaterThan(body.bottom));

      final back = lines.where((l) =>
          _isPoint(l.from, exitX, joinY) &&
          _isPoint(l.to, diamond.center.dx, joinY));
      expect(back, hasLength(1), reason: 'exit returns to the centre line');

      // The arrow into `stop` starts at the join point, not at the body.
      final stop = scene.shapes.whereType<SceneCircle>().last;
      final intoStop = lines.where((l) =>
          _isPoint(l.from, diamond.center.dx, joinY) &&
          l.to.dy <= stop.center.dy - stop.radius + 0.5 &&
          l.head == ArrowHead.filled);
      expect(intoStop, hasLength(1));
    });

    test('`is` label sits under the diamond, `endwhile` label beside the exit',
        () {
      final texts = scene.shapes.whereType<SceneText>();
      final yes = texts.singleWhere((t) => t.text == 'yes');
      expect(yes.offset.dy, greaterThanOrEqualTo(diamond.bottom));
      expect(yes.offset.dy + 14, lessThanOrEqualTo(body.top));
      expect(yes.offset.dx, greaterThanOrEqualTo(diamond.center.dx));

      final no = texts.singleWhere((t) => t.text == 'no');
      expect(no.offset.dx + 'no'.length * 7.0,
          lessThanOrEqualTo(diamond.left + 0.5));
      expect(no.offset.dy, lessThan(diamond.center.dy));
      expect(no.offset.dy + 14, greaterThan(diamond.top));
    });

    test('scene is large enough for the side edges', () {
      for (final l in lines) {
        expect(l.from.dx, greaterThanOrEqualTo(0));
        expect(l.to.dx, greaterThanOrEqualTo(0));
        expect(l.from.dx, lessThanOrEqualTo(scene.size.width));
        expect(l.to.dx, lessThanOrEqualTo(scene.size.width));
        expect(l.to.dy, lessThanOrEqualTo(scene.size.height));
      }
    });

    test('empty body still loops back and exits', () {
      final s = _layout('@startuml\nwhile (x?)\nendwhile\nstop\n@enduml\n');
      final d = s.shapes.whereType<SceneDiamond>().single.rect;
      final ls = s.shapes.whereType<SceneLine>();
      expect(
          ls.where((l) => _isPoint(l.to, d.right, d.center.dy)), hasLength(1));
      expect(
          ls.where((l) => _isPoint(l.from, d.left, d.center.dy)), hasLength(1));
    });
  });
}
