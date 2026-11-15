import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

// Regression tests for ChristianGeng/puml_canvas#3: attached class notes
// are placed beside their target, and a message label after a sequence
// note is not covered by the note.

class _FixedTextMeasurer implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) => Size(text.length * 7.0, 14);
}

Diagram _parse(String source) => Parser().parse(Lexer().tokenize(source));

Scene _layout(String source) =>
    const AutoLayout().layout(_parse(source), _FixedTextMeasurer());

/// The outer box of class [name]: the largest box containing its header.
Rect _classRect(Scene scene, String name) {
  final header =
      scene.shapes.whereType<SceneText>().firstWhere((t) => t.text == name);
  final at = header.offset + const Offset(1, 1);
  final boxes = scene.shapes
      .whereType<SceneBox>()
      .where((b) => b.rect.contains(at))
      .toList()
    ..sort((a, b) =>
        (b.rect.width * b.rect.height).compareTo(a.rect.width * a.rect.height));
  return boxes.first.rect;
}

Rect _noteRect(Scene scene, String text) =>
    scene.shapes.whereType<SceneNote>().singleWhere((n) => n.text == text).rect;

bool _inside(Rect r, Size size) =>
    r.left >= 0 &&
    r.top >= 0 &&
    r.right <= size.width &&
    r.bottom <= size.height;

void main() {
  group('class note side (ChristianGeng/puml_canvas#3)', () {
    test('parser keeps the side of an attached note', () {
      final d = _parse('@startuml\n'
          'class A\n'
          'note left of A : l\n'
          'note right of A : r\n'
          'note top of A : t\n'
          'note bottom of A : b\n'
          'note "free" as N1\n'
          '@enduml\n') as ClassDiagram;
      final sides = {for (final n in d.freeNotes) n.text: n.side};
      expect(sides, {
        'l': NoteSide.left,
        'r': NoteSide.right,
        't': NoteSide.top,
        'b': NoteSide.bottom,
        'free': null,
      });
    });

    test('`note right of A` sits right of A, not under another class', () {
      final scene = _layout('@startuml\n'
          'class A\n'
          'class B\n'
          'A --> B\n'
          'note right of A : about A\n'
          '@enduml\n');
      final a = _classRect(scene, 'A');
      final b = _classRect(scene, 'B');
      final note = _noteRect(scene, 'about A');

      expect(note.left, greaterThan(a.right));
      // Vertically level with A (overlapping its band), above B.
      expect(note.top, lessThan(a.bottom));
      expect(note.bottom, greaterThan(a.top));
      expect(note.overlaps(a), isFalse);
      expect(note.overlaps(b), isFalse);
      expect(note.top, lessThan(b.top));
      expect(_inside(note, scene.size), isTrue);

      // A dashed connector joins the note and A.
      final dashed = scene.shapes
          .whereType<SceneLine>()
          .where((l) => l.dashed && l.head == null);
      expect(
          dashed.where((l) =>
              (l.from.dx - note.left).abs() < 0.5 &&
              (l.to.dx - a.right).abs() < 0.5),
          hasLength(1));
    });

    test('`note left of A` sits left of A and stays inside the scene', () {
      final scene = _layout('@startuml\n'
          'class A\n'
          'note left of A : on the left\n'
          '@enduml\n');
      final a = _classRect(scene, 'A');
      final note = _noteRect(scene, 'on the left');
      expect(note.right, lessThan(a.left));
      expect(note.top, lessThan(a.bottom));
      expect(note.bottom, greaterThan(a.top));
      expect(_inside(note, scene.size), isTrue);
      expect(_inside(a, scene.size), isTrue);
    });

    test('`note top of` / `note bottom of` sit above / below the target', () {
      final scene = _layout('@startuml\n'
          'class A\n'
          'note top of A : above\n'
          'note bottom of A : below\n'
          '@enduml\n');
      final a = _classRect(scene, 'A');
      expect(_noteRect(scene, 'above').bottom, lessThan(a.top));
      expect(_noteRect(scene, 'below').top, greaterThan(a.bottom));
    });

    test('a note beside a class is nudged clear of a neighbouring class', () {
      final scene = _layout('@startuml\n'
          'class A\n'
          'class B\n'
          'class C\n'
          'A --> B\n'
          'A --> C\n'
          'note right of B : a long note about B\n'
          '@enduml\n');
      final note = _noteRect(scene, 'a long note about B');
      for (final name in ['A', 'B', 'C']) {
        expect(note.overlaps(_classRect(scene, name)), isFalse, reason: name);
      }
    });

    test('free-standing notes still go below the classes', () {
      final scene = _layout('@startuml\n'
          'class A\n'
          'note "free" as N1\n'
          'N1 .. A\n'
          '@enduml\n');
      expect(_noteRect(scene, 'free').top,
          greaterThan(_classRect(scene, 'A').bottom));
    });
  });

  group('sequence note before a message (ChristianGeng/puml_canvas#3)', () {
    const repro = '@startuml\n'
        'note over A, B : handshake\n'
        'A -> B : hello\n'
        '@enduml\n';

    test('the next message label sits below the note', () {
      final scene = _layout(repro);
      final note = _noteRect(scene, 'handshake');
      final msg = scene.shapes
          .whereType<SceneLine>()
          .singleWhere((l) => l.label == 'hello');
      // The renderer draws a line label `height + 2` above the line.
      final labelTop = msg.from.dy - 14 - 2;
      expect(labelTop, greaterThanOrEqualTo(note.bottom));
    });

    test('the same holds for a side note between two messages', () {
      final scene = _layout('@startuml\n'
          'A -> B : hello\n'
          'note left of A\n'
          '  multi-line\n'
          '  note\n'
          'end note\n'
          'B --> A : ack\n'
          '@enduml\n');
      final note = _noteRect(scene, 'multi-line\nnote');
      final ack = scene.shapes
          .whereType<SceneLine>()
          .singleWhere((l) => l.label == 'ack');
      expect(ack.from.dy - 14 - 2, greaterThanOrEqualTo(note.bottom));
    });

    test('the participant feet stay below the pushed-down message', () {
      final scene = _layout(repro);
      final msg = scene.shapes
          .whereType<SceneLine>()
          .singleWhere((l) => l.label == 'hello');
      final feet = scene.shapes
          .whereType<SceneBox>()
          .where((b) => b.label == 'A')
          .map((b) => b.rect.top)
          .toList()
        ..sort();
      expect(feet, hasLength(2));
      expect(feet.last, greaterThan(msg.from.dy));
    });
  });
}
