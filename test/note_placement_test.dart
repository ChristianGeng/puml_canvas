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

/// Scales with the font size, so a skin font size shows in the layout.
class _ScaledTextMeasurer implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) {
    final fs = style.fontSize ?? 14;
    return Size(text.length * fs * 0.6, fs * 1.25);
  }
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

  group('sequence note clearance: plan matches emission', () {
    List<SceneLine> messages(Scene s) =>
        s.shapes.whereType<SceneLine>().where((l) => l.label != null).toList();

    double feetTop(Scene s) => (s.shapes
            .whereType<SceneBox>()
            .where((b) => b.label == 'A')
            .map((b) => b.rect.top)
            .toList()
          ..sort())
        .last;

    Scene layoutBody(String body, {String skin = ''}) => const AutoLayout()
        .layout(
            _parse('@startuml\n${skin}participant A\nparticipant B\n'
                '$body@enduml\n'),
            skin.isEmpty ? _FixedTextMeasurer() : _ScaledTextMeasurer());

    double lastMessageY(Scene s) =>
        messages(s).map((m) => m.from.dy).reduce((a, b) => a > b ? a : b);

    const note = 'note over A, B : context\n';

    // What follows the last message (group padding, ...) fixes its distance
    // to the participant feet; a note above it must not change that
    // distance unless the plan and emission disagree.
    void expectConsistent(String body) {
      final s = layoutBody(body);
      final plain = layoutBody(body.replaceAll(note, ''));
      expect(feetTop(s) - lastMessageY(s),
          closeTo(feetTop(plain) - lastMessageY(plain), 0.5),
          reason: 'feet gap for:\n$body');
      for (final m in messages(s)) {
        expect(m.from.dy, lessThan(feetTop(s)));
      }
      for (final x in s.shapes.whereType<SceneBox>()) {
        expect(x.rect.bottom, lessThanOrEqualTo(s.size.height));
      }
    }

    const msg = 'A -> B : hello\n';

    test('activation events between note and message keep the push', () {
      for (final between in [
        'activate A\n',
        'deactivate A\n',
        'create C\n',
        'destroy B\n',
      ]) {
        final body = (note + between + msg) * 4;
        expectConsistent(body);
        final s = layoutBody(body);
        final notes = s.shapes.whereType<SceneNote>().toList();
        final ms = messages(s);
        for (var i = 0; i < notes.length; i++) {
          // The label is drawn `height + 2` above the arrow.
          expect(ms[i].from.dy - 14 - 2,
              greaterThanOrEqualTo(notes[i].rect.bottom),
              reason: '$between: label $i clears its note');
        }
      }
    });

    test('a dash separator after the note ends its clearance', () {
      expectConsistent('$note--\n$msg');
    });

    test('a separator after the note ends its clearance', () {
      expectConsistent('$note== sep ==\n$msg');
    });

    test('a skip separator after the note ends its clearance', () {
      expectConsistent('$note...\n$msg');
    });

    test('a group starting after the note ends its clearance', () {
      expectConsistent('${note}group g\n${msg}end\n');
    });

    test('a group ending after the note ends its clearance', () {
      expectConsistent('group g\n${note}end\n$msg');
    });

    test('an else divider after the note ends its clearance', () {
      expectConsistent('alt a\n${note}else b\n${msg}end\n');
    });

    test('a synchronized message after a note keeps its pair', () {
      final s = layoutBody('A -> B : one\n$note& B -> A : two\n');
      final ms = messages(s);
      final one = ms.singleWhere((m) => m.label == 'one');
      final two = ms.singleWhere((m) => m.label == 'two');
      expect(two.from.dy, closeTo(one.from.dy, 0.5));
      expect(two.from.dy, lessThan(feetTop(s)));
    });

    group('with skinparam defaultFontSize 24', () {
      const skin = 'skinparam defaultFontSize 24\n';
      // _ScaledTextMeasurer: a 24 px label is 30 px high.
      const labelH = 30.0;

      test('the participant feet stay below the pushed-down message', () {
        final s = layoutBody('$note$msg', skin: skin);
        final plain = layoutBody(msg, skin: skin);
        final hello = messages(s).single;
        expect(hello.from.dy - labelH - 2,
            greaterThanOrEqualTo(s.shapes.whereType<SceneNote>().single.rect
                .bottom));
        expect(feetTop(s) - hello.from.dy,
            closeTo(feetTop(plain) - messages(plain).single.from.dy, 0.5));
        for (final x in s.shapes.whereType<SceneBox>()) {
          expect(x.rect.bottom, lessThanOrEqualTo(s.size.height));
        }
      });

      test('a self-message label is planned at the skin size', () {
        const last = 'A -> B : end\n';
        double gap(Scene s) =>
            feetTop(s) -
            messages(s).singleWhere((m) => m.label == 'end').from.dy;
        expect(gap(layoutBody('A -> A : self\n$last', skin: skin)),
            closeTo(gap(layoutBody(last, skin: skin)), 0.5));
      });
    });

    group('a first synchronized message has nothing to pair with', () {
      for (final first in ['& B -> A : two\n', '& A -> B : hello\n']) {
        test('${first.trim()} after a note clears it', () {
          final s = layoutBody('$note$first');
          final m = messages(s).single;
          expect(m.from.dy - 14 - 2,
              greaterThanOrEqualTo(
                  s.shapes.whereType<SceneNote>().single.rect.bottom));
          expectConsistent('$note$first');
        });

        test('${first.trim()} is planned like a plain message', () {
          double gap(Scene s) => feetTop(s) - messages(s).single.from.dy;
          expect(gap(layoutBody(first)),
              closeTo(gap(layoutBody(first.replaceFirst('& ', ''))), 0.5));
        });
      }
    });

    test('an inline note pushes the next label down too', () {
      final s = _layout('@startuml\n'
          'A -> B : first\n'
          'note right : a rather long note\n'
          'B -> A : a very long response label indeed\n'
          '@enduml\n');
      final n = _noteRect(s, 'a rather long note');
      final reply = messages(s)
          .singleWhere((l) => l.label == 'a very long response label indeed');
      expect(reply.from.dy - 14 - 2, greaterThanOrEqualTo(n.bottom));
      for (final m in messages(s)) {
        expect(m.from.dy, lessThan(feetTop(s)));
      }
    });
  });

  group('attached class notes never give up overlapping', () {
    test('a side note slides past a class taller than 600 px', () {
      final fields = [for (var i = 0; i < 60; i++) '  +field$i : int'];
      final s = _layout('@startuml\n'
          'class A\n'
          'class B {\n${fields.join('\n')}\n}\n'
          'note right of A : a note wider than the gap\n'
          '@enduml\n');
      final b = _classRect(s, 'B');
      expect(b.height, greaterThan(600));
      final n = _noteRect(s, 'a note wider than the gap');
      expect(n.overlaps(b), isFalse);
      expect(_inside(n, s.size), isTrue);
    });

    test('two top notes wider than 600 px do not overlap', () {
      final words = List.filled(100, 'w').join();
      final s = _layout('@startuml\n'
          'class A\n'
          'note top of A : first $words\n'
          'note top of A : second $words\n'
          '@enduml\n');
      final a = _noteRect(s, 'first $words');
      final b = _noteRect(s, 'second $words');
      expect(a.width, greaterThan(600));
      expect(a.overlaps(b), isFalse);
      expect(_inside(a, s.size) && _inside(b, s.size), isTrue);
    });
  });
}
