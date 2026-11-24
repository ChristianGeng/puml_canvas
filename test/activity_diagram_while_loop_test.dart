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

  group('activity while loop extents', () {
    Rect textRect(SceneText t) =>
        Rect.fromLTWH(t.offset.dx, t.offset.dy, t.text.length * 7.0, 14);

    void expectInsideScene(Scene s) {
      for (final l in s.shapes.whereType<SceneLine>()) {
        for (final p in [l.from, l.to]) {
          expect(p.dx, greaterThanOrEqualTo(0), reason: 'line $p');
          expect(p.dx, lessThanOrEqualTo(s.size.width), reason: 'line $p');
        }
      }
      for (final t in s.shapes.whereType<SceneText>()) {
        final r = textRect(t);
        expect(r.left, greaterThanOrEqualTo(0), reason: 'label ${t.text}');
        expect(r.right, lessThanOrEqualTo(s.size.width),
            reason: 'label ${t.text}');
      }
    }

    test('three fork branches with short loops stay inside the scene', () {
      final s = _layout('''
@startuml
start
fork
  while (a?) is (y)
    :x;
  endwhile (n)
fork again
  while (b?) is (y)
    :x;
  endwhile (n)
fork again
  while (c?) is (y)
    :x;
  endwhile (n)
end fork
stop
@enduml
''');
      expectInsideScene(s);
    });

    test('a wide loop body keeps the exit route inside the scene', () {
      final s = _layout('''
@startuml
start
while (More?) is (yes)
  :${'w' * 80};
endwhile (no)
stop
@enduml
''');
      expectInsideScene(s);
    });

    test('empty body: the return path passes below the `is` label', () {
      final s = _layout(
          '@startuml\nwhile (x?) is (yes)\nendwhile (no)\nstop\n@enduml\n');
      final label = textRect(
          s.shapes.whereType<SceneText>().singleWhere((t) => t.text == 'yes'));
      for (final l in s.shapes.whereType<SceneLine>()) {
        final r = Rect.fromPoints(l.from, l.to);
        final crosses = r.left < label.right &&
            r.right > label.left &&
            r.top <= label.bottom &&
            r.bottom >= label.top;
        expect(crosses, isFalse, reason: 'line ${l.from}->${l.to}');
      }
    });

    test('a long `is` label stays clear of the loop-back', () {
      final s = _layout('''
@startuml
while (x?) is (yes keep going)
  :a;
endwhile (no)
stop
@enduml
''');
      final d = s.shapes.whereType<SceneDiamond>().single.rect;
      final label = textRect(s.shapes
          .whereType<SceneText>()
          .singleWhere((t) => t.text == 'yes keep going'));
      final into = s.shapes
          .whereType<SceneLine>()
          .singleWhere((l) => _isPoint(l.to, d.right, d.center.dy));
      expect(into.from.dx, greaterThan(label.right));
    });

    test('empty body with an `is` label: the parent attaches at the join', () {
      final s = _layout('''
@startuml
if (c?) then (y)
  while (x?) is (yes)
  endwhile
else (n)
  :b;
endif
@enduml
''');
      final d = s.shapes
          .whereType<SceneDiamond>()
          .singleWhere((x) => x.label == 'x?')
          .rect;
      final lines = s.shapes.whereType<SceneLine>().toList();
      // The exit edge rejoins the centre line at joinY ...
      final join = lines.singleWhere((l) =>
          _near(l.to.dx, d.center.dx) &&
          l.from.dx < d.left &&
          _near(l.from.dy, l.to.dy));
      final joinY = join.to.dy;
      // ... and the if-merge tail starts exactly there.
      final tail = lines.where(
          (l) => !identical(l, join) && _isPoint(l.from, d.center.dx, joinY));
      expect(tail, isNotEmpty);
    });

    test('`endwhile` label stays inside an enclosing partition', () {
      final s = _layout('''
@startuml
partition g {
  while (x?) is (y)
    :a;
  endwhile (a rather long label)
}
@enduml
''');
      final box = s.shapes.whereType<SceneBox>().single.rect;
      final label = textRect(s.shapes
          .whereType<SceneText>()
          .singleWhere((t) => t.text == 'a rather long label'));
      expect(label.left, greaterThanOrEqualTo(box.left));
    });

    test('`endwhile` label of a fork branch clears the neighbouring loop', () {
      final s = _layout('''
@startuml
fork
  while (a?) is (y)
    :x;
  endwhile (a rather long label)
fork again
  while (b?) is (y)
    :x;
  endwhile (a rather long label)
end fork
@enduml
''');
      Rect diamond(String label) => s.shapes
          .whereType<SceneDiamond>()
          .singleWhere((x) => x.label == label)
          .rect;
      final a = diamond('a?');
      final b = diamond('b?');
      // Loop a's loop-back column is its rightmost edge.
      final aRight = s.shapes
          .whereType<SceneLine>()
          .singleWhere((l) => _isPoint(l.to, a.right, a.center.dy))
          .from
          .dx;
      final bLabel = s.shapes
          .whereType<SceneText>()
          .where((t) => t.text == 'a rather long label')
          .map(textRect)
          .singleWhere((r) => r.left > a.right);
      expect(bLabel.right, lessThanOrEqualTo(b.left + 0.5));
      expect(bLabel.left, greaterThan(aRight));
    });
  });

  group('labels of blocks nested in a while loop', () {
    Rect textRect(SceneText t) =>
        Rect.fromLTWH(t.offset.dx, t.offset.dy, t.text.length * 7.0, 14);

    /// Lines passing through the interior of a label.
    List<String> crossings(Scene s) {
      final out = <String>[];
      for (final t in s.shapes.whereType<SceneText>()) {
        final r = textRect(t).deflate(0.5);
        for (final l in s.shapes.whereType<SceneLine>()) {
          final seg = Rect.fromPoints(l.from, l.to);
          final hit = seg.width < 0.5
              ? seg.left > r.left &&
                  seg.left < r.right &&
                  seg.top < r.bottom &&
                  seg.bottom > r.top
              : seg.height < 0.5
                  ? seg.top > r.top &&
                      seg.top < r.bottom &&
                      seg.left < r.right &&
                      seg.right > r.left
                  : seg.overlaps(r);
          if (hit) out.add('${t.text}: ${l.from}->${l.to}');
        }
      }
      return out;
    }

    void expectLabelsInsideScene(Scene s) {
      for (final t in s.shapes.whereType<SceneText>()) {
        final r = textRect(t);
        expect(r.left, greaterThanOrEqualTo(0), reason: 'label ${t.text}');
        expect(r.right, lessThanOrEqualTo(s.size.width),
            reason: 'label ${t.text}');
        expect(r.bottom, lessThanOrEqualTo(s.size.height),
            reason: 'label ${t.text}');
      }
    }

    /// Everything but the labels, for comparing layouts.
    List<String> geometry(Scene s) => [
          for (final x in s.shapes)
            if (x is SceneLine)
              'line ${x.from} ${x.to}'
            else if (x is SceneDiamond)
              'diamond ${x.rect}'
            else if (x is SceneRoundedBox)
              'box ${x.rect}'
        ];

    for (final (name, src) in [
      (
        '`not` label of a nested repeat',
        '''
@startuml
while (o?)
  repeat
    :a;
  repeat while (c?) is (y) not (n)
endwhile
@enduml
'''
      ),
      (
        '`is` label of a nested repeat',
        '''
@startuml
while (o?)
  repeat
    :a;
  repeat while (c?) is (yes)
endwhile
@enduml
'''
      ),
      (
        '`then` label of a nested if',
        '''
@startuml
while (o?)
  if (c?) then (yes indeed)
    :a;
  endif
endwhile
@enduml
'''
      ),
    ]) {
      test('$name is not crossed by the loop-back', () {
        final s = _layout(src);
        expect(crossings(s), isEmpty);
        expectLabelsInsideScene(s);
      });
    }

    test('a repeat outside a while keeps its geometry; `is` widens it', () {
      const plain = '''
@startuml
start
repeat
  :a;
repeat while (c?)
stop
@enduml
''';
      final s = _layout(plain.replaceFirst('(c?)', '(c?) is (a long yes)'));
      expect(geometry(s), geometry(_layout(plain)));
      expect(crossings(s), isEmpty);
      expectLabelsInsideScene(s);
    });

    test('a repeat outside a while: the exit passes its `not` label', () {
      const plain = '''
@startuml
start
repeat
  :a;
repeat while (c?)
:after;
@enduml
''';
      final before = _layout(plain);
      final s = _layout(plain.replaceFirst('(c?)', '(c?) not (no)'));
      Rect box(Scene x, String label) => x.shapes
          .whereType<SceneRoundedBox>()
          .singleWhere((b) => b.label == label)
          .rect;
      final c = s.shapes
          .whereType<SceneDiamond>()
          .singleWhere((d) => d.label == 'c?')
          .rect;
      expect(box(s, 'a'), box(before, 'a'));
      // The next node moves down by the label's height (14) plus 2.
      expect(box(s, 'after'), box(before, 'after').translate(0, 16));
      final not = textRect(
          s.shapes.whereType<SceneText>().singleWhere((t) => t.text == 'no'));
      expect(not.top, greaterThanOrEqualTo(c.bottom));
      expect(not.bottom, lessThanOrEqualTo(box(s, 'after').top));
      // The exit edge stays continuous from the diamond to the next node.
      final lines = s.shapes.whereType<SceneLine>();
      expect(
          lines.where((l) =>
              _isPoint(l.from, c.center.dx, c.bottom) &&
              _near(l.to.dy, not.bottom)),
          hasLength(1));
      expect(
          lines.where((l) =>
              _isPoint(l.from, c.center.dx, not.bottom) &&
              _near(l.to.dy, box(s, 'after').top)),
          hasLength(1));
      expect(crossings(s), isEmpty);
    });

    test('an if outside a while keeps its geometry; labels widen the scene',
        () {
      const plain = '''
@startuml
start
if (c?) then (y)
  :a;
else (n)
  :b;
endif
stop
@enduml
''';
      final s = _layout(plain.replaceFirst('then (y)', 'then (a very long yes)'));
      expect(geometry(s), geometry(_layout(plain)));
      expectLabelsInsideScene(s);
    });

    test('an if in a fork branch keeps its label clear of the next branch',
        () {
      final s = _layout('''
@startuml
start
fork
  if (c?) then (a very long yes label)
    :a;
  endif
fork again
  :b;
end fork
@enduml
''');
      final label = textRect(s.shapes
          .whereType<SceneText>()
          .singleWhere((t) => t.text == 'a very long yes label'));
      final b = s.shapes
          .whereType<SceneRoundedBox>()
          .singleWhere((x) => x.label == 'b')
          .rect;
      expect(label.right, lessThanOrEqualTo(b.left));
    });
  });
}
