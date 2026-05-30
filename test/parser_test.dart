import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

SequenceDiagram parseSequence(String source) {
  final tokens = Lexer().tokenize(source);
  final diagram = Parser().parse(tokens);
  return diagram as SequenceDiagram;
}

void main() {
  group('Parser', () {
    test('parses an empty sequence diagram', () {
      final d = parseSequence('@startuml\n@enduml\n');
      expect(d.events, isEmpty);
      expect(d.participants, isEmpty);
    });

    test('parses a single labeled message', () {
      final d = parseSequence('@startuml\nA -> B : hello\n@enduml\n');
      expect(d.events, hasLength(1));
      final m = d.events.single as Message;
      expect(m.from, 'A');
      expect(m.to, 'B');
      expect(m.label, 'hello');
      expect(m.lineStyle, LineStyle.solid);
      expect(m.head, ArrowHead.filled);
      expect(m.direction, MessageDirection.forward);
    });

    test('parses dashed arrow style', () {
      final d = parseSequence('@startuml\nA --> B\n@enduml\n');
      final m = d.events.single as Message;
      expect(m.lineStyle, LineStyle.dashed);
      expect(m.head, ArrowHead.filled);
    });

    group('arrow variants', () {
      const cases = <(String, LineStyle, ArrowHead, MessageDirection)>[
        ('->', LineStyle.solid, ArrowHead.filled, MessageDirection.forward),
        ('-->', LineStyle.dashed, ArrowHead.filled, MessageDirection.forward),
        ('->>', LineStyle.solid, ArrowHead.open, MessageDirection.forward),
        ('-->>', LineStyle.dashed, ArrowHead.open, MessageDirection.forward),
        (
          '->o',
          LineStyle.solid,
          ArrowHead.openCircle,
          MessageDirection.forward
        ),
        (
          '-->o',
          LineStyle.dashed,
          ArrowHead.openCircle,
          MessageDirection.forward
        ),
        ('->x', LineStyle.solid, ArrowHead.cross, MessageDirection.forward),
        ('-->x', LineStyle.dashed, ArrowHead.cross, MessageDirection.forward),
        ('<-', LineStyle.solid, ArrowHead.filled, MessageDirection.backward),
        ('<--', LineStyle.dashed, ArrowHead.filled, MessageDirection.backward),
        ('<<-', LineStyle.solid, ArrowHead.open, MessageDirection.backward),
        ('<<--', LineStyle.dashed, ArrowHead.open, MessageDirection.backward),
      ];
      for (final c in cases) {
        test('"${c.$1}" decodes to (${c.$2}, ${c.$3}, ${c.$4})', () {
          final d = parseSequence('@startuml\nA ${c.$1} B\n@enduml\n');
          final m = d.events.single as Message;
          expect(m.from, 'A');
          expect(m.to, 'B');
          expect(m.lineStyle, c.$2);
          expect(m.head, c.$3);
          expect(m.direction, c.$4);
        });
      }
    });

    group('arrow head/tail decoration variants', () {
      // The 20 PlantUML message arrow head/tail combos the user-supplied
      // repro covers. Each entry is (arrow, head, direction, tailDecoration).
      // The line style is implicitly solid for all of these.
      const cases = <(
        String,
        ArrowHead,
        MessageDirection,
        EndpointDecoration?
      )>[
        ('->', ArrowHead.filled, MessageDirection.forward, null),
        ('->>', ArrowHead.open, MessageDirection.forward, null),
        ('-\\', ArrowHead.open, MessageDirection.forward, null),
        ('-\\\\', ArrowHead.open, MessageDirection.forward, null),
        ('-/', ArrowHead.open, MessageDirection.forward, null),
        ('-//', ArrowHead.open, MessageDirection.forward, null),
        ('->x', ArrowHead.cross, MessageDirection.forward, null),
        (
          'x->',
          ArrowHead.filled,
          MessageDirection.forward,
          EndpointDecoration.cross,
        ),
        (
          'o->',
          ArrowHead.filled,
          MessageDirection.forward,
          EndpointDecoration.openCircle,
        ),
        ('->o', ArrowHead.openCircle, MessageDirection.forward, null),
        (
          'o->o',
          ArrowHead.openCircle,
          MessageDirection.forward,
          EndpointDecoration.openCircle,
        ),
        ('<->', ArrowHead.filled, MessageDirection.bidirectional, null),
        (
          'o<->o',
          ArrowHead.openCircle,
          MessageDirection.bidirectional,
          EndpointDecoration.openCircle,
        ),
        (
          'x<->x',
          ArrowHead.cross,
          MessageDirection.bidirectional,
          EndpointDecoration.cross,
        ),
        ('->>o', ArrowHead.openCircle, MessageDirection.forward, null),
        ('-\\o', ArrowHead.openCircle, MessageDirection.forward, null),
        ('-\\\\o', ArrowHead.openCircle, MessageDirection.forward, null),
        ('-/o', ArrowHead.openCircle, MessageDirection.forward, null),
        ('-//o', ArrowHead.openCircle, MessageDirection.forward, null),
        (
          'x->o',
          ArrowHead.openCircle,
          MessageDirection.forward,
          EndpointDecoration.cross,
        ),
      ];
      for (final c in cases) {
        test('"${c.$1}" decodes to head=${c.$2} dir=${c.$3} tail=${c.$4}', () {
          final d = parseSequence('@startuml\nA ${c.$1} B\n@enduml\n');
          final m = d.events.single as Message;
          expect(m.from, 'A');
          expect(m.to, 'B');
          expect(m.lineStyle, LineStyle.solid);
          expect(m.head, c.$2);
          expect(m.direction, c.$3);
          expect(m.tailDecoration, c.$4);
        });
      }

      test('the full repro source parses all 20 arrows in order', () {
        final d = parseSequence(
          '@startuml\n'
          'participant Alice as a\n'
          'participant Bob   as b\n'
          'a ->     b\n'
          'a ->>    b\n'
          'a -\\     b\n'
          'a -\\\\    b\n'
          'a -/     b\n'
          'a -//    b\n'
          'a ->x    b\n'
          'a x->    b\n'
          'a o->    b\n'
          'a ->o    b\n'
          'a o->o   b\n'
          'a <->    b\n'
          'a o<->o  b\n'
          'a x<->x  b\n'
          'a ->>o   b\n'
          'a -\\o    b\n'
          'a -\\\\o   b\n'
          'a -/o    b\n'
          'a -//o   b\n'
          'a x->o   b\n'
          '@enduml\n',
        );
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(20));
        // Each message addresses a / b, never collapses into a bidirectional
        // misparse, and never produces a stray identifier consumption.
        for (final m in messages) {
          expect(m.from, 'a');
          expect(m.to, 'b');
        }
        // Spot-check the four lexer-bug regressions specifically. Order
        // matches the verbatim source: index 10 is `o->o`, 12 is `o<->o`,
        // 13 is `x<->x`, 19 is `x->o`.
        expect(messages[10].direction, MessageDirection.forward); // o->o
        expect(messages[10].head, ArrowHead.openCircle);
        expect(messages[10].tailDecoration, EndpointDecoration.openCircle);
        expect(messages[12].direction, MessageDirection.bidirectional); // o<->o
        expect(messages[12].head, ArrowHead.openCircle);
        expect(messages[12].tailDecoration, EndpointDecoration.openCircle);
        expect(messages[13].direction, MessageDirection.bidirectional); // x<->x
        expect(messages[13].head, ArrowHead.cross);
        expect(messages[13].tailDecoration, EndpointDecoration.cross);
        expect(messages[19].direction, MessageDirection.forward); // x->o
        expect(messages[19].head, ArrowHead.openCircle);
        expect(messages[19].tailDecoration, EndpointDecoration.cross);
      });
    });

    group('arrow modifiers', () {
      test('hidden flag is decoded', () {
        final d = parseSequence('@startuml\nA -[hidden]-> B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.hidden, isTrue);
        expect(m.color, isNull);
        expect(m.lineStyle, LineStyle.solid);
        expect(m.head, ArrowHead.filled);
        expect(m.direction, MessageDirection.forward);
      });

      test('hex color is decoded', () {
        final d = parseSequence('@startuml\nA -[#FF8800]-> B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.color, const Color(0xFFFF8800));
        expect(m.hidden, isFalse);
        expect(m.lineStyle, LineStyle.solid);
      });

      test('named color is decoded case-insensitively', () {
        final d =
            parseSequence('@startuml\nA -[#Red]-> B\nC -[Blue]-> D\n@enduml\n');
        final messages = d.events.whereType<Message>().toList();
        expect(messages[0].color, const Color(0xFFFF0000));
        expect(messages[1].color, const Color(0xFF0000FF));
      });

      test('dashed-with-color decodes both', () {
        final d = parseSequence('@startuml\nA --[#blue]-> B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.lineStyle, LineStyle.dashed);
        expect(m.color, const Color(0xFF0000FF));
      });

      test('color composes with open V head', () {
        final d = parseSequence('@startuml\nA -[#red]->> B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.head, ArrowHead.open);
        expect(m.color, const Color(0xFFFF0000));
      });

      test('backward solid colored', () {
        final d = parseSequence('@startuml\nA <-[#blue]- B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.direction, MessageDirection.backward);
        expect(m.lineStyle, LineStyle.solid);
        expect(m.color, const Color(0xFF0000FF));
      });

      test('backward dashed colored', () {
        final d = parseSequence('@startuml\nA <--[#00FF00]-- B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.direction, MessageDirection.backward);
        expect(m.lineStyle, LineStyle.dashed);
        expect(m.color, const Color(0xFF00FF00));
      });

      test('short hex #RGB expands', () {
        final d = parseSequence('@startuml\nA -[#F80]-> B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.color, const Color(0xFFFF8800));
      });

      test('argb hex #AARRGGBB is honored', () {
        final d = parseSequence('@startuml\nA -[#80FF0000]-> B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.color, const Color(0x80FF0000));
      });

      test('unknown color name throws ParserException', () {
        expect(
          () => parseSequence('@startuml\nA -[chartreuse]-> B\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('default message has no color and is not hidden', () {
        final d = parseSequence('@startuml\nA -> B\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.hidden, isFalse);
        expect(m.color, isNull);
      });
    });

    test('preserves participant order across messages', () {
      final d = parseSequence(
        '@startuml\nA -> B\nB -> C\nA -> C\n@enduml\n',
      );
      expect(d.participantsInOrder().map((p) => p.alias).toList(),
          ['A', 'B', 'C']);
    });

    test('throws on missing arrow', () {
      expect(
        () => parseSequence('@startuml\nA B\n@enduml\n'),
        throwsA(isA<ParserException>()),
      );
    });

    group('found / lost messages (anonymous endpoints)', () {
      test('?-> Target marks fromShort source', () {
        final d = parseSequence('@startuml\n?-> Alice\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.fromExternal, MessageExternal.fromShort);
        expect(m.toExternal, isNull);
        expect(m.to, 'Alice');
        expect(m.direction, MessageDirection.forward);
        expect(m.head, ArrowHead.filled);
        // Anonymous source must not pollute the participant order.
        expect(d.participantsInOrder().map((p) => p.alias).toList(), ['Alice']);
      });

      test('[-> Target marks fromEdge source', () {
        final d = parseSequence('@startuml\n[-> Alice\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.fromExternal, MessageExternal.fromEdge);
        expect(m.toExternal, isNull);
        expect(m.to, 'Alice');
        expect(d.participantsInOrder().map((p) => p.alias).toList(), ['Alice']);
      });

      test('Source ->] marks toEdge target', () {
        final d = parseSequence('@startuml\nAlice ->]\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.fromExternal, isNull);
        expect(m.toExternal, MessageExternal.toEdge);
        expect(m.from, 'Alice');
        expect(d.participantsInOrder().map((p) => p.alias).toList(), ['Alice']);
      });

      test('Source ->? marks toShort target', () {
        final d = parseSequence('@startuml\nAlice ->?\n@enduml\n');
        final m = d.events.single as Message;
        expect(m.fromExternal, isNull);
        expect(m.toExternal, MessageExternal.toShort);
        expect(m.from, 'Alice');
        expect(d.participantsInOrder().map((p) => p.alias).toList(), ['Alice']);
      });

      test('dashed forms `?-->` / `-->]` preserve LineStyle.dashed', () {
        final d = parseSequence(
          '@startuml\n?--> Alice\nAlice -->]\n@enduml\n',
        );
        final ms = d.events.whereType<Message>().toList();
        expect(ms, hasLength(2));
        expect(ms[0].lineStyle, LineStyle.dashed);
        expect(ms[0].fromExternal, MessageExternal.fromShort);
        expect(ms[1].lineStyle, LineStyle.dashed);
        expect(ms[1].toExternal, MessageExternal.toEdge);
      });

      test('verbatim source with all four forms parses cleanly', () {
        final d = parseSequence('''@startuml
?-> Alice    : ""?->""\\n**short** to actor1
[-> Alice    : ""[->""\\n**from start** to actor1
[-> Bob      : ""[->""\\n**from start** to actor2
?-> Bob      : ""?->""\\n**short** to actor2
Alice ->]    : ""->]""\\nfrom actor1 **to end**
Alice ->?    : ""->?""\\n**short** from actor1
Alice -> Bob : ""->"" \\nfrom actor1 to actor2
@enduml
''');
        final ms = d.events.whereType<Message>().toList();
        expect(ms, hasLength(7));
        expect(ms[0].fromExternal, MessageExternal.fromShort);
        expect(ms[0].to, 'Alice');
        expect(ms[1].fromExternal, MessageExternal.fromEdge);
        expect(ms[1].to, 'Alice');
        expect(ms[2].fromExternal, MessageExternal.fromEdge);
        expect(ms[2].to, 'Bob');
        expect(ms[3].fromExternal, MessageExternal.fromShort);
        expect(ms[3].to, 'Bob');
        expect(ms[4].from, 'Alice');
        expect(ms[4].toExternal, MessageExternal.toEdge);
        expect(ms[5].from, 'Alice');
        expect(ms[5].toExternal, MessageExternal.toShort);
        expect(ms[6].from, 'Alice');
        expect(ms[6].to, 'Bob');
        expect(ms[6].fromExternal, isNull);
        expect(ms[6].toExternal, isNull);
        // Only Alice + Bob — no anonymous-endpoint participant pollution.
        expect(d.participantsInOrder().map((p) => p.alias).toList(),
            ['Alice', 'Bob']);
      });
    });

    group('lost-endpoint `?` combined with arrow-head variants', () {
      // Regression: previously the lexer accepted `?` only after a plain `>`
      // / `>>` head, NOT after head/cap decorations (`o`, `x`, `\`, `\\`,
      // `/`, `//`) or trailing caps (`>o`, `>>o`, `>x`). This group locks in
      // the 20 head-variant + short-lost combinations from the bug report.
      Message decode(String arrow) {
        final d = parseSequence('@startuml\nAlice $arrow\n@enduml\n');
        return d.events.whereType<Message>().single;
      }

      void expectShortLost(Message m,
          {required ArrowHead head,
          required MessageDirection direction,
          required LineStyle lineStyle,
          EndpointDecoration? tailDecoration}) {
        expect(m.toExternal, MessageExternal.toShort);
        expect(m.fromExternal, isNull);
        expect(m.from, 'Alice');
        expect(m.head, head);
        expect(m.direction, direction);
        expect(m.lineStyle, lineStyle);
        expect(m.tailDecoration, tailDecoration);
      }

      test('->? : plain filled head + short lost', () {
        expectShortLost(decode('->?'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('->>? : open (thin/async) head + short lost', () {
        expectShortLost(decode('->>?'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'-\? : single-half head + short lost', () {
        expectShortLost(decode(r'-\?'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'-\\? : double-half head + short lost', () {
        expectShortLost(decode(r'-\\?'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('-/? : single-half head + short lost', () {
        expectShortLost(decode('-/?'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('-//? : double-half head + short lost', () {
        expectShortLost(decode('-//?'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('->x? : cross head + short lost', () {
        expectShortLost(decode('->x?'),
            head: ArrowHead.cross,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('x->? : cross tail + filled head + short lost', () {
        expectShortLost(decode('x->?'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.cross);
      });

      test('o->? : circle tail + filled head + short lost', () {
        expectShortLost(decode('o->?'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('->o? : circle head + short lost', () {
        expectShortLost(decode('->o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('o->o? : circle tail + circle head + short lost', () {
        // The combined glyph `o->o` MUST decode as (tail=o, head=o) — not
        // as (head=o) + literal `?o` left over. This is the textbook
        // failure mode the bug report calls out.
        expectShortLost(decode('o->o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('->>o? : open head with circle cap + short lost', () {
        expectShortLost(decode('->>o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'-\o? : half head with circle cap + short lost', () {
        expectShortLost(decode(r'-\o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'-\\o? : double-half head with circle cap + short lost', () {
        expectShortLost(decode(r'-\\o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('-/o? : half head with circle cap + short lost', () {
        expectShortLost(decode('-/o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('-//o? : double-half head with circle cap + short lost', () {
        expectShortLost(decode('-//o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('x->o? : cross tail + circle head + short lost', () {
        expectShortLost(decode('x->o?'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.cross);
      });

      group('bidirectional + lost-endpoint normalizes to forward', () {
        // Structural decision: a bidirectional arrow needs a real participant
        // on BOTH sides to mount the return triangle. When the right side is
        // anonymous (`?`/`]`), there's nothing to point back at, so the
        // parser collapses the direction to forward. The head shape and any
        // tail decoration ARE preserved so the visible glyphs from the
        // source still appear in the rendered output.
        test('<->? : plain bidirectional + short lost → forward', () {
          expectShortLost(decode('<->?'),
              head: ArrowHead.filled,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid);
        });

        test('o<->o? : circle-decorated bidirectional + short lost → forward',
            () {
          expectShortLost(decode('o<->o?'),
              head: ArrowHead.openCircle,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid,
              tailDecoration: EndpointDecoration.openCircle);
        });

        test('x<->x? : cross-decorated bidirectional + short lost → forward',
            () {
          expectShortLost(decode('x<->x?'),
              head: ArrowHead.cross,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid,
              tailDecoration: EndpointDecoration.cross);
        });
      });

      test(
          'verbatim 21-line source from the bug report parses with all '
          'forms producing toShort right endpoints', () {
        // The exact source from the user bug report (lines 5–25). Line 4
        // is the italic-label baseline; the remaining 20 lines exercise the
        // head-variant + short-lost combination. All 20 must mark
        // toExternal = toShort with the head/tail decoded from the glyphs.
        final d = parseSequence('@startuml\n'
            'participant Alice as a\n'
            'participant Bob   as b\n'
            'a ->     b : //Long long label//\n'
            'a ->?      : ""->?   ""\n'
            'a ->>?     : ""->>?  ""\n'
            'a -\\?      : ""-\\?   ""\n'
            'a -\\\\?     : ""-\\\\\\\\?""\n'
            'a -/?      : ""-/?   ""\n'
            'a -//?     : ""-//?  ""\n'
            'a ->x?     : ""->x?  ""\n'
            'a x->?     : ""x->?  ""\n'
            'a o->?     : ""o->?  ""\n'
            'a ->o?     : ""->o?  ""\n'
            'a o->o?    : ""o->o? ""\n'
            'a <->?     : ""<->?  ""\n'
            'a o<->o?   : ""o<->o?""\n'
            'a x<->x?   : ""x<->x?""\n'
            'a ->>o?    : ""->>o? ""\n'
            'a -\\o?     : ""-\\o?  ""\n'
            'a -\\\\o?    : ""-\\\\\\\\o?""\n'
            'a -/o?     : ""-/o?  ""\n'
            'a -//o?    : ""-//o? ""\n'
            'a x->o?    : ""x->o? ""\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms, hasLength(21));
        // First message: plain `->` (no lost endpoint), with the italic
        // label preserved verbatim for inline markup to interpret.
        expect(ms[0].toExternal, isNull);
        expect(ms[0].label, '//Long long label//');
        // Every other message ends at a short-lost stub.
        for (final m in ms.skip(1)) {
          expect(m.toExternal, MessageExternal.toShort,
              reason: 'arrow with label ${m.label} should be toShort');
          expect(m.fromExternal, isNull);
        }
        // No bidirectional arrow survives — the three `<->?` rows collapse
        // to forward (since the lost-endpoint can't receive a return tip).
        expect(ms.where((m) => m.direction == MessageDirection.bidirectional),
            isEmpty);
        // The 21 arrow rows must NOT introduce extra participants — only
        // `a` and `b` should appear in declaration order.
        expect(d.participantsInOrder().map((p) => p.alias).toList(),
            ['a', 'b']);
      });
    });

    group('found-endpoint `?` combined with arrow-head variants (Case B)', () {
      // Left-side mirror of the lost-endpoint `?` group above. Previously the
      // lexer accepted `?->` and `?->>` but rejected `?-\`, `?o->`, `?o->o`,
      // `?<->`, etc. — the found-marker scan composed badly with leading
      // tail decorations and half-arrow body forms. This group locks in all
      // 20 head-variant + short-found combinations.
      Message decode(String arrow) {
        final d = parseSequence('@startuml\n$arrow Bob\n@enduml\n');
        return d.events.whereType<Message>().single;
      }

      void expectShortFound(Message m,
          {required ArrowHead head,
          required MessageDirection direction,
          required LineStyle lineStyle,
          EndpointDecoration? tailDecoration}) {
        expect(m.fromExternal, MessageExternal.fromShort);
        expect(m.toExternal, isNull);
        expect(m.to, 'Bob');
        expect(m.head, head);
        expect(m.direction, direction);
        expect(m.lineStyle, lineStyle);
        expect(m.tailDecoration, tailDecoration);
      }

      test('?-> : plain filled head + short found', () {
        expectShortFound(decode('?->'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?->> : open (thin/async) head + short found', () {
        expectShortFound(decode('?->>'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'?-\ : single-half head + short found', () {
        expectShortFound(decode(r'?-\'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'?-\\ : double-half head + short found', () {
        expectShortFound(decode(r'?-\\'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?-/ : single-half head + short found', () {
        expectShortFound(decode('?-/'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?-// : double-half head + short found', () {
        expectShortFound(decode('?-//'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?->x : cross head + short found', () {
        expectShortFound(decode('?->x'),
            head: ArrowHead.cross,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?x-> : cross tail + filled head + short found', () {
        expectShortFound(decode('?x->'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.cross);
      });

      test('?o-> : circle tail + filled head + short found', () {
        expectShortFound(decode('?o->'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('?->o : circle head + short found', () {
        expectShortFound(decode('?->o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?o->o : circle tail + circle head + short found', () {
        expectShortFound(decode('?o->o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('?->>o : open head with circle cap + short found', () {
        expectShortFound(decode('?->>o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'?-\o : half head with circle cap + short found', () {
        expectShortFound(decode(r'?-\o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'?-\\o : double-half head with circle cap + short found', () {
        expectShortFound(decode(r'?-\\o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?-/o : half head with circle cap + short found', () {
        expectShortFound(decode('?-/o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?-//o : double-half head with circle cap + short found', () {
        expectShortFound(decode('?-//o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('?x->o : cross tail + circle head + short found', () {
        expectShortFound(decode('?x->o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.cross);
      });

      group('bidirectional + short-found normalizes to forward', () {
        // Structural decision: a bidirectional arrow with an anonymous SOURCE
        // (left-external) has no real participant on the left to mount a
        // return triangle. PlantUML's intent for found messages is an arrow
        // flowing FROM the stub TOWARD the real participant, so we collapse
        // bidirectional to forward. The head shape + tail decoration are
        // preserved so the visible glyphs from the source still appear.
        test('?<-> : plain bidirectional + short found → forward', () {
          expectShortFound(decode('?<->'),
              head: ArrowHead.filled,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid);
        });

        test('?o<->o : circle-decorated bidirectional + short found → forward',
            () {
          expectShortFound(decode('?o<->o'),
              head: ArrowHead.openCircle,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid,
              tailDecoration: EndpointDecoration.openCircle);
        });

        test('?x<->x : cross-decorated bidirectional + short found → forward',
            () {
          expectShortFound(decode('?x<->x'),
              head: ArrowHead.cross,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid,
              tailDecoration: EndpointDecoration.cross);
        });
      });

      test(
          'verbatim 21-line source with all forms produces fromShort left endpoints',
          () {
        // The verbatim source from the user bug report, line for line. Line 4
        // is the italic-label baseline; the remaining 20 lines exercise the
        // head-variant + short-found combination. All 20 must mark
        // fromExternal = fromShort with the head/tail decoded from the glyphs.
        final d = parseSequence('@startuml\n'
            'participant Alice as a\n'
            'participant Bob   as b\n'
            'a ->     b : //Long long label//\n'
            '?->      b : ""?->   ""\n'
            '?->>     b : ""?->>  ""\n'
            '?-\\      b : ""?-\\   ""\n'
            '?-\\\\     b : ""?-\\\\\\\\""\n'
            '?-/      b : ""?-/   ""\n'
            '?-//     b : ""?-//  ""\n'
            '?->x     b : ""?->x  ""\n'
            '?x->     b : ""?x->  ""\n'
            '?o->     b : ""?o->  ""\n'
            '?->o     b : ""?->o  ""\n'
            '?o->o    b : ""?o->o ""\n'
            '?<->     b : ""?<->  ""\n'
            '?o<->o   b : ""?o<->o""\n'
            '?x<->x   b : ""?x<->x""\n'
            '?->>o    b : ""?->>o ""\n'
            '?-\\o     b : ""?-\\o  ""\n'
            '?-\\\\o    b : ""?-\\\\\\\\o ""\n'
            '?-/o     b : ""?-/o  ""\n'
            '?-//o    b : ""?-//o ""\n'
            '?x->o    b : ""?x->o ""\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms, hasLength(21));
        // First message: plain `->` (no found endpoint), with the italic
        // label preserved verbatim for inline markup to interpret.
        expect(ms[0].fromExternal, isNull);
        expect(ms[0].label, '//Long long label//');
        // Every other message starts at a short-found stub.
        for (final m in ms.skip(1)) {
          expect(m.fromExternal, MessageExternal.fromShort,
              reason: 'arrow with label ${m.label} should be fromShort');
          expect(m.toExternal, isNull);
        }
        // Bidirectional arrows collapse — none should survive.
        expect(ms.where((m) => m.direction == MessageDirection.bidirectional),
            isEmpty);
        expect(d.participantsInOrder().map((p) => p.alias).toList(),
            ['a', 'b']);
      });
    });

    group('edge-lost-endpoint `]` combined with arrow-head variants (Case C)',
        () {
      // The right-side `]` lost-endpoint marker. This case ALREADY worked
      // before this task because the lexer's `consumeLostEnd` accepts both
      // `?` and `]`, and the parser strips a trailing `]` as `toEdge`. The
      // tests below are a structural smoke check that locks in the behavior.
      Message decode(String arrow) {
        final d = parseSequence('@startuml\nAlice $arrow\n@enduml\n');
        return d.events.whereType<Message>().single;
      }

      void expectEdgeLost(Message m,
          {required ArrowHead head,
          required MessageDirection direction,
          required LineStyle lineStyle,
          EndpointDecoration? tailDecoration}) {
        expect(m.toExternal, MessageExternal.toEdge);
        expect(m.fromExternal, isNull);
        expect(m.from, 'Alice');
        expect(m.head, head);
        expect(m.direction, direction);
        expect(m.lineStyle, lineStyle);
        expect(m.tailDecoration, tailDecoration);
      }

      test('->] : plain filled head + edge lost', () {
        expectEdgeLost(decode('->]'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('->>] : open head + edge lost', () {
        expectEdgeLost(decode('->>]'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'-\] : single-half head + edge lost', () {
        expectEdgeLost(decode(r'-\]'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('o->] : circle tail + filled head + edge lost', () {
        expectEdgeLost(decode('o->]'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('o->o] : circle tail + circle head + edge lost', () {
        expectEdgeLost(decode('o->o]'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('<->] : bidirectional + edge lost → forward', () {
        expectEdgeLost(decode('<->]'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('o<->o] : bidirectional with circle decorations + edge lost → forward',
          () {
        expectEdgeLost(decode('o<->o]'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('verbatim Case C 20-arrow source parses to all toEdge', () {
        final d = parseSequence('@startuml\n'
            'participant Alice as a\n'
            'participant Bob   as b\n'
            'a ->]      : ""->]   ""\n'
            'a ->>]     : ""->>]  ""\n'
            'a -\\]      : ""-\\]   ""\n'
            'a -\\\\]     : ""-\\\\\\\\]""\n'
            'a -/]      : ""-/]   ""\n'
            'a -//]     : ""-//]  ""\n'
            'a ->x]     : ""->x]  ""\n'
            'a x->]     : ""x->]  ""\n'
            'a o->]     : ""o->]  ""\n'
            'a ->o]     : ""->o]  ""\n'
            'a o->o]    : ""o->o] ""\n'
            'a <->]     : ""<->]  ""\n'
            'a o<->o]   : ""o<->o]""\n'
            'a x<->x]   : ""x<->x]""\n'
            'a ->>o]    : ""->>o] ""\n'
            'a -\\o]     : ""-\\o]  ""\n'
            'a -\\\\o]    : ""-\\\\\\\\o]""\n'
            'a -/o]     : ""-/o]  ""\n'
            'a -//o]    : ""-//o] ""\n'
            'a x->o]    : ""x->o] ""\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms, hasLength(20));
        for (final m in ms) {
          expect(m.toExternal, MessageExternal.toEdge,
              reason: 'arrow with label ${m.label} should be toEdge');
          expect(m.fromExternal, isNull);
        }
        expect(ms.where((m) => m.direction == MessageDirection.bidirectional),
            isEmpty);
        expect(d.participantsInOrder().map((p) => p.alias).toList(),
            ['a', 'b']);
      });
    });

    group('edge-found-endpoint `[` combined with arrow-head variants (Case D)',
        () {
      // Left-side mirror of Case C. Previously the parser accepted `[->`,
      // `[->>`, etc. but rejected `[x->`, `[o->`, `[<->`, `[-\`, `[-\o`, etc.
      // The lexer didn't absorb `[` for those head-variant forms, so the
      // parser saw a stray leftBracket. This group locks in 20 head-variant
      // + edge-found combinations.
      Message decode(String arrow) {
        final d = parseSequence('@startuml\n$arrow Bob\n@enduml\n');
        return d.events.whereType<Message>().single;
      }

      void expectEdgeFound(Message m,
          {required ArrowHead head,
          required MessageDirection direction,
          required LineStyle lineStyle,
          EndpointDecoration? tailDecoration}) {
        expect(m.fromExternal, MessageExternal.fromEdge);
        expect(m.toExternal, isNull);
        expect(m.to, 'Bob');
        expect(m.head, head);
        expect(m.direction, direction);
        expect(m.lineStyle, lineStyle);
        expect(m.tailDecoration, tailDecoration);
      }

      test('[-> : plain filled head + edge found', () {
        expectEdgeFound(decode('[->'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[->> : open head + edge found', () {
        expectEdgeFound(decode('[->>'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'[-\ : single-half head + edge found', () {
        expectEdgeFound(decode(r'[-\'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'[-\\ : double-half head + edge found', () {
        expectEdgeFound(decode(r'[-\\'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[-/ : half head + edge found', () {
        expectEdgeFound(decode('[-/'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[-// : double-half head + edge found', () {
        expectEdgeFound(decode('[-//'),
            head: ArrowHead.open,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[->x : cross head + edge found', () {
        expectEdgeFound(decode('[->x'),
            head: ArrowHead.cross,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[x-> : cross tail + filled head + edge found', () {
        expectEdgeFound(decode('[x->'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.cross);
      });

      test('[o-> : circle tail + filled head + edge found', () {
        expectEdgeFound(decode('[o->'),
            head: ArrowHead.filled,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('[->o : circle head + edge found', () {
        expectEdgeFound(decode('[->o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[o->o : circle tail + circle head + edge found', () {
        expectEdgeFound(decode('[o->o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.openCircle);
      });

      test('[->>o : open head with circle cap + edge found', () {
        expectEdgeFound(decode('[->>o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'[-\o : half head with circle cap + edge found', () {
        expectEdgeFound(decode(r'[-\o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test(r'[-\\o : double-half head with circle cap + edge found', () {
        expectEdgeFound(decode(r'[-\\o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[-/o : half head with circle cap + edge found', () {
        expectEdgeFound(decode('[-/o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[-//o : double-half head with circle cap + edge found', () {
        expectEdgeFound(decode('[-//o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid);
      });

      test('[x->o : cross tail + circle head + edge found', () {
        expectEdgeFound(decode('[x->o'),
            head: ArrowHead.openCircle,
            direction: MessageDirection.forward,
            lineStyle: LineStyle.solid,
            tailDecoration: EndpointDecoration.cross);
      });

      group('bidirectional + edge-found normalizes to forward', () {
        // Mirrors the `?<->` group: edge-found bidirectional collapses to
        // forward because the anonymous left source has nothing to receive a
        // return triangle. The arrow flows from the diagram edge toward the
        // real participant on the right.
        test('[<-> : bidirectional + edge found → forward', () {
          expectEdgeFound(decode('[<->'),
              head: ArrowHead.filled,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid);
        });

        test('[o<->o : circle-decorated bidirectional + edge found → forward',
            () {
          expectEdgeFound(decode('[o<->o'),
              head: ArrowHead.openCircle,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid,
              tailDecoration: EndpointDecoration.openCircle);
        });

        test('[x<->x : cross-decorated bidirectional + edge found → forward',
            () {
          expectEdgeFound(decode('[x<->x'),
              head: ArrowHead.cross,
              direction: MessageDirection.forward,
              lineStyle: LineStyle.solid,
              tailDecoration: EndpointDecoration.cross);
        });
      });

      test('verbatim Case D 20-arrow source parses to all fromEdge', () {
        final d = parseSequence('@startuml\n'
            'participant Alice as a\n'
            'participant Bob   as b\n'
            '[->      b : ""[->   ""\n'
            '[->>     b : ""[->>  ""\n'
            '[-\\      b : ""[-\\   ""\n'
            '[-\\\\     b : ""[-\\\\\\\\""\n'
            '[-/      b : ""[-/   ""\n'
            '[-//     b : ""[-//  ""\n'
            '[->x     b : ""[->x  ""\n'
            '[x->     b : ""[x->  ""\n'
            '[o->     b : ""[o->  ""\n'
            '[->o     b : ""[->o  ""\n'
            '[o->o    b : ""[o->o ""\n'
            '[<->     b : ""[<->  ""\n'
            '[o<->o   b : ""[o<->o""\n'
            '[x<->x   b : ""[x<->x""\n'
            '[->>o    b : ""[->>o ""\n'
            '[-\\o     b : ""[-\\o  ""\n'
            '[-\\\\o    b : ""[-\\\\\\\\o""\n'
            '[-/o     b : ""[-/o  ""\n'
            '[-//o    b : ""[-//o ""\n'
            '[x->o    b : ""[x->o ""\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms, hasLength(20));
        for (final m in ms) {
          expect(m.fromExternal, MessageExternal.fromEdge,
              reason: 'arrow with label ${m.label} should be fromEdge');
          expect(m.toExternal, isNull);
        }
        expect(ms.where((m) => m.direction == MessageDirection.bidirectional),
            isEmpty);
        expect(d.participantsInOrder().map((p) => p.alias).toList(),
            ['a', 'b']);
      });
    });

    group('notes', () {
      test('note left of', () {
        final d = parseSequence(
          '@startuml\nA -> B\nnote left of B : hidden detail\n@enduml\n',
        );
        final note = d.events.whereType<Note>().single;
        expect(note.position, NotePosition.leftOf);
        expect(note.participants, ['B']);
        expect(note.text, 'hidden detail');
      });

      test('note right of', () {
        final d = parseSequence(
          '@startuml\nA -> B\nnote right of A : side comment\n@enduml\n',
        );
        final note = d.events.whereType<Note>().single;
        expect(note.position, NotePosition.rightOf);
      });

      test('note over single', () {
        final d = parseSequence(
          '@startuml\nA -> B\nnote over A : floats\n@enduml\n',
        );
        final note = d.events.whereType<Note>().single;
        expect(note.position, NotePosition.over);
        expect(note.participants, ['A']);
      });

      test('note over multiple participants', () {
        final d = parseSequence(
          '@startuml\nA -> B\nnote over A, B : spans both\n@enduml\n',
        );
        final note = d.events.whereType<Note>().single;
        expect(note.participants, ['A', 'B']);
      });

      test('multi-line note left of with end note', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            'note left of A\n'
            'first line\n'
            'second line\n'
            'end note\n'
            '@enduml\n');
        final note = d.events.whereType<Note>().single;
        expect(note.position, NotePosition.leftOf);
        expect(note.participants, ['A']);
        expect(note.text, 'first line\nsecond line');
      });

      test('multi-line note over multiple participants', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            'note over A, B\n'
            'one\n'
            'two\n'
            'three\n'
            'end note\n'
            '@enduml\n');
        final note = d.events.whereType<Note>().single;
        expect(note.position, NotePosition.over);
        expect(note.participants, ['A', 'B']);
        expect(note.text, 'one\ntwo\nthree');
      });

      test('multi-line note trims each line', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            'note right of B\n'
            '  padded line\n'
            '\t\tindented\n'
            'end note\n'
            '@enduml\n');
        final note = d.events.whereType<Note>().single;
        expect(note.text, 'padded line\nindented');
      });

      test('multi-line note missing end note throws ParserException', () {
        expect(
          () => parseSequence('@startuml\n'
              'note left of A\n'
              'forgot to close\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('note across / hnote across spans all declared participants', () {
        // Verbatim source from the user-reported repro mixing the explicit
        // `note over <first>, <last>` form with the `across` shorthand. The
        // `across` notes should snapshot the participant set at parse time
        // (Alice, Bob, Charlie) so layout treats them as over-multiple notes.
        final d = parseSequence('@startuml\n'
            'Alice->Bob:m1\n'
            'Bob->Charlie:m2\n'
            'note over Alice, Charlie: Old method for note over all part. with:\\n ""note over //FirstPart, LastPart//"".\n'
            'note across: New method with:\\n""note across""\n'
            'Bob->Alice\n'
            'hnote across:Note across all part.\n'
            '@enduml\n');
        final notes = d.events.whereType<Note>().toList();
        expect(notes, hasLength(3));

        // 1) explicit `note over Alice, Charlie`
        expect(notes[0].position, NotePosition.over);
        expect(notes[0].participants, ['Alice', 'Charlie']);
        expect(notes[0].shape, NoteShape.rectangle);

        // 2) `note across` — span all participants declared so far
        expect(notes[1].position, NotePosition.over);
        expect(notes[1].participants, ['Alice', 'Bob', 'Charlie']);
        expect(notes[1].shape, NoteShape.rectangle);

        // 3) `hnote across` — same span, hexagon shape
        expect(notes[2].position, NotePosition.over);
        expect(notes[2].participants, ['Alice', 'Bob', 'Charlie']);
        expect(notes[2].shape, NoteShape.hexagon);
      });

      test('hnote/rnote inline and multi-line forms with verbatim body', () {
        // Verbatim source from the user-reported repro covering all four
        // shape variants: inline hnote, multi-line rnote with body that
        // literally contains `"r" as rectangle` / `"h" as hexagon`, and
        // multi-line rnote/hnote with plain text bodies.
        final d = parseSequence('@startuml\n'
            'caller -> server : conReq\n'
            'hnote over caller : idle\n'
            'caller <- server : conConf\n'
            'rnote over server "r" as rectangle\n'
            '"h" as hexagon\n'
            'endrnote\n'
            'rnote over server\n'
            'this is on several lines\n'
            'endrnote\n'
            'hnote over caller\n'
            'this is on several lines\n'
            'endhnote\n'
            '@enduml\n');
        final notes = d.events.whereType<Note>().toList();
        expect(notes, hasLength(4));

        // 1) inline hnote
        expect(notes[0].position, NotePosition.over);
        expect(notes[0].participants, ['caller']);
        expect(notes[0].text, 'idle');
        expect(notes[0].shape, NoteShape.hexagon);

        // 2) multi-line rnote whose body text is literally the rest of the
        //    header line plus the next line; lexer captures the full
        //    trimmed line so the body should preserve the quoted tokens.
        expect(notes[1].position, NotePosition.over);
        expect(notes[1].participants, ['server']);
        expect(notes[1].shape, NoteShape.rectangle);
        expect(notes[1].text, '"r" as rectangle\n"h" as hexagon');

        // 3) multi-line rnote, plain body
        expect(notes[2].position, NotePosition.over);
        expect(notes[2].participants, ['server']);
        expect(notes[2].text, 'this is on several lines');
        expect(notes[2].shape, NoteShape.rectangle);

        // 4) multi-line hnote, plain body
        expect(notes[3].position, NotePosition.over);
        expect(notes[3].participants, ['caller']);
        expect(notes[3].text, 'this is on several lines');
        expect(notes[3].shape, NoteShape.hexagon);
      });

      test('standalone slash between notes parses as sync marker', () {
        // PlantUML's `/` line is a sync directive that aligns the next event
        // with the previous one at the same Y. Visual alignment is currently
        // deferred — the goal here is that the source parses without error
        // and the `/` produces no event (notes still appear in the AST).
        final d = parseSequence('@startuml\n'
            'note over Alice : initial state of Alice\n'
            '/\n'
            'note over Bob : initial state of Bob\n'
            'Bob -> Alice : hello\n'
            '@enduml\n');
        final notes = d.events.whereType<Note>().toList();
        expect(notes, hasLength(2));
        expect(notes[0].participants, ['Alice']);
        expect(notes[0].text, 'initial state of Alice');
        expect(notes[1].participants, ['Bob']);
        expect(notes[1].text, 'initial state of Bob');
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(1));
        expect(messages.single.from, 'Bob');
        expect(messages.single.to, 'Alice');
      });

      test('standalone & between messages parses as sync marker', () {
        // PlantUML teoz `&` on its own line aligns the next event with the
        // previous one at the same Y. Visual alignment is currently deferred —
        // the goal here is that the source parses without error and the `&`
        // produces no event (messages still appear in the AST).
        final d = parseSequence('@startuml\n'
            '!pragma teoz true\n'
            'Alice -> Bob : hello\n'
            '&\n'
            'Bob -> Charlie : hi\n'
            '@enduml\n');
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(2));
        expect(messages[0].from, 'Alice');
        expect(messages[0].to, 'Bob');
        expect(messages[1].from, 'Bob');
        expect(messages[1].to, 'Charlie');
      });

      test('standalone & with note left/right shorthand', () {
        // Covers two PlantUML teoz features together:
        //  * standalone `&` line preceding a message OR a note as a sync mark
        //  * `note left/right <Id>` (no `of`) shorthand for the target
        //    participant.
        final d = parseSequence('@startuml\n'
            '!pragma teoz true\n'
            'S1 ->(30) S2: msg 1\\n\n'
            '&\n'
            'S2 ->(30) S1: msg 2\n'
            'note left S1: msg\\nS2 to S1\n'
            '&\n'
            'note right S2: msg\\nS1 to S2\n'
            '@enduml\n');
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(2));
        expect(messages[0].from, 'S1');
        expect(messages[0].to, 'S2');
        expect(messages[1].from, 'S2');
        expect(messages[1].to, 'S1');
        final notes = d.events.whereType<Note>().toList();
        expect(notes, hasLength(2));
        expect(notes[0].position, NotePosition.leftOf);
        expect(notes[0].participants, ['S1']);
        expect(notes[1].position, NotePosition.rightOf);
        expect(notes[1].participants, ['S2']);
      });
    });

    group('ref over', () {
      test('ref over single participant', () {
        final d = parseSequence(
          '@startuml\nA -> B\nref over A : foo\n@enduml\n',
        );
        final ref = d.events.whereType<RefBox>().single;
        expect(ref.participants, ['A']);
        expect(ref.text, 'foo');
      });

      test('ref over multiple participants', () {
        final d = parseSequence(
          '@startuml\nA -> B\nref over A, B, C : bar\n@enduml\n',
        );
        final ref = d.events.whereType<RefBox>().single;
        expect(ref.participants, ['A', 'B', 'C']);
        expect(ref.text, 'bar');
      });

      test('ref without over throws ParserException', () {
        expect(
          () => parseSequence('@startuml\nref X : foo\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('multi-line ref over block with end ref', () {
        final d = parseSequence(
          '@startuml\n'
          'participant Alice\n'
          'actor Bob\n'
          'ref over Alice, Bob : init\n'
          'Alice -> Bob : hello\n'
          'ref over Bob\n'
          'This can be on several lines\n'
          'end ref\n'
          '@enduml\n',
        );
        final refs = d.events.whereType<RefBox>().toList();
        expect(refs, hasLength(2));
        expect(refs[0].participants, ['Alice', 'Bob']);
        expect(refs[0].text, 'init');
        expect(refs[1].participants, ['Bob']);
        expect(refs[1].text, 'This can be on several lines');
      });
    });

    group('activate/deactivate', () {
      test('activate and deactivate produce events', () {
        final d = parseSequence(
          '@startuml\nA -> B\nactivate B\nB --> A\ndeactivate B\n@enduml\n',
        );
        expect(d.events.whereType<Activate>().single.participant, 'B');
        expect(d.events.whereType<Deactivate>().single.participant, 'B');
      });
    });

    group('inline activation suffixes', () {
      test('"++" emits Message then Activate(to)', () {
        final d = parseSequence('@startuml\nA -> B ++\n@enduml\n');
        expect(d.events, hasLength(2));
        final m = d.events[0] as Message;
        expect(m.from, 'A');
        expect(m.to, 'B');
        expect(m.activation, ActivationSuffix.activateTarget);
        final act = d.events[1] as Activate;
        expect(act.participant, 'B');
      });

      test('"--" emits Message then Deactivate(from)', () {
        final d = parseSequence('@startuml\nB --> A --\n@enduml\n');
        expect(d.events, hasLength(2));
        final m = d.events[0] as Message;
        expect(m.activation, ActivationSuffix.deactivateSource);
        final deact = d.events[1] as Deactivate;
        expect(deact.participant, 'B');
      });

      test('"**" emits Message then Create(to)', () {
        final d = parseSequence('@startuml\nA -> B **\n@enduml\n');
        expect(d.events, hasLength(2));
        final m = d.events[0] as Message;
        expect(m.activation, ActivationSuffix.createTarget);
        final create = d.events[1] as Create;
        expect(create.participant, 'B');
      });

      test('"!!" emits Message then Destroy(to)', () {
        final d = parseSequence('@startuml\nB -> A !!\n@enduml\n');
        expect(d.events, hasLength(2));
        final m = d.events[0] as Message;
        expect(m.activation, ActivationSuffix.destroyTarget);
        final destroy = d.events[1] as Destroy;
        expect(destroy.participant, 'A');
      });

      test('suffix before label is accepted', () {
        final d = parseSequence('@startuml\nA -> B ++ : start\n@enduml\n');
        final m = d.events[0] as Message;
        expect(m.label, 'start');
        expect(m.activation, ActivationSuffix.activateTarget);
      });

      test('suffix between arrow and target is rejected', () {
        expect(
          () => parseSequence('@startuml\nA -> ++ B\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('stray suffix at start of line is rejected', () {
        expect(
          () => parseSequence('@startuml\n++\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('chained "--++" deactivates source then activates target', () {
        // Verbatim source from the bug report: extra whitespace between
        // tokens, plus a chained `--++` suffix. The full event stream must
        // be Message(alice->bob) + Activate(bob),
        //    Message(bob->charlie) + Deactivate(bob) + Activate(charlie),
        //    Message(charlie-->alice dashed) + Deactivate(charlie).
        final d = parseSequence('@startuml\n'
            'alice   ->  bob     ++   : hello1\n'
            'bob     ->  charlie --++ : hello2\n'
            'charlie --> alice   --   : ok\n'
            '@enduml\n');
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(3));
        // Third message must remain a dashed forward arrow (NOT a return).
        expect(messages[2].from, 'charlie');
        expect(messages[2].to, 'alice');
        expect(messages[2].lineStyle, LineStyle.dashed);
        expect(messages[2].direction, MessageDirection.forward);

        // Full event sequence including secondary events.
        final kinds = d.events.map((e) => e.runtimeType.toString()).toList();
        expect(kinds, [
          'Message',     // alice -> bob ++
          'Activate',    //   -> Activate(bob)
          'Message',     // bob -> charlie --++
          'Deactivate',  //   -> Deactivate(bob)
          'Activate',    //   -> Activate(charlie)
          'Message',     // charlie --> alice --
          'Deactivate',  //   -> Deactivate(charlie)
        ]);
        final acts = d.events.whereType<Activate>().toList();
        expect(acts.map((a) => a.participant).toList(), ['bob', 'charlie']);
        final deacts = d.events.whereType<Deactivate>().toList();
        expect(deacts.map((d) => d.participant).toList(),
            ['bob', 'charlie']);
        // The chained `--++` message records the target-side effect in the
        // legacy single-slot field for backward compatibility.
        expect(messages[1].activation, ActivationSuffix.activateTarget);
      });

      test('chained "++--" is accepted (reverse order)', () {
        // Same combination as `--++` but written in the opposite order:
        // target-activate first, then source-deactivate. Both effects must
        // still apply.
        final d = parseSequence('@startuml\n'
            'A -> B ++-- : msg\n'
            '@enduml\n');
        final kinds = d.events.map((e) => e.runtimeType.toString()).toList();
        // Emission order is fixed (Deactivate(source) before Activate(target))
        // regardless of the textual order of the two suffixes.
        expect(kinds, ['Message', 'Deactivate', 'Activate']);
        expect(d.events.whereType<Deactivate>().single.participant, 'A');
        expect(d.events.whereType<Activate>().single.participant, 'B');
      });

      test('"--++" pops the matching call-stack frame for the source', () {
        // alice ++ pushes (alice,bob). The chained --++ on the next call
        // deactivates bob (which must pop the (alice,bob) frame) and pushes
        // (bob,charlie). A subsequent `return` must therefore unwind to bob,
        // not to alice.
        final d = parseSequence('@startuml\n'
            'alice -> bob ++ : hello1\n'
            'bob -> charlie --++ : hello2\n'
            'return done\n'
            '@enduml\n');
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(3));
        final ret = messages.last;
        expect(ret.direction, MessageDirection.backward);
        expect(ret.from, 'charlie');
        expect(ret.to, 'bob');
        expect(ret.label, 'done');
      });

      test('duplicate "--" suffix is rejected', () {
        expect(
          () => parseSequence('@startuml\nA -> B -- --\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('conflicting "++" + "**" suffix is rejected', () {
        expect(
          () => parseSequence('@startuml\nA -> B ++ **\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });
    });

    group('autoactivate', () {
      test('autoactivate off (default) leaves return tied to last forward', () {
        final d = parseSequence('@startuml\n'
            'A -> B : call\n'
            'return ok\n'
            '@enduml\n');
        expect(d.autoactivate, isFalse);
        // No implicit Activate emitted.
        expect(d.events.whereType<Activate>(), isEmpty);
        // Single explicit return -> reverse message + Deactivate(B).
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(2));
        expect(messages[1].from, 'B');
        expect(messages[1].to, 'A');
        expect(messages[1].direction, MessageDirection.backward);
      });

      test('autoactivate on sets the flag and emits implicit Activate', () {
        final d = parseSequence('@startuml\n'
            'autoactivate on\n'
            'A -> B : hello\n'
            '@enduml\n');
        expect(d.autoactivate, isTrue);
        final acts = d.events.whereType<Activate>().toList();
        expect(acts, hasLength(1));
        expect(acts.single.participant, 'B');
      });

      test('return unwinds the call stack to the original caller', () {
        final d = parseSequence('@startuml\n'
            'autoactivate on\n'
            'alice -> bob : hello\n'
            'bob -> bob : self call\n'
            'bill -> bob #005500 : hello from thread 2\n'
            'bob -> george ** : create\n'
            'return done in thread 2\n'
            'return rc\n'
            'bob -> george !! : delete\n'
            'return success\n'
            '@enduml\n');
        expect(d.autoactivate, isTrue);
        final messages = d.events.whereType<Message>().toList();
        // 4 forward calls + 3 returns + 1 destroy call = 8 messages.
        expect(messages, hasLength(8));
        // The three returns must close the stack in LIFO order, ignoring
        // self-calls (which don't push) and destroy-calls (which don't push).
        final returns = messages.where((m) => m.lineStyle == LineStyle.dashed).toList();
        expect(returns, hasLength(3));
        expect(returns[0].from, 'george');
        expect(returns[0].to, 'bob');
        expect(returns[0].label, 'done in thread 2');
        expect(returns[1].from, 'bob');
        expect(returns[1].to, 'bill');
        expect(returns[1].label, 'rc');
        // After the destroy, the only remaining frame is (alice, bob), so
        // `return success` must travel back to alice.
        expect(returns[2].from, 'bob');
        expect(returns[2].to, 'alice');
        expect(returns[2].label, 'success');
      });

      test('autoactivate carries the per-message color into Activate', () {
        final d = parseSequence('@startuml\n'
            'autoactivate on\n'
            'bill -> bob #005500 : hi\n'
            '@enduml\n');
        final act = d.events.whereType<Activate>().single;
        expect(act.participant, 'bob');
        expect(act.color, const Color(0xFF005500));
      });

      test('autoactivate skips push and implicit activate for self calls', () {
        final d = parseSequence('@startuml\n'
            'autoactivate on\n'
            'A -> A : self\n'
            'return done\n'
            '@enduml\n');
        // Self-call neither pushes a stack frame nor emits an implicit
        // Activate, so the `return` should fall back to the last-forward
        // heuristic and produce a reverse self-message (A -> A backward).
        expect(d.events.whereType<Activate>(), isEmpty);
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(2));
        expect(messages[1].direction, MessageDirection.backward);
        expect(messages[1].from, 'A');
        expect(messages[1].to, 'A');
      });

      test('autoactivate off disables implicit activation', () {
        final d = parseSequence('@startuml\n'
            'autoactivate on\n'
            'A -> B : on\n'
            'autoactivate off\n'
            'A -> B : off\n'
            '@enduml\n');
        // Only the first forward call should produce an implicit Activate.
        final acts = d.events.whereType<Activate>().toList();
        expect(acts, hasLength(1));
        expect(acts.single.participant, 'B');
        expect(d.autoactivate, isFalse);
      });

      test('explicit ++ pushes a call-stack frame so return unwinds it', () {
        final d = parseSequence('@startuml\n'
            'A -> B ++ : call\n'
            'return ok\n'
            '@enduml\n');
        expect(d.autoactivate, isFalse);
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(2));
        // The forward `++` push plus the matching return must aim at the
        // ++ caller (A), not the legacy last-forward heuristic.
        expect(messages[1].from, 'B');
        expect(messages[1].to, 'A');
        expect(messages[1].direction, MessageDirection.backward);
        expect(messages[1].label, 'ok');
        // Activate(B) from ++ then Deactivate(B) from return.
        final acts = d.events.whereType<Activate>().toList();
        expect(acts, hasLength(1));
        expect(acts.single.participant, 'B');
        final deacts = d.events.whereType<Deactivate>().toList();
        expect(deacts, hasLength(1));
        expect(deacts.single.participant, 'B');
      });

      test('explicit ++/**/!! with chained returns and color after suffix', () {
        // Verbatim user source from the bug report. Covers:
        //   - explicit ++ activation pushing onto the call stack while
        //     autoactivate is off
        //   - self-call under explicit ++ (still pushes — user opted in)
        //   - double space between ++ and #005500 (lexer/parser tolerance)
        //   - ** creates george and pushes a frame
        //   - !! destroys george and does NOT push
        //   - chained `return` unwinding the stack in LIFO order
        final d = parseSequence('@startuml\n'
            'alice -> bob ++ : hello\n'
            'bob -> bob ++ : self call\n'
            'bob -> bib ++  #005500 : hello\n'
            'bob -> george ** : create\n'
            'return done\n'
            'return rc\n'
            'bob -> george !! : delete\n'
            'return success\n'
            '@enduml\n');
        expect(d.autoactivate, isFalse);
        // Four forward calls (++,++,++,**) + three returns + one !! call
        // = 8 messages total.
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(8));
        // The double space + color-after-suffix line must keep the color.
        expect(messages[2].from, 'bob');
        expect(messages[2].to, 'bib');
        expect(messages[2].color, const Color(0xFF005500));
        expect(messages[2].activation, ActivationSuffix.activateTarget);
        // The three `return`s should unwind in LIFO order:
        //   stack just before first return: (alice,bob),(bob,bob),(bob,bib),(bob,george)
        //   return done  → pops (bob, george) -> george → bob
        //   return rc    → pops (bob, bib)    -> bib    → bob
        //   then `bob -> george !!`           — does NOT push
        //   return success → pops (bob, bob)  -> bob    → bob (self return)
        final returns =
            messages.where((m) => m.direction == MessageDirection.backward).toList();
        expect(returns, hasLength(3));
        expect(returns[0].from, 'george');
        expect(returns[0].to, 'bob');
        expect(returns[0].label, 'done');
        expect(returns[1].from, 'bib');
        expect(returns[1].to, 'bob');
        expect(returns[1].label, 'rc');
        expect(returns[2].from, 'bob');
        expect(returns[2].to, 'bob');
        expect(returns[2].label, 'success');
        // !! emits Destroy(george).
        expect(d.events.whereType<Destroy>().single.participant, 'george');
        // ** emits Create(george).
        expect(d.events.whereType<Create>().single.participant, 'george');
        // Explicit ++ on three non-self calls (bob, bib) plus the self call
        // emit Activate events. ** does NOT add an implicit Activate when
        // autoactivate is off.
        final acts = d.events.whereType<Activate>().toList();
        // ++ on bob (from alice), ++ on bob (from bob self), ++ on bib.
        expect(acts.map((a) => a.participant).toList(), ['bob', 'bob', 'bib']);
        // The bib activation carries the #005500 color through.
        expect(acts[2].color, const Color(0xFF005500));
      });
    });

    group('hide unlinked', () {
      test('default is false', () {
        final d = parseSequence('@startuml\n'
            'participant Alice\n'
            'participant Bob\n'
            'Alice -> Bob : hi\n'
            '@enduml\n');
        expect(d.hideUnlinked, isFalse);
      });

      test('hide unlinked sets the flag', () {
        final d = parseSequence('@startuml\n'
            'hide unlinked\n'
            'participant Alice\n'
            'participant Bob\n'
            'participant Carol\n'
            'Alice -> Bob : hello\n'
            '@enduml\n');
        expect(d.hideUnlinked, isTrue);
        // Carol is still parsed as a declared participant — the filter is
        // applied at render time, not by mutating the AST.
        expect(d.participants.map((p) => p.alias).toList(),
            ['Alice', 'Bob', 'Carol']);
      });

      test('hide unlinked is order-independent (after participants)', () {
        final d = parseSequence('@startuml\n'
            'participant Alice\n'
            'participant Bob\n'
            'participant Carol\n'
            'Alice -> Bob : hello\n'
            'hide unlinked\n'
            '@enduml\n');
        expect(d.hideUnlinked, isTrue);
      });

      test('other hide variants do not set hideUnlinked', () {
        final d = parseSequence('@startuml\n'
            'hide footbox\n'
            'Alice -> Bob : hi\n'
            '@enduml\n');
        expect(d.hideUnlinked, isFalse);
      });

      test('hide footbox sets the hideFootbox flag', () {
        final d = parseSequence('@startuml\n'
            'actor Alice\n'
            'actor Bob\n'
            'Alice -> Bob : hello\n'
            'hide footbox\n'
            '@enduml\n');
        expect(d.hideFootbox, isTrue);
      });

      test('actorStyle awesome is captured on the diagram', () {
        final d = parseSequence('@startuml\n'
            'skinparam actorStyle awesome\n'
            'actor Alice\n'
            'actor Bob\n'
            'Alice -> Bob : hello\n'
            'hide footbox\n'
            '@enduml\n');
        expect(d.actorStyle, 'awesome');
        expect(d.hideFootbox, isTrue);
      });

      test('linkedAliases includes only Message endpoints', () {
        final d = parseSequence('@startuml\n'
            'hide unlinked\n'
            'participant Alice\n'
            'participant Bob\n'
            'participant Carol\n'
            'activate Carol\n'
            'Alice -> Bob : hello\n'
            'deactivate Carol\n'
            '@enduml\n');
        // Carol is referenced only by activate/deactivate, so she's NOT
        // linked. This is the strict interpretation called out in the spec.
        expect(d.linkedAliases(), {'Alice', 'Bob'});
      });

      test('create syntax (**) links the created participant', () {
        // Per spec: a participant created via `**` IS linked because the
        // create message references it as a target.
        final d = parseSequence('@startuml\n'
            'hide unlinked\n'
            'Alice -> Bob ** : new\n'
            '@enduml\n');
        expect(d.linkedAliases(), containsAll(['Alice', 'Bob']));
      });

      test('linkedAliases recurses into group branches', () {
        final d = parseSequence('@startuml\n'
            'hide unlinked\n'
            'alt happy\n'
            'Alice -> Bob : ok\n'
            'else sad\n'
            'Alice -> Carol : err\n'
            'end\n'
            '@enduml\n');
        expect(d.linkedAliases(), {'Alice', 'Bob', 'Carol'});
      });
    });

    group('mainframe directive', () {
      test('captures the rest-of-line label verbatim incl. inline markup', () {
        final d = parseSequence('@startuml\n'
            'mainframe This is a **mainframe**\n'
            'Alice->Bob : Hello\n'
            '@enduml\n');
        // The lexer captures the post-keyword remainder as a single text
        // token so `**bold**` markers reach layout intact; layout then runs
        // it through parseInlineMarkup so "mainframe" inside `**...**`
        // renders bold.
        expect(d.mainframeLabel, 'This is a **mainframe**');
        // Sanity: the rest of the diagram still parses.
        final m = d.events.whereType<Message>().single;
        expect(m.from, 'Alice');
        expect(m.to, 'Bob');
        expect(m.label, 'Hello');
      });

      test('defaults to null when no mainframe directive is present', () {
        final d = parseSequence('@startuml\n'
            'Alice -> Bob : hi\n'
            '@enduml\n');
        expect(d.mainframeLabel, isNull);
      });

      test('bare `mainframe` (no label) sets an empty string label', () {
        // PlantUML accepts a bare `mainframe` line; layout still draws the
        // wrapping frame, just with no tab text.
        final d = parseSequence('@startuml\n'
            'mainframe\n'
            'Alice -> Bob : hi\n'
            '@enduml\n');
        expect(d.mainframeLabel, '');
      });

      test('label with bold span is parseable as inline markup', () {
        // Verify the captured label, when fed through parseInlineMarkup,
        // yields a bold subtree whose flattened text contains "mainframe".
        // The bold style is on the parent TextSpan; the literal word lives
        // in its child (text: 'mainframe'), so flatten before matching.
        final d = parseSequence('@startuml\n'
            'mainframe This is a **mainframe**\n'
            'Alice->Bob : Hi\n'
            '@enduml\n');
        final span = parseInlineMarkup(
            d.mainframeLabel!, const TextStyle(fontSize: 12));
        String flatten(InlineSpan s) {
          final buf = StringBuffer();
          if (s is TextSpan) {
            if (s.text != null) buf.write(s.text);
            final children = s.children;
            if (children != null) {
              for (final c in children) {
                buf.write(flatten(c));
              }
            }
          }
          return buf.toString();
        }

        var sawBoldMainframe = false;
        void visit(InlineSpan s) {
          if (s is TextSpan) {
            final w = s.style?.fontWeight;
            if ((w == FontWeight.bold || w == FontWeight.w700) &&
                flatten(s).contains('mainframe')) {
              sawBoldMainframe = true;
            }
            final children = s.children;
            if (children != null) {
              for (final c in children) {
                visit(c);
              }
            }
          }
        }

        visit(span);
        expect(sawBoldMainframe, isTrue,
            reason: 'expected a bold span containing "mainframe"');
      });
    });

    group('groups', () {
      test('alt with else branches', () {
        final d = parseSequence('@startuml\n'
            'alt happy path\n'
            'A -> B : ok\n'
            'else error\n'
            'A -> B : fail\n'
            'end\n'
            '@enduml\n');
        final g = d.events.whereType<Group>().single;
        expect(g.kind, GroupKind.alt);
        expect(g.branches, hasLength(2));
        expect(g.branches[0].label, 'happy path');
        expect(g.branches[1].label, 'error');
        expect(g.branches[0].events.whereType<Message>().single.label, 'ok');
      });

      test('opt single branch', () {
        final d = parseSequence('@startuml\n'
            'opt logged in\n'
            'A -> B\n'
            'end\n'
            '@enduml\n');
        final g = d.events.whereType<Group>().single;
        expect(g.kind, GroupKind.opt);
        expect(g.branches, hasLength(1));
        expect(g.branches.single.label, 'logged in');
      });

      test('loop without label', () {
        final d = parseSequence('@startuml\n'
            'loop\n'
            'A -> B\n'
            'end\n'
            '@enduml\n');
        final g = d.events.whereType<Group>().single;
        expect(g.kind, GroupKind.loop);
        expect(g.branches.single.label, isNull);
      });

      test('nested groups', () {
        final d = parseSequence('@startuml\n'
            'alt outer\n'
            'loop 3 times\n'
            'A -> B\n'
            'end\n'
            'else\n'
            'A -> B : fallback\n'
            'end\n'
            '@enduml\n');
        final outer = d.events.whereType<Group>().single;
        expect(outer.kind, GroupKind.alt);
        expect(outer.branches, hasLength(2));
        final innerLoop = outer.branches[0].events.whereType<Group>().single;
        expect(innerLoop.kind, GroupKind.loop);
        expect(innerLoop.branches.single.label, '3 times');
      });

      test('alt with tab and body colors strips color codes from labels', () {
        final d = parseSequence('@startuml\n'
            'Alice -> Bob: Authentication Request\n'
            'alt#Gold #LightBlue Successful case\n'
            '    Bob -> Alice: Authentication Accepted\n'
            'else #Pink Failure\n'
            '    Bob -> Alice: Authentication Rejected\n'
            'end\n'
            '@enduml\n');
        final g = d.events.whereType<Group>().single;
        expect(g.kind, GroupKind.alt);
        expect(g.tabColor, const Color(0xFFFFD700));
        expect(g.branches, hasLength(2));
        expect(g.branches[0].label, 'Successful case');
        expect(g.branches[0].bodyColor, const Color(0xFFADD8E6));
        expect(g.branches[1].label, 'Failure');
        expect(g.branches[1].bodyColor, const Color(0xFFFFC0CB));
      });

      test('uncolored alt/else leaves tabColor and bodyColor null', () {
        final d = parseSequence('@startuml\n'
            'alt happy path\n'
            'A -> B : ok\n'
            'else error\n'
            'A -> B : fail\n'
            'end\n'
            '@enduml\n');
        final g = d.events.whereType<Group>().single;
        expect(g.tabColor, isNull);
        expect(g.branches[0].bodyColor, isNull);
        expect(g.branches[1].bodyColor, isNull);
        expect(g.branches[0].label, 'happy path');
        expect(g.branches[1].label, 'error');
      });
    });

    group('actor kinds', () {
      test('participant keyword maps to ParticipantKind.participant', () {
        final d = parseSequence('@startuml\nparticipant Alice\n@enduml\n');
        expect(d.participants.single.kind, ParticipantKind.participant);
      });

      test('actor keyword maps to ParticipantKind.actor', () {
        final d = parseSequence('@startuml\nactor Alice\n@enduml\n');
        expect(d.participants.single.alias, 'Alice');
        expect(d.participants.single.kind, ParticipantKind.actor);
      });

      test('boundary keyword maps to ParticipantKind.boundary', () {
        final d = parseSequence('@startuml\nboundary B\n@enduml\n');
        expect(d.participants.single.kind, ParticipantKind.boundary);
      });

      test('control keyword maps to ParticipantKind.control', () {
        final d = parseSequence('@startuml\ncontrol C\n@enduml\n');
        expect(d.participants.single.kind, ParticipantKind.control);
      });

      test('entity keyword maps to ParticipantKind.entity', () {
        final d = parseSequence('@startuml\nentity E\n@enduml\n');
        expect(d.participants.single.kind, ParticipantKind.entity);
      });

      test('database keyword maps to ParticipantKind.database', () {
        final d =
            parseSequence('@startuml\ndatabase "User DB" as DB\n@enduml\n');
        expect(d.participants.single.alias, 'DB');
        expect(d.participants.single.displayName, 'User DB');
        expect(d.participants.single.kind, ParticipantKind.database);
      });

      test('collections keyword maps to ParticipantKind.collections', () {
        final d = parseSequence('@startuml\ncollections Items\n@enduml\n');
        expect(d.participants.single.kind, ParticipantKind.collections);
      });

      test('queue keyword maps to ParticipantKind.queue', () {
        final d = parseSequence('@startuml\nqueue Q as MQ\n@enduml\n');
        expect(d.participants.single.alias, 'MQ');
        expect(d.participants.single.displayName, 'Q');
        expect(d.participants.single.kind, ParticipantKind.queue);
      });

      test('mixed kinds preserve declaration order', () {
        final d = parseSequence('@startuml\n'
            'actor A\n'
            'boundary B\n'
            'database D\n'
            'A -> B\n'
            'B -> D\n'
            '@enduml\n');
        expect(d.participants.map((p) => p.kind).toList(), [
          ParticipantKind.actor,
          ParticipantKind.boundary,
          ParticipantKind.database,
        ]);
      });
    });

    group('participant rich label', () {
      test('=Title / ---- / ""SubTitle"" produces 2 labelSections', () {
        final d = parseSequence('@startuml\n'
            'participant Participant [\n'
            '    =Title\n'
            '    ----\n'
            '    ""SubTitle""\n'
            ']\n'
            'participant Bob\n'
            'Participant -> Bob\n'
            '@enduml\n');
        final p = d.participants.firstWhere((p) => p.alias == 'Participant');
        expect(p.labelSections, isNotNull);
        expect(p.labelSections!, hasLength(2));
        expect(p.labelSections![0].lines, hasLength(1));
        expect(p.labelSections![0].lines[0].text, 'Title');
        expect(p.labelSections![0].lines[0].style,
            ParticipantLabelStyle.title);
        expect(p.labelSections![1].lines, hasLength(1));
        expect(p.labelSections![1].lines[0].text, 'SubTitle');
        expect(p.labelSections![1].lines[0].style,
            ParticipantLabelStyle.code);
        final bob = d.participants.firstWhere((p) => p.alias == 'Bob');
        expect(bob.labelSections, isNull);
      });

      test('plain `[ ... ]` content without markers leaves labelSections null',
          () {
        final d = parseSequence('@startuml\n'
            'participant Foo [\n'
            '    hello world\n'
            ']\n'
            '@enduml\n');
        final foo = d.participants.single;
        expect(foo.labelSections, isNull);
        expect(foo.displayName, 'hello world');
      });
    });

    group('create/destroy keywords', () {
      test('"create A" emits Create event without adding participant', () {
        final d = parseSequence('@startuml\ncreate A\n@enduml\n');
        expect(d.participants, isEmpty);
        expect(d.events, hasLength(1));
        expect((d.events.single as Create).participant, 'A');
      });

      test('"create participant Alice" adds participant and Create event', () {
        final d =
            parseSequence('@startuml\ncreate participant Alice\n@enduml\n');
        expect(d.participants, hasLength(1));
        expect(d.participants.single.alias, 'Alice');
        expect(d.participants.single.kind, ParticipantKind.participant);
        expect(d.events, hasLength(1));
        expect((d.events.single as Create).participant, 'Alice');
      });

      test('"create actor \\"Bob\\" as B" adds actor and Create event', () {
        final d =
            parseSequence('@startuml\ncreate actor "Bob" as B\n@enduml\n');
        expect(d.participants, hasLength(1));
        expect(d.participants.single.alias, 'B');
        expect(d.participants.single.displayName, 'Bob');
        expect(d.participants.single.kind, ParticipantKind.actor);
        expect((d.events.single as Create).participant, 'B');
      });

      test('"create database DB" adds database participant', () {
        final d = parseSequence('@startuml\ncreate database DB\n@enduml\n');
        expect(d.participants, hasLength(1));
        expect(d.participants.single.alias, 'DB');
        expect(d.participants.single.kind, ParticipantKind.database);
        expect((d.events.single as Create).participant, 'DB');
      });

      test('"destroy A" emits Destroy event', () {
        final d = parseSequence('@startuml\ndestroy A\n@enduml\n');
        expect(d.participants, isEmpty);
        expect(d.events, hasLength(1));
        expect((d.events.single as Destroy).participant, 'A');
      });

      test('"create" with no name throws ParserException', () {
        expect(
          () => parseSequence('@startuml\ncreate\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('"destroy" with no name throws ParserException', () {
        expect(
          () => parseSequence('@startuml\ndestroy\n@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });
    });

    group('participant box', () {
      test('single box with one participant', () {
        final d = parseSequence('@startuml\n'
            'box "L"\n'
            'participant A\n'
            'end box\n'
            '@enduml\n');
        expect(d.boxes, hasLength(1));
        final box = d.boxes.single;
        expect(box.label, 'L');
        expect(box.color, isNull);
        expect(box.participants, hasLength(1));
        expect(box.participants.single.alias, 'A');
      });

      test('colored box with multiple kinds', () {
        final d = parseSequence('@startuml\n'
            'box "L" #LightBlue\n'
            'actor A\n'
            'database B\n'
            'end box\n'
            '@enduml\n');
        final box = d.boxes.single;
        expect(box.color, const Color(0xFFADD8E6));
        expect(box.participants.map((p) => p.kind).toList(),
            [ParticipantKind.actor, ParticipantKind.database]);
        expect(box.participants.map((p) => p.alias).toList(), ['A', 'B']);
      });

      test('hex color is decoded for box', () {
        final d = parseSequence('@startuml\n'
            'box "L" #FF8800\n'
            'participant A\n'
            'end box\n'
            '@enduml\n');
        expect(d.boxes.single.color, const Color(0xFFFF8800));
      });

      test('inner participants are also added to top-level participants', () {
        final d = parseSequence('@startuml\n'
            'box "L"\n'
            'participant A\n'
            'participant B\n'
            'end box\n'
            '@enduml\n');
        expect(d.participants.map((p) => p.alias).toList(), ['A', 'B']);
        expect(d.boxes.single.participants.map((p) => p.alias).toList(),
            ['A', 'B']);
      });

      test('participantsInOrder lists boxed participants first', () {
        final d = parseSequence('@startuml\n'
            'box "Inner"\n'
            'participant B\n'
            'end box\n'
            'participant A\n'
            '@enduml\n');
        expect(
            d.participantsInOrder().map((p) => p.alias).toList(), ['B', 'A']);
      });

      test('boxOf returns the containing box', () {
        final d = parseSequence('@startuml\n'
            'box "L"\n'
            'participant A\n'
            'end box\n'
            'participant B\n'
            '@enduml\n');
        expect(d.boxOf('A')!.label, 'L');
        expect(d.boxOf('B'), isNull);
        expect(d.boxOf('Unknown'), isNull);
      });

      test('nested box is parsed with children', () {
        final d = parseSequence('@startuml\n'
            'box "Outer"\n'
            'box "Inner"\n'
            'participant A\n'
            'end box\n'
            'end box\n'
            '@enduml\n');
        expect(d.boxes, hasLength(1));
        final outer = d.boxes.single;
        expect(outer.label, 'Outer');
        expect(outer.participants, isEmpty);
        expect(outer.children, hasLength(1));
        final inner = outer.children.single;
        expect(inner.label, 'Inner');
        expect(inner.participants.map((p) => p.alias).toList(), ['A']);
        // Inner participants are still surfaced at the top level so that
        // participantsInOrder() and message resolution see them.
        expect(d.participants.map((p) => p.alias).toList(), ['A']);
        expect(d.boxOf('A')!.label, 'Inner');
      });

      test('nested box keeps outer direct participants', () {
        final d = parseSequence('@startuml\n'
            'box "Outer" #LightBlue\n'
            'participant Bob\n'
            'box "Inner"\n'
            'participant Alice\n'
            'participant John\n'
            'end box\n'
            'end box\n'
            'participant Other\n'
            '@enduml\n');
        expect(d.participants.map((p) => p.alias).toList(),
            ['Bob', 'Alice', 'John', 'Other']);
        final outer = d.boxes.single;
        expect(outer.label, 'Outer');
        expect(outer.color, const Color(0xFFADD8E6));
        expect(outer.participants.map((p) => p.alias).toList(), ['Bob']);
        expect(outer.children, hasLength(1));
        final inner = outer.children.single;
        expect(inner.label, 'Inner');
        expect(inner.color, isNull);
        expect(inner.participants.map((p) => p.alias).toList(),
            ['Alice', 'John']);
        // Both inner participants and inner box should be enclosed by outer
        // when iterating allParticipants().
        expect(outer.allParticipants().map((p) => p.alias).toList(),
            ['Bob', 'Alice', 'John']);
      });

      test('verbatim nested box with !pragma and #LightBlue', () {
        final d = parseSequence('@startuml\n'
            '\n'
            '!pragma teoz true\n'
            'box "Internal Service" #LightBlue\n'
            'participant Bob\n'
            'box "Subteam"\n'
            'participant Alice\n'
            'participant John\n'
            'end box\n'
            '\n'
            'end box\n'
            'participant Other\n'
            '\n'
            'Bob -> Alice : hello\n'
            'Alice -> John : hello\n'
            'John -> Other: Hello\n'
            '\n'
            '@enduml\n');
        // Participant declaration order must remain Bob, Alice, John, Other.
        expect(d.participants.map((p) => p.alias).toList(),
            ['Bob', 'Alice', 'John', 'Other']);
        // Same order should hold from participantsInOrder().
        expect(d.participantsInOrder().map((p) => p.alias).toList(),
            ['Bob', 'Alice', 'John', 'Other']);
        expect(d.boxes, hasLength(1));
        final outer = d.boxes.single;
        expect(outer.label, 'Internal Service');
        expect(outer.color, const Color(0xFFADD8E6));
        expect(outer.participants.map((p) => p.alias).toList(), ['Bob']);
        expect(outer.children, hasLength(1));
        final inner = outer.children.single;
        expect(inner.label, 'Subteam');
        expect(inner.color, isNull);
        expect(inner.participants.map((p) => p.alias).toList(),
            ['Alice', 'John']);
        // Messages: Bob->Alice, Alice->John, John->Other.
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(3));
        expect(messages[0].from, 'Bob');
        expect(messages[0].to, 'Alice');
        expect(messages[1].from, 'Alice');
        expect(messages[1].to, 'John');
        expect(messages[2].from, 'John');
        expect(messages[2].to, 'Other');
      });

      test('!pragma line is consumed silently and produces no events', () {
        final d = parseSequence('@startuml\n'
            '!pragma teoz true\n'
            'A -> B : hi\n'
            '@enduml\n');
        expect(d.events.whereType<Message>(), hasLength(1));
      });

      test('#LightBlue resolves to the expected color', () {
        final d = parseSequence('@startuml\n'
            'box "L" #LightBlue\n'
            'participant A\n'
            'end box\n'
            '@enduml\n');
        expect(d.boxes.single.color, const Color(0xFFADD8E6));
      });

      test('message inside box throws ParserException', () {
        expect(
          () => parseSequence('@startuml\n'
              'box "L"\n'
              'participant A\n'
              'A -> A\n'
              'end box\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('missing end box throws ParserException', () {
        expect(
          () => parseSequence('@startuml\n'
              'box "L"\n'
              'participant A\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('box without label string throws ParserException', () {
        expect(
          () => parseSequence('@startuml\n'
              'box\n'
              'participant A\n'
              'end box\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('multiple boxes are kept in declaration order', () {
        final d = parseSequence('@startuml\n'
            'box "First"\n'
            'participant A\n'
            'end box\n'
            'box "Second"\n'
            'participant B\n'
            'end box\n'
            '@enduml\n');
        expect(d.boxes.map((b) => b.label).toList(), ['First', 'Second']);
      });
    });

    group('participant declarations', () {
      test('bare participant fixes order', () {
        final d = parseSequence(
          '@startuml\nparticipant C\nparticipant B\nA -> B\nB -> C\n@enduml\n',
        );
        expect(d.participants.map((p) => p.alias).toList(), ['C', 'B']);
        expect(d.participantsInOrder().map((p) => p.alias).toList(),
            ['C', 'B', 'A']);
      });

      test('quoted display name with alias', () {
        final d = parseSequence(
          '@startuml\nparticipant "Database" as DB\nA -> DB\n@enduml\n',
        );
        expect(d.participants.single.alias, 'DB');
        expect(d.participants.single.displayName, 'Database');
        expect(d.participants.single.label, 'Database');
      });

      test('identifier as alias form', () {
        final d = parseSequence(
          '@startuml\nparticipant Service as S\nS -> S\n@enduml\n',
        );
        expect(d.participants.single.alias, 'S');
        expect(d.participants.single.displayName, 'Service');
      });

      test('":Name:" implicit actor declaration derives alias from name', () {
        final d = parseSequence('@startuml\n:First Actor:\n@enduml\n');
        final p = d.participants.single;
        expect(p.kind, ParticipantKind.actor);
        expect(p.displayName, 'First Actor');
        expect(p.alias, 'FirstActor');
      });

      test('":Name\\nLine: as Alias" keeps \\n as newline, uses explicit alias',
          () {
        final d = parseSequence(
          '@startuml\n:Another\\nactor: as Man2\n@enduml\n',
        );
        final p = d.participants.single;
        expect(p.kind, ParticipantKind.actor);
        expect(p.displayName, 'Another\nactor');
        expect(p.alias, 'Man2');
      });

      test('"actor :Name: as Alias" uses colon-wrapped display name', () {
        final d = parseSequence(
          '@startuml\nactor :Last actor: as Person1\n@enduml\n',
        );
        final p = d.participants.single;
        expect(p.kind, ParticipantKind.actor);
        expect(p.displayName, 'Last actor');
        expect(p.alias, 'Person1');
      });

      test('plain "actor Name" still parses (regression)', () {
        final d = parseSequence('@startuml\nactor Woman3\n@enduml\n');
        final p = d.participants.single;
        expect(p.kind, ParticipantKind.actor);
        expect(p.alias, 'Woman3');
        expect(p.displayName, isNull);
      });

      test('all four inline-actor forms in one diagram', () {
        final d = parseSequence(
          '@startuml\n'
          ':First Actor:\n'
          ':Another\\nactor: as Man2\n'
          'actor Woman3\n'
          'actor :Last actor: as Person1\n'
          '@enduml\n',
        );
        expect(d.participants.map((p) => p.alias).toList(),
            ['FirstActor', 'Man2', 'Woman3', 'Person1']);
        expect(d.participants.every((p) => p.kind == ParticipantKind.actor),
            isTrue);
        expect(d.participants[0].displayName, 'First Actor');
        expect(d.participants[1].displayName, 'Another\nactor');
        expect(d.participants[2].displayName, isNull);
        expect(d.participants[3].displayName, 'Last actor');
      });
    });

    group('separators', () {
      test('"== Title ==" emits Separator(title, label)', () {
        final d = parseSequence('@startuml\n== Phase 1 ==\n@enduml\n');
        final sep = d.events.single as Separator;
        expect(sep.kind, SeparatorKind.title);
        expect(sep.label, 'Phase 1');
      });

      test('"== ==" empty title yields null label', () {
        final d = parseSequence('@startuml\n== ==\n@enduml\n');
        final sep = d.events.single as Separator;
        expect(sep.kind, SeparatorKind.title);
        expect(sep.label, isNull);
      });

      test('"||5||" emits Separator(delay, delayPixels=5)', () {
        final d = parseSequence('@startuml\n||5||\n@enduml\n');
        final sep = d.events.single as Separator;
        expect(sep.kind, SeparatorKind.delay);
        expect(sep.delayPixels, 5);
      });

      test('"||||" empty delay has null delayPixels', () {
        final d = parseSequence('@startuml\n||||\n@enduml\n');
        final sep = d.events.single as Separator;
        expect(sep.kind, SeparatorKind.delay);
        expect(sep.delayPixels, isNull);
      });

      test('"..." emits Separator(skip)', () {
        final d = parseSequence('@startuml\n...\n@enduml\n');
        final sep = d.events.single as Separator;
        expect(sep.kind, SeparatorKind.skip);
      });

      test('"--" on its own line emits Separator(dash)', () {
        final d = parseSequence('@startuml\n--\n@enduml\n');
        final sep = d.events.single as Separator;
        expect(sep.kind, SeparatorKind.dash);
      });

      test('"--" suffix after message target is preserved (not separator)', () {
        final d = parseSequence('@startuml\nB --> A --\n@enduml\n');
        expect(d.events.whereType<Separator>(), isEmpty);
        final m = d.events.whereType<Message>().single;
        expect(m.activation, ActivationSuffix.deactivateSource);
      });

      test('all four separators in one diagram', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            '== Phase 1 ==\n'
            'A -> B\n'
            '||10||\n'
            'A -> B\n'
            '...\n'
            'A -> B\n'
            '--\n'
            'A -> B\n'
            '@enduml\n');
        final seps = d.events.whereType<Separator>().toList();
        expect(seps.map((s) => s.kind).toList(), [
          SeparatorKind.title,
          SeparatorKind.delay,
          SeparatorKind.skip,
          SeparatorKind.dash,
        ]);
      });
    });

    group('style block', () {
      // `<style>...</style>` is PlantUML's CSS-like skin override. We consume
      // and ignore the entire block at the lexer level — style application is
      // deferred — so the surrounding diagram still parses normally.
      test('empty <style></style> block is skipped', () {
        final d = parseSequence('@startuml\n'
            '<style></style>\n'
            'A -> B : hi\n'
            '@enduml\n');
        expect(d.events, hasLength(1));
        final m = d.events.single as Message;
        expect(m.from, 'A');
        expect(m.to, 'B');
        expect(m.label, 'hi');
      });

      test('multiline <style> block with CSS-like body is skipped', () {
        final d = parseSequence('@startuml\n'
            '<style>\n'
            'lifeLine {\n'
            '  LineStyle 0\n'
            '}\n'
            'delay {\n'
            '  LineStyle 1-4\n'
            '}\n'
            '</style>\n'
            'Alice -> Bob : hello\n'
            'Alice <- Bob : hello\n'
            '@enduml\n');
        final msgs = d.events.whereType<Message>().toList();
        expect(msgs, hasLength(2));
        expect(msgs[0].from, 'Alice');
        expect(msgs[0].to, 'Bob');
        expect(msgs[0].direction, MessageDirection.forward);
        expect(msgs[1].from, 'Alice');
        expect(msgs[1].to, 'Bob');
        expect(msgs[1].direction, MessageDirection.backward);
      });

      test('<style> block + ... delay marker (user repro)', () {
        // Verbatim user source: the block both contains a `delay` selector and
        // is followed by a `...` delay marker. Both must parse.
        final d = parseSequence('@startuml\n'
            '<style>\n'
            'lifeLine {\n'
            '  LineStyle 0\n'
            '}\n'
            'delay {\n'
            '  LineStyle 1-4\n'
            '}\n'
            '</style>\n'
            'Alice -> Bob : hello\n'
            '...\n'
            'Alice <- Bob : hello\n'
            '@enduml\n');
        final types = d.events.map((e) => e.runtimeType).toList();
        expect(types, [Message, Separator, Message]);
        final sep = d.events[1] as Separator;
        expect(sep.kind, SeparatorKind.skip);
      });

      test('case-insensitive <STYLE> and </Style> tags', () {
        final d = parseSequence('@startuml\n'
            '<STYLE>\n'
            'anything {\n'
            '  foo bar\n'
            '}\n'
            '</Style>\n'
            'A -> B\n'
            '@enduml\n');
        expect(d.events.single, isA<Message>());
      });

      test('unterminated <style> block throws LexerException', () {
        expect(
          () => Lexer().tokenize('@startuml\n<style>\nincomplete\n@enduml\n'),
          throwsA(isA<LexerException>()),
        );
      });
    });

    group('delay marker (...)', () {
      // `...` already lowers to `Separator(kind: SeparatorKind.skip)` in this
      // engine — the AST/layout treat it as the visible delay break. These
      // tests pin the lowering so future refactors don't regress it.
      test('bare ... emits Separator(skip) with no label', () {
        final d = parseSequence('@startuml\nA -> B\n...\nB -> A\n@enduml\n');
        final sep = d.events.whereType<Separator>().single;
        expect(sep.kind, SeparatorKind.skip);
        expect(sep.label, isNull);
      });

      test('"... 5 minutes later ..." parses with label', () {
        final d = parseSequence(
            '@startuml\nA -> B\n... 5 minutes later ...\nB -> A\n@enduml\n');
        final sep = d.events.whereType<Separator>().single;
        expect(sep.kind, SeparatorKind.skip);
        expect(sep.label, '5 minutes later');
      });
    });

    group('autonumber', () {
      test('plain autonumber prepends "1 " to message labels', () {
        final d = parseSequence('@startuml\n'
            'autonumber\n'
            'A -> B : hi\n'
            '@enduml\n');
        final m = d.events.whereType<Message>().single;
        expect(m.label, '1 hi');
      });

      test('autonumber with start value, no label, becomes the label', () {
        final d = parseSequence('@startuml\n'
            'autonumber 10\n'
            'A -> B\n'
            '@enduml\n');
        final m = d.events.whereType<Message>().single;
        expect(m.label, '10');
      });

      test('autonumber start and increment', () {
        final d = parseSequence('@startuml\n'
            'autonumber 10 5\n'
            'A -> B : x\n'
            'A -> B : y\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms.map((m) => m.label).toList(), ['10 x', '15 y']);
      });

      test('autonumber with zero-padded format', () {
        final d = parseSequence('@startuml\n'
            'autonumber "[%03d]"\n'
            'A -> B : hi\n'
            '@enduml\n');
        final m = d.events.whereType<Message>().single;
        expect(m.label, '[001] hi');
      });

      test('autonumber stop pauses numbering, resume continues', () {
        final d = parseSequence('@startuml\n'
            'autonumber\n'
            'A -> B\n'
            'autonumber stop\n'
            'A -> B\n'
            'autonumber resume\n'
            'A -> B\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms.map((m) => m.label).toList(), ['1', null, '2']);
      });

      test('autonumber resume with explicit value sets the increment', () {
        // PlantUML semantics: `resume N` is the new step, counter keeps its
        // pre-resume value.
        final d = parseSequence('@startuml\n'
            'autonumber 5\n'
            'A -> B\n'
            'autonumber stop\n'
            'A -> B\n'
            'autonumber resume 100\n'
            'A -> B\n'
            'A -> B\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms.map((m) => m.label).toList(), ['5', null, '6', '106']);
      });

      test('format string without %d marker is used as a plain prefix', () {
        final d = parseSequence('@startuml\n'
            'autonumber "no marker"\n'
            'A -> B : hi\n'
            '@enduml\n');
        final m = d.events.whereType<Message>().single;
        expect(m.label, 'no marker 1 hi');
      });

      test('messages before any autonumber directive are not numbered', () {
        final d = parseSequence('@startuml\n'
            'A -> B : hello\n'
            'autonumber\n'
            'A -> B : world\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms.map((m) => m.label).toList(), ['hello', '1 world']);
      });

      test('autonumber works inside group blocks', () {
        final d = parseSequence('@startuml\n'
            'autonumber\n'
            'alt valid\n'
            'A -> B : ok\n'
            'else invalid\n'
            'A -> B : bad\n'
            'end\n'
            '@enduml\n');
        final group = d.events.whereType<Group>().single;
        final first = group.branches[0].events.whereType<Message>().single;
        final second = group.branches[1].events.whereType<Message>().single;
        expect(first.label, '1 ok');
        expect(second.label, '2 bad');
      });

      test('activation suffix does not consume autonumber for follow-up event',
          () {
        final d = parseSequence('@startuml\n'
            'autonumber\n'
            'A -> B ++ : start\n'
            '@enduml\n');
        final m = d.events.whereType<Message>().single;
        final a = d.events.whereType<Activate>().single;
        expect(m.label, '1 start');
        expect(a.participant, 'B');
      });
    });

    group('title/header/footer/caption', () {
      test('single-line title', () {
        final d =
            parseSequence('@startuml\ntitle My Diagram\nA -> B\n@enduml\n');
        expect(d.decorations.title, 'My Diagram');
      });

      test('single-line caption', () {
        final d =
            parseSequence('@startuml\ncaption Figure 1\nA -> B\n@enduml\n');
        expect(d.decorations.caption, 'Figure 1');
      });

      test('single-line header default center', () {
        final d = parseSequence('@startuml\nheader Top Bar\nA -> B\n@enduml\n');
        expect(d.decorations.header!.text, 'Top Bar');
        expect(d.decorations.header!.align, TextAlign.center);
      });

      test('single-line footer with right alignment', () {
        final d =
            parseSequence('@startuml\nfooter right Page 1\nA -> B\n@enduml\n');
        expect(d.decorations.footer!.text, 'Page 1');
        expect(d.decorations.footer!.align, TextAlign.right);
      });

      test('header left alignment', () {
        final d =
            parseSequence('@startuml\nheader left Hello\nA -> B\n@enduml\n');
        expect(d.decorations.header!.align, TextAlign.left);
      });

      test('multi-line title', () {
        final d = parseSequence('@startuml\n'
            'title\n'
            'first line\n'
            'second line\n'
            'end title\n'
            'A -> B\n'
            '@enduml\n');
        expect(d.decorations.title, 'first line\nsecond line');
      });

      test('multi-line header with alignment', () {
        final d = parseSequence('@startuml\n'
            'header right\n'
            'top right text\n'
            'second\n'
            'end header\n'
            'A -> B\n'
            '@enduml\n');
        expect(d.decorations.header!.text, 'top right text\nsecond');
        expect(d.decorations.header!.align, TextAlign.right);
      });

      test('multi-line footer', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            'footer\n'
            'bottom\n'
            'end footer\n'
            '@enduml\n');
        expect(d.decorations.footer!.text, 'bottom');
        expect(d.decorations.footer!.align, TextAlign.center);
      });

      test('duplicate title throws', () {
        expect(
          () => parseSequence('@startuml\n'
              'title First\n'
              'title Second\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('duplicate header throws', () {
        expect(
          () => parseSequence('@startuml\n'
              'header One\n'
              'header Two\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('duplicate footer throws', () {
        expect(
          () => parseSequence('@startuml\n'
              'footer One\n'
              'footer Two\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('duplicate caption throws', () {
        expect(
          () => parseSequence('@startuml\n'
              'caption One\n'
              'caption Two\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('missing end title throws', () {
        expect(
          () => parseSequence('@startuml\n'
              'title\n'
              'unterminated\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('title default null', () {
        final d = parseSequence('@startuml\nA -> B\n@enduml\n');
        expect(d.decorations.title, isNull);
        expect(d.decorations.header, isNull);
        expect(d.decorations.footer, isNull);
        expect(d.decorations.caption, isNull);
      });

      test('title with inline markup and \\n escape', () {
        final d = parseSequence('@startuml\n'
            'title __Simple__ communication example\\non several lines\n'
            'Alice -> Bob: Authentication Request\n'
            'Bob -> Alice: Authentication Response\n'
            '@enduml\n');
        // Inline markup is preserved verbatim for the renderer to consume,
        // and `\n` is normalized to a real newline so the title spans 2 lines.
        expect(d.decorations.title,
            '__Simple__ communication example\non several lines');
      });

      test('multi-line title block with inline HTML tags', () {
        // Regression test: the block form `title ... end title` must capture
        // body lines verbatim, including inline HTML markup like <u>, <i>,
        // <font color=red>, and <img:...>, without the lexer trying to
        // interpret `<...>` as arrows/generics/stereotypes.
        final d = parseSequence('@startuml\n'
            'title <u>Simple</u> communication example on <i>several</i> lines and using <font color=red>html</font>\n'
            'This is hosted by <img:sourceforge.jpg>\n'
            'end title\n'
            'Alice -> Bob: Authentication Request\n'
            'Bob -> Alice: Authentication Response\n'
            '@enduml\n');
        expect(
          d.decorations.title,
          '<u>Simple</u> communication example on <i>several</i> lines and using <font color=red>html</font>\n'
          'This is hosted by <img:sourceforge.jpg>',
        );
      });
    });

    group('newpage', () {
      test('"newpage" alone parses to NewPage(null)', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            'newpage\n'
            'A -> B\n'
            '@enduml\n');
        final pages = d.events.whereType<NewPage>().toList();
        expect(pages, hasLength(1));
        expect(pages.single.title, isNull);
      });

      test('"newpage Some title" parses to NewPage with title', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            'newpage Some title\n'
            'A -> B\n'
            '@enduml\n');
        final pages = d.events.whereType<NewPage>().toList();
        expect(pages, hasLength(1));
        expect(pages.single.title, 'Some title');
      });

      test('multiple newpage events appear in order', () {
        final d = parseSequence('@startuml\n'
            'A -> B\n'
            'newpage\n'
            'A -> B\n'
            'newpage Page Three\n'
            'A -> B\n'
            '@enduml\n');
        final pages = d.events.whereType<NewPage>().toList();
        expect(pages, hasLength(2));
        expect(pages[0].title, isNull);
        expect(pages[1].title, 'Page Three');
      });

      test('edge endpoint with cap decorations and reverse arrows', () {
        // Sequence 89 case 53: every supported edge + cap + direction combo.
        // Failure mode before the fix: `Bob <-]` and `Bob x<-]` left the
        // trailing `]` un-consumed by the lexer's `<-` body branch.
        final d = parseSequence('@startuml\n'
            'participant Alice\n'
            'participant Bob #lightblue\n'
            'Alice -> Bob\n'
            'Bob -> Carol\n'
            '...\n'
            '[-> Bob\n'
            '[o-> Bob\n'
            '[o->o Bob\n'
            '[x-> Bob\n'
            '...\n'
            '[<- Bob\n'
            '[x<- Bob\n'
            '...\n'
            'Bob ->]\n'
            'Bob ->o]\n'
            'Bob o->o]\n'
            'Bob ->x]\n'
            '...\n'
            'Bob <-]\n'
            'Bob x<-]\n'
            '@enduml\n');
        // Every message line must parse — count Messages (separators
        // contribute the `...` markers but are not Messages).
        final messages = d.events.whereType<Message>().toList();
        expect(messages.length, greaterThanOrEqualTo(14));
      });

      test('"ignore newpage" suppresses subsequent newpage events', () {
        final d = parseSequence('@startuml\n'
            'ignore newpage\n'
            'Alice -> Bob : message 1\n'
            'Alice -> Bob : message 2\n'
            'newpage\n'
            'Alice -> Bob : message 3\n'
            'Alice -> Bob : message 4\n'
            'newpage A title for the\\nlast page\n'
            'Alice -> Bob : message 5\n'
            'Alice -> Bob : message 6\n'
            '@enduml\n');
        final pages = d.events.whereType<NewPage>().toList();
        expect(pages, isEmpty);
        final messages = d.events.whereType<Message>().toList();
        expect(messages, hasLength(6));
      });
    });

    group('legend', () {
      test('parses legend with body and endlegend', () {
        final d = parseSequence('@startuml\n'
            'legend\n'
            'first line\n'
            'second line\n'
            'endlegend\n'
            'A -> B\n'
            '@enduml\n');
        expect(d.decorations.legend!.text, 'first line\nsecond line');
        expect(d.decorations.legend!.align, TextAlign.left);
      });

      test('legend right sets align', () {
        final d = parseSequence('@startuml\n'
            'legend right\n'
            'right aligned\n'
            'endlegend\n'
            'A -> B\n'
            '@enduml\n');
        expect(d.decorations.legend!.text, 'right aligned');
        expect(d.decorations.legend!.align, TextAlign.right);
      });

      test('legend center sets align', () {
        final d = parseSequence('@startuml\n'
            'legend center\n'
            'centered\n'
            'endlegend\n'
            'A -> B\n'
            '@enduml\n');
        expect(d.decorations.legend!.align, TextAlign.center);
      });

      test('two-word end legend is accepted', () {
        final d = parseSequence('@startuml\n'
            'legend\n'
            'body\n'
            'end legend\n'
            'A -> B\n'
            '@enduml\n');
        expect(d.decorations.legend!.text, 'body');
      });

      test('duplicate legend throws', () {
        expect(
          () => parseSequence('@startuml\n'
              'legend\n'
              'first\n'
              'endlegend\n'
              'legend\n'
              'second\n'
              'endlegend\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('missing endlegend throws', () {
        expect(
          () => parseSequence('@startuml\n'
              'legend\n'
              'unterminated\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
      });

      test('legend default null', () {
        final d = parseSequence('@startuml\nA -> B\n@enduml\n');
        expect(d.decorations.legend, isNull);
      });
    });

    group('skinparam', () {
      test('inline backgroundColor parses to a Color', () {
        final d = parseSequence(
            '@startuml\nskinparam backgroundColor #FFEEDD\n@enduml\n');
        expect(d.decorations.skin.backgroundColor, const Color(0xFFFFEEDD));
      });

      test('inline named color is accepted', () {
        final d = parseSequence(
            '@startuml\nskinparam sequenceArrowColor red\n@enduml\n');
        expect(d.decorations.skin.sequenceArrowColor, const Color(0xFFFF0000));
      });

      test('inline defaultFontSize parses to a double', () {
        final d =
            parseSequence('@startuml\nskinparam defaultFontSize 18\n@enduml\n');
        expect(d.decorations.skin.defaultFontSize, 18.0);
      });

      test('keys are matched case-insensitively', () {
        final d = parseSequence(
            '@startuml\nskinparam NoteBackgroundColor #ABCDEF\n@enduml\n');
        expect(d.decorations.skin.noteBackgroundColor, const Color(0xFFABCDEF));
      });

      test('block form without prefix parses each pair', () {
        final d = parseSequence('@startuml\n'
            'skinparam {\n'
            '  backgroundColor #112233\n'
            '  defaultFontSize 14\n'
            '}\n'
            '@enduml\n');
        expect(d.decorations.skin.backgroundColor, const Color(0xFF112233));
        expect(d.decorations.skin.defaultFontSize, 14.0);
      });

      test('block form with sequence prefix concatenates keys', () {
        final d = parseSequence('@startuml\n'
            'skinparam sequence {\n'
            '  ArrowColor #Red\n'
            '  LifeLineBackgroundColor #LightGray\n'
            '}\n'
            '@enduml\n');
        expect(d.decorations.skin.sequenceArrowColor, const Color(0xFFFF0000));
        expect(d.decorations.skin.sequenceLifeLineBackgroundColor, const Color(0xFFD3D3D3));
      });

      test('participant prefix block sets participant colors', () {
        final d = parseSequence('@startuml\n'
            'skinparam participant {\n'
            '  BackgroundColor #EEEEEE\n'
            '  BorderColor Black\n'
            '}\n'
            '@enduml\n');
        expect(d.decorations.skin.participantBackgroundColor, const Color(0xFFEEEEEE));
        expect(d.decorations.skin.participantBorderColor, const Color(0xFF000000));
      });

      test('unknown inline key is silently ignored', () {
        expect(
          () => parseSequence(
              '@startuml\nskinparam totallyMadeUpKey #FF00FF\n@enduml\n'),
          returnsNormally,
        );
        final d = parseSequence(
            '@startuml\nskinparam totallyMadeUpKey #FF00FF\n@enduml\n');
        expect(d.decorations.skin.backgroundColor, isNull);
        expect(d.decorations.skin.sequenceArrowColor, isNull);
      });

      test('unknown block key is silently ignored', () {
        expect(
          () => parseSequence('@startuml\n'
              'skinparam sequence {\n'
              '  BogusKey #FF00FF\n'
              '  ArrowColor #Blue\n'
              '}\n'
              '@enduml\n'),
          returnsNormally,
        );
        final d = parseSequence('@startuml\n'
            'skinparam sequence {\n'
            '  BogusKey #FF00FF\n'
            '  ArrowColor #Blue\n'
            '}\n'
            '@enduml\n');
        expect(d.decorations.skin.sequenceArrowColor, const Color(0xFF0000FF));
      });

      test('skin defaults are all null when no skinparam is used', () {
        final d = parseSequence('@startuml\nA -> B\n@enduml\n');
        expect(d.decorations.skin.backgroundColor, isNull);
        expect(d.decorations.skin.defaultFontSize, isNull);
        expect(d.decorations.skin.sequenceArrowColor, isNull);
        expect(d.decorations.skin.sequenceLifeLineBackgroundColor, isNull);
        expect(d.decorations.skin.participantBackgroundColor, isNull);
        expect(d.decorations.skin.participantBorderColor, isNull);
        expect(d.decorations.skin.noteBackgroundColor, isNull);
        expect(d.decorations.skin.noteBorderColor, isNull);
      });
    });
  });

  group('class diagram', () {
    ClassDiagram parseClass(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as ClassDiagram;
    }

    test('parses a single empty class', () {
      final d = parseClass('@startuml\nclass Foo\n@enduml\n');
      expect(d.classes, hasLength(1));
      expect(d.classes.single.name, 'Foo');
      expect(d.classes.single.kind, ClassKind.class_);
      expect(d.classes.single.members, isEmpty);
      expect(d.relationships, isEmpty);
    });

    test('parses class with fields and methods', () {
      final d = parseClass('@startuml\n'
          'class Animal {\n'
          '  +name: String\n'
          '  -age: int\n'
          '  +eat()\n'
          '  +sleep(): void\n'
          '}\n'
          '@enduml\n');
      expect(d.classes, hasLength(1));
      final c = d.classes.single;
      expect(c.members, hasLength(4));
      final f1 = c.members[0] as Field;
      expect(f1.name, 'name');
      expect(f1.type, 'String');
      expect(f1.visibility, Visibility.public);
      final f2 = c.members[1] as Field;
      expect(f2.visibility, Visibility.private);
      expect(f2.name, 'age');
      expect(f2.type, 'int');
      final m1 = c.members[2] as Method;
      expect(m1.name, 'eat');
      expect(m1.visibility, Visibility.public);
      final m2 = c.members[3] as Method;
      expect(m2.name, 'sleep');
      expect(m2.returnType, 'void');
    });

    test('parses protected and package-private visibilities', () {
      final d = parseClass('@startuml\n'
          'class X {\n'
          '  #protectedField\n'
          '  ~pkgPrivate: int\n'
          '}\n'
          '@enduml\n');
      final members = d.classes.single.members;
      expect((members[0] as Field).visibility, Visibility.protected);
      expect((members[1] as Field).visibility, Visibility.packagePrivate);
    });

    test('captures every visibility prefix per member kind', () {
      // Mirrors the verbatim source from the visibility-icons rendering bug:
      // each member has a distinct prefix and the parser must preserve the
      // (visibility, field-vs-method) tuple downstream so the layout can pick
      // the right shape primitive.
      final d = parseClass('@startuml\n'
          'class Dummy {\n'
          '-field1\n'
          '#field2\n'
          '~method1()\n'
          '+method2()\n'
          '}\n'
          '@enduml\n');
      final members = d.classes.single.members;
      expect(members, hasLength(4));
      final f1 = members[0] as Field;
      expect(f1.name, 'field1');
      expect(f1.visibility, Visibility.private);
      final f2 = members[1] as Field;
      expect(f2.name, 'field2');
      expect(f2.visibility, Visibility.protected);
      final m1 = members[2] as Method;
      expect(m1.name, 'method1');
      expect(m1.visibility, Visibility.packagePrivate);
      final m2 = members[3] as Method;
      expect(m2.name, 'method2');
      expect(m2.visibility, Visibility.public);
    });

    test('parses static and abstract modifiers', () {
      final d = parseClass('@startuml\n'
          'abstract class Shape {\n'
          '  {static} +instances: int\n'
          '  {abstract} +area(): double\n'
          '}\n'
          '@enduml\n');
      final c = d.classes.single;
      expect(c.kind, ClassKind.abstractClass);
      final f = c.members[0] as Field;
      expect(f.isStatic, isTrue);
      final m = c.members[1] as Method;
      expect(m.isAbstract, isTrue);
      expect(m.returnType, 'double');
    });

    test('parses interface', () {
      final d = parseClass('@startuml\n'
          'interface Drawable {\n'
          '  +draw()\n'
          '}\n'
          '@enduml\n');
      final c = d.classes.single;
      expect(c.kind, ClassKind.interface);
      expect(c.name, 'Drawable');
    });

    test('parses enum with values', () {
      final d = parseClass('@startuml\n'
          'enum Color {\n'
          '  RED\n'
          '  GREEN\n'
          '  BLUE\n'
          '}\n'
          '@enduml\n');
      final c = d.classes.single;
      expect(c.kind, ClassKind.enum_);
      expect(c.members, hasLength(3));
      expect((c.members[0] as EnumValue).name, 'RED');
      expect((c.members[2] as EnumValue).name, 'BLUE');
    });

    test('parses member divider lines', () {
      final d = parseClass('@startuml\n'
          'class X {\n'
          '  +a\n'
          '  --\n'
          '  +b\n'
          '  ..\n'
          '  +c\n'
          '  ==\n'
          '  +d\n'
          '}\n'
          '@enduml\n');
      final members = d.classes.single.members;
      expect((members[1] as MemberDivider).kind, DividerKind.solid);
      expect((members[3] as MemberDivider).kind, DividerKind.dashed);
      expect((members[5] as MemberDivider).kind, DividerKind.doubleLine);
    });

    test('parses inheritance relationship A <|-- B', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A <|-- B\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.from, 'A');
      expect(r.to, 'B');
      expect(r.kind, RelationshipKind.inheritance);
    });

    test('parses realization A <|.. B', () {
      final d = parseClass('@startuml\n'
          'interface A\n'
          'class B\n'
          'A <|.. B\n'
          '@enduml\n');
      expect(d.relationships.single.kind, RelationshipKind.realization);
    });

    test('parses composition A *-- B', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A *-- B\n'
          '@enduml\n');
      expect(d.relationships.single.kind, RelationshipKind.composition);
    });

    test('parses aggregation A o-- B', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A o-- B\n'
          '@enduml\n');
      expect(d.relationships.single.kind, RelationshipKind.aggregation);
    });

    test('parses directed association A --> B', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A --> B\n'
          '@enduml\n');
      expect(d.relationships.single.kind, RelationshipKind.directedAssociation);
    });

    test('parses association A -- B', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A -- B\n'
          '@enduml\n');
      expect(d.relationships.single.kind, RelationshipKind.association);
    });

    test('parses dependency A ..> B', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A ..> B\n'
          '@enduml\n');
      expect(d.relationships.single.kind, RelationshipKind.dependency);
    });

    test('parses link A .. B', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A .. B\n'
          '@enduml\n');
      expect(d.relationships.single.kind, RelationshipKind.link);
    });

    test('reversed inheritance A --|> B reverses ends', () {
      final d = parseClass('@startuml\n'
          'class A\n'
          'class B\n'
          'A --|> B\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.kind, RelationshipKind.inheritance);
      expect(r.from, 'B');
      expect(r.to, 'A');
    });

    test('parses multiplicities and label', () {
      final d = parseClass('@startuml\n'
          'class Animal\n'
          'class Leg\n'
          'Animal "1" *-- "*" Leg : has\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.kind, RelationshipKind.composition);
      expect(r.fromMultiplicity, '1');
      expect(r.toMultiplicity, '*');
      expect(r.label, 'has');
    });

    test('parses class with header stereotype', () {
      final d = parseClass('@startuml\n'
          'class Order <<Aggregate>>\n'
          '@enduml\n');
      expect(d.classes.single.stereotype, 'Aggregate');
    });

    test('parses class with generics on header', () {
      final d = parseClass('@startuml\n'
          'class AggregateRoot<ID>\n'
          '@enduml\n');
      expect(d.classes.single.generics, 'ID');
    });

    test('parses nested generics in interface header', () {
      final d = parseClass('@startuml\n'
          'interface Repository<T extends AggregateRoot<ID>, ID>\n'
          '@enduml\n');
      expect(d.classes.single.kind, ClassKind.interface);
      expect(d.classes.single.generics,
          'T extends AggregateRoot<ID>, ID');
    });

    test('parses record keyword as record kind', () {
      final d = parseClass('@startuml\n'
          'record Money {\n'
          '  amount: BigDecimal\n'
          '  currency: Currency\n'
          '}\n'
          '@enduml\n');
      expect(d.classes.single.kind, ClassKind.record_);
      expect(d.classes.single.members, hasLength(2));
    });

    test('silently consumes hide directives', () {
      final d = parseClass('@startuml\n'
          'hide empty members\n'
          'hide circle\n'
          'class Foo\n'
          '@enduml\n');
      expect(d.classes, hasLength(1));
    });

    test('parses free note with alias', () {
      final d = parseClass('@startuml\n'
          'class Foo\n'
          'note "hello" as N1\n'
          'N1 .. Foo\n'
          '@enduml\n');
      expect(d.freeNotes, hasLength(1));
      expect(d.freeNotes.single.alias, 'N1');
      expect(d.freeNotes.single.text, 'hello');
      expect(d.freeNotes.single.attachedTo, isNull);
      expect(d.relationships.single.from, 'N1');
      expect(d.relationships.single.to, 'Foo');
    });

    test('parses multi-line note attached to a class', () {
      final d = parseClass('@startuml\n'
          'class Order\n'
          'note right of Order\n'
          '  invariant 1\n'
          '  invariant 2\n'
          'end note\n'
          '@enduml\n');
      expect(d.freeNotes, hasLength(1));
      expect(d.freeNotes.single.attachedTo, 'Order');
      expect(d.freeNotes.single.text, contains('invariant 1'));
    });

    test('package wrapper flattens its body into the class diagram', () {
      final d = parseClass('@startuml\n'
          'package "domain" <<Layer>> {\n'
          '  class Foo\n'
          '  class Bar\n'
          '}\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name), ['Foo', 'Bar']);
    });

    test('drops generics on relationship endpoints', () {
      final d = parseClass('@startuml\n'
          'interface Repository<T>\n'
          'class OrderRepository\n'
          'Repository<T> <|.. OrderRepository\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.from, 'Repository');
      expect(r.to, 'OrderRepository');
      expect(r.kind, RelationshipKind.realization);
    });

    test('accepts extensive element-type matrix (source 31)', () {
      final d = parseClass('@startuml\n'
          'hide empty members\n'
          'abstract abstract\n'
          'abstract class "abstract class"\n'
          'annotation annotation\n'
          'circle circle ()\n'
          'circle_short_form\n'
          'class class\n'
          'class class_stereo <<stereotype>>\n'
          'dataclass dataclass\n'
          'diamond diamond <>\n'
          'diamond_short_form\n'
          'entity entity\n'
          'enum enum\n'
          'exception exception\n'
          'interface interface\n'
          'metaclass metaclass\n'
          'protocol protocol\n'
          'record record\n'
          'stereotype stereotype\n'
          'struct struct\n'
          '@enduml\n');
      expect(d.classes.length, greaterThanOrEqualTo(15));
    });

    test('accepts label text containing < and > (source 32)', () {
      final d = parseClass('@startuml\n'
          'class Car\n'
          'Driver - Car : drives >\n'
          'Car *- Wheel : have 4 >\n'
          'Car -- Person : < owns\n'
          '@enduml\n');
      expect(d.relationships, hasLength(3));
      // All labels are preserved (or at least the rels parse).
      expect(d.classes.map((c) => c.name),
          containsAll(['Car', 'Driver', 'Wheel', 'Person']));
    });

    test('accepts `class X as "alias"` quoted alias forms (source 33)', () {
      final d = parseClass('@startuml\n'
          'class "This is my class" as class1\n'
          'class class2 as "It works this way too"\n'
          'class2 *-- "foo/dummy" : use\n'
          '@enduml\n');
      expect(d.classes.length, greaterThanOrEqualTo(2));
      expect(d.relationships, hasLength(1));
      final r = d.relationships.single;
      expect(r.kind, RelationshipKind.composition);
      expect(r.label, 'use');
    });

    test('accepts `\$`-prefixed names and `remove` directive (source 34)', () {
      final d = parseClass('@startuml\n'
          'class \$C1\n'
          'class \$C2\n'
          '\$C2 class "\$C2" as dollarC2\n'
          'remove \$C1\n'
          'remove \$C2\n'
          'remove dollarC2\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name), containsAll([r'$C1', r'$C2']));
    });

    test('accepts inline `ClassName : member` declarations (source 35)', () {
      final d = parseClass('@startuml\n'
          'Object <|-- ArrayList\n'
          'Object : equals()\n'
          'ArrayList : Object[] elementData\n'
          'ArrayList : size()\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name),
          containsAll(['Object', 'ArrayList']));
      expect(d.relationships, hasLength(1));
    });

    test('accepts visibility prefix on class keyword (source 36)', () {
      final d = parseClass('@startuml\n'
          '-class "private Class" { }\n'
          '#class "protected Class" { }\n'
          '~class "package private Class" { }\n'
          '+class "public Class" { }\n'
          '@enduml\n');
      expect(d.classes, hasLength(4));
    });

    test('accepts notes (stereotype + attachments) (source 37)', () {
      final d = parseClass('@startuml\n'
          'class Foo << General >>\n'
          'Foo .. N1 : link\n'
          'note left: simple note\n'
          'note top of Foo : top note\n'
          'note "freenote" as N1\n'
          '@enduml\n');
      expect(d.classes.any((c) => c.name == 'Foo'), isTrue);
    });

    test('accepts multi-line notes with HTML (source 38)', () {
      final d = parseClass('@startuml\n'
          'class Foo\n'
          'note top of Foo\n'
          '  A <b>note</b>\n'
          '  on Foo\n'
          'end note\n'
          'note as N1\n'
          '  <b>free</b> note\n'
          'end note\n'
          '@enduml\n');
      expect(d.classes.any((c) => c.name == 'Foo'), isTrue);
    });

    test('accepts class notes with punctuation in multi-line bodies', () {
      // Regression: multi-line note bodies for `note top of <id>` and
      // `note as <id>` must be captured as raw text by the lexer; previously
      // the lexer only entered note-body mode for sequence-diagram forms
      // (`note over X`, `note left/right of X`), so a `.` inside the body
      // raised a LexerException at `one.` on line 6.
      final d = parseClass('@startuml\n'
          'class Foo\n'
          'note left: On last defined class\n'
          'note top of Foo\n'
          '  In java, <size:18>every</size> <u>class</u>\n'
          '  <b>extends</b> <i>this</i> one.\n'
          'end note\n'
          'note as N1\n'
          '  This note is <u>also</u> <b><color:royalBlue>on\n'
          '  several</color> <s>words</s> lines\n'
          '  And this is hosted by <img:https://plantuml.com/sourceforge.jpg>\n'
          'end note\n'
          '@enduml\n');
      expect(d.classes.any((c) => c.name == 'Foo'), isTrue);
      // The verbatim sample contains three notes: one inline `note left:`,
      // one multi-line `note top of Foo`, and one free-standing
      // `note as N1`. The target-less `note left:` form is consumed
      // gracefully without producing a FreeNote, so we assert the two
      // multi-line notes are captured here.
      expect(d.freeNotes, hasLength(2));
      expect(
          d.freeNotes.any(
              (n) => n.alias == 'N1' && n.text.contains('several')),
          isTrue);
      expect(
          d.freeNotes.any((n) =>
              n.attachedTo == 'Foo' &&
              n.text.contains('extends') &&
              n.text.contains('one.')),
          isTrue);
    });

    test('accepts notes attached to members (source 39)', () {
      final d = parseClass('@startuml\n'
          'class A {\n'
          '  {static} int counter\n'
          '  +void {abstract} start(int timeout)\n'
          '}\n'
          'note right of A::counter : a note for counter\n'
          'note right of A::start : a note for start\n'
          '@enduml\n');
      expect(d.classes.any((c) => c.name == 'A'), isTrue);
    });

    test('accepts notes on quoted member signature (source 40)', () {
      final d = parseClass('@startuml\n'
          'class A {\n'
          '  +void start(int timeoutms)\n'
          '}\n'
          'note right of A::"start(int timeoutms)" : a note\n'
          '@enduml\n');
      expect(d.classes.any((c) => c.name == 'A'), isTrue);
    });

    test('accepts notes on links (source 41)', () {
      // Notes on links (`note on link …`, `note right on link …`) are
      // consumed gracefully so the surrounding diagram parses without error.
      // Visual rendering of the note-on-link attachment is deferred — we
      // only assert the diagram parses with at least the first relationship.
      final d = parseClass('@startuml\n'
          'class Dummy\n'
          'Dummy --> Foo : A link\n'
          'note on link #red: note that is red\n'
          'Dummy --> Foo2 : Another link\n'
          'note right on link #blue\n'
          '  this is my note on right link and in blue\n'
          'end note\n'
          '@enduml\n');
      expect(d.relationships.length, greaterThanOrEqualTo(1));
    });

    test('accepts hide/show member control (source 42)', () {
      final d = parseClass('@startuml\n'
          'class Dummy1 { +myMethods() }\n'
          'class Dummy2 { +hiddenMethod() }\n'
          'class Dummy3 <<Serializable>> { String name }\n'
          'hide members\n'
          'hide <<Serializable>> circle\n'
          'show Dummy1 methods\n'
          'show <<Serializable>> fields\n'
          '@enduml\n');
      expect(d.classes, hasLength(3));
    });

    test('accepts `remove X` directive (source 43)', () {
      final d = parseClass('@startuml\n'
          'class Foo1\n'
          'class Foo2\n'
          'Foo2 *-- Foo1\n'
          'remove Foo2\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name), containsAll(['Foo1', 'Foo2']));
      expect(d.relationships, hasLength(1));
    });

    test('accepts `\$tag` suffix on declarations (source 44)', () {
      final d = parseClass('@startuml\n'
          'class C1 \$tag13\n'
          'enum E1\n'
          'interface I1 \$tag13\n'
          'C1 -- I1\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name),
          containsAll(['C1', 'E1', 'I1']));
      expect(d.relationships, hasLength(1));
    });

    test('accepts `hide \$tag` (source 45)', () {
      final d = parseClass('@startuml\n'
          'class C1 \$tag13\n'
          'enum E1\n'
          'interface I1 \$tag13\n'
          'C1 -- I1\n'
          'hide \$tag13\n'
          '@enduml\n');
      expect(d.classes.length, greaterThanOrEqualTo(3));
    });

    test('accepts `remove \$tag` (source 46)', () {
      final d = parseClass('@startuml\n'
          'class C1 \$tag13\n'
          'enum E1\n'
          'interface I1 \$tag13\n'
          'C1 -- I1\n'
          'remove \$tag13\n'
          '@enduml\n');
      expect(d.classes.length, greaterThanOrEqualTo(3));
    });

    test('accepts multi-`\$tag` suffix + `restore \$tag` (source 47)', () {
      final d = parseClass('@startuml\n'
          'class C1 \$tag13 \$tag1\n'
          'enum E1\n'
          'interface I1 \$tag13\n'
          'C1 -- I1\n'
          'remove \$tag13\n'
          'restore \$tag1\n'
          '@enduml\n');
      expect(d.classes.length, greaterThanOrEqualTo(3));
    });

    test('accepts `remove *` wildcard selector (source 48)', () {
      final d = parseClass('@startuml\n'
          'class C1 \$tag13 \$tag1\n'
          'enum E1\n'
          'interface I1 \$tag13\n'
          'C1 -- I1\n'
          'remove *\n'
          'restore \$tag1\n'
          '@enduml\n');
      expect(d.classes.length, greaterThanOrEqualTo(3));
    });

    test('accepts `hide @unlinked` selector (source 49)', () {
      final d = parseClass('@startuml\n'
          'class C1\n'
          'class C2\n'
          'class C3\n'
          'C1 -- C2\n'
          'hide @unlinked\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name),
          containsAll(['C1', 'C2', 'C3']));
    });

    test('accepts `remove @unlinked` selector (source 50)', () {
      final d = parseClass('@startuml\n'
          'class C1\n'
          'class C2\n'
          'class C3\n'
          'C1 -- C2\n'
          'remove @unlinked\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name),
          containsAll(['C1', 'C2', 'C3']));
    });

    test('accepts gradient colors on class and package (source 69)', () {
      final d = parseClass('@startuml\n'
          'skinparam backgroundcolor AntiqueWhite/Gold\n'
          'skinparam classBackgroundColor Wheat|CornflowerBlue\n'
          'class Foo #red-green\n'
          'note left of Foo\n'
          '  this is my note\n'
          'end note\n'
          'package example #GreenYellow/LightGoldenRodYellow {\n'
          '  class Dummy\n'
          '}\n'
          '@enduml\n');
      expect(d.classes.map((c) => c.name), containsAll(['Foo', 'Dummy']));
    });
  });

  group('object diagram', () {
    ClassDiagram parseObject(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as ClassDiagram;
    }

    test('parses a single bare object header', () {
      final d = parseObject('@startuml\nobject alice\n@enduml\n');
      expect(d.classes, hasLength(1));
      final c = d.classes.single;
      expect(c.name, 'alice');
      expect(c.kind, ClassKind.object_);
      expect(c.instanceOf, isNull);
      expect(c.members, isEmpty);
    });

    test('parses typed instance "object alice : Person"', () {
      final d = parseObject('@startuml\nobject alice : Person\n@enduml\n');
      final c = d.classes.single;
      expect(c.kind, ClassKind.object_);
      expect(c.name, 'alice');
      expect(c.instanceOf, 'Person');
    });

    test('parses object body with attribute assignments', () {
      final d = parseObject('@startuml\n'
          'object alice {\n'
          '  name = "Alice"\n'
          '  age = 30\n'
          '}\n'
          '@enduml\n');
      final members = d.classes.single.members;
      expect(members, hasLength(2));
      final a1 = members[0] as Attribute;
      expect(a1.name, 'name');
      expect(a1.value, 'Alice');
      expect(a1.isMap, isFalse);
      final a2 = members[1] as Attribute;
      expect(a2.name, 'age');
      expect(a2.value, '30');
    });

    test('parses map with key => value entries', () {
      final d = parseObject('@startuml\n'
          'map config {\n'
          '  host => "localhost"\n'
          '  port => "8080"\n'
          '}\n'
          '@enduml\n');
      final c = d.classes.single;
      expect(c.kind, ClassKind.map_);
      expect(c.name, 'config');
      final a1 = c.members[0] as Attribute;
      expect(a1.isMap, isTrue);
      expect(a1.name, 'host');
      expect(a1.value, 'localhost');
      final a2 = c.members[1] as Attribute;
      expect(a2.isMap, isTrue);
      expect(a2.name, 'port');
      expect(a2.value, '8080');
    });

    test('parses relationships between objects', () {
      final d = parseObject('@startuml\n'
          'object alice\n'
          'object bob\n'
          'alice --> bob : knows\n'
          '@enduml\n');
      expect(d.classes, hasLength(2));
      final r = d.relationships.single;
      expect(r.from, 'alice');
      expect(r.to, 'bob');
      expect(r.kind, RelationshipKind.directedAssociation);
      expect(r.label, 'knows');
    });
  });

  group('ER diagram', () {
    ClassDiagram parseEr(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as ClassDiagram;
    }

    test('parses entity with members', () {
      final d = parseEr('@startuml\n'
          'entity Customer {\n'
          '  id : int\n'
          '  name : varchar\n'
          '}\n'
          '@enduml\n');
      expect(d.classes, hasLength(1));
      final c = d.classes.single;
      expect(c.kind, ClassKind.entity_);
      expect(c.name, 'Customer');
      expect(c.members, hasLength(2));
      final f = c.members[0] as Field;
      expect(f.name, 'id');
      expect(f.type, 'int');
    });

    test('parses required field with leading "*"', () {
      final d = parseEr('@startuml\n'
          'entity E {\n'
          '  * id : int\n'
          '}\n'
          '@enduml\n');
      final f = d.classes.single.members.single as Field;
      expect(f.required, isTrue);
      expect(f.name, 'id');
      expect(f.type, 'int');
    });

    test('parses trailing <<PK>> stereotype', () {
      final d = parseEr('@startuml\n'
          'entity E {\n'
          '  * id : int <<PK>>\n'
          '  * ref : int <<FK>>\n'
          '}\n'
          '@enduml\n');
      final members = d.classes.single.members;
      final pk = members[0] as Field;
      expect(pk.required, isTrue);
      expect(pk.name, 'id');
      expect(pk.type, 'int');
      expect(pk.stereotype, 'PK');
      final fk = members[1] as Field;
      expect(fk.stereotype, 'FK');
    });

    test('parses member divider inside entity body', () {
      final d = parseEr('@startuml\n'
          'entity E {\n'
          '  * id : int <<PK>>\n'
          '  --\n'
          '  name : varchar\n'
          '}\n'
          '@enduml\n');
      final members = d.classes.single.members;
      expect(members, hasLength(3));
      expect((members[1] as MemberDivider).kind, DividerKind.solid);
    });

    test('parses one-to-one crow\'s foot ||--||', () {
      final d = parseEr('@startuml\n'
          'entity A {\n  x : int\n}\n'
          'entity B {\n  y : int\n}\n'
          'A ||--|| B\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.from, 'A');
      expect(r.to, 'B');
      expect(r.fromCrowFoot, CrowFoot.one);
      expect(r.toCrowFoot, CrowFoot.one);
    });

    test('parses one-to-zero-or-one ||--o|', () {
      final d = parseEr('@startuml\n'
          'entity A {\n  x : int\n}\n'
          'entity B {\n  y : int\n}\n'
          'A ||--o| B\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.fromCrowFoot, CrowFoot.one);
      expect(r.toCrowFoot, CrowFoot.zeroOrOne);
    });

    test('parses one-to-zero-or-many ||--o{', () {
      final d = parseEr('@startuml\n'
          'entity A {\n  x : int\n}\n'
          'entity B {\n  y : int\n}\n'
          'A ||--o{ B\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.fromCrowFoot, CrowFoot.one);
      expect(r.toCrowFoot, CrowFoot.zeroOrMany);
    });

    test('parses one-to-one-or-many ||--|{', () {
      final d = parseEr('@startuml\n'
          'entity A {\n  x : int\n}\n'
          'entity B {\n  y : int\n}\n'
          'A ||--|{ B\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.fromCrowFoot, CrowFoot.one);
      expect(r.toCrowFoot, CrowFoot.oneOrMany);
    });

    test('parses zero-or-many-to-one }o--||', () {
      final d = parseEr('@startuml\n'
          'entity A {\n  x : int\n}\n'
          'entity B {\n  y : int\n}\n'
          'A }o--|| B\n'
          '@enduml\n');
      final r = d.relationships.single;
      expect(r.fromCrowFoot, CrowFoot.zeroOrMany);
      expect(r.toCrowFoot, CrowFoot.one);
    });

    test('parses full Customer / Order / LineItem example', () {
      final d = parseEr('@startuml\n'
          'entity Customer {\n'
          '  * id : int <<PK>>\n'
          '  --\n'
          '  * name : varchar\n'
          '}\n'
          'entity Order {\n'
          '  * id : int <<PK>>\n'
          '  * customer_id : int <<FK>>\n'
          '}\n'
          'entity LineItem {\n'
          '  * id : int <<PK>>\n'
          '  * order_id : int <<FK>>\n'
          '}\n'
          'Customer ||--o{ Order\n'
          'Order ||--|{ LineItem\n'
          '@enduml\n');
      expect(d.classes, hasLength(3));
      for (final c in d.classes) {
        expect(c.kind, ClassKind.entity_);
      }
      expect(d.relationships, hasLength(2));
      expect(d.relationships[0].fromCrowFoot, CrowFoot.one);
      expect(d.relationships[0].toCrowFoot, CrowFoot.zeroOrMany);
      expect(d.relationships[1].fromCrowFoot, CrowFoot.one);
      expect(d.relationships[1].toCrowFoot, CrowFoot.oneOrMany);
    });
  });

  group('use case diagram', () {
    UseCaseDiagram parseUseCase(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as UseCaseDiagram;
    }

    test('parses a single bare actor', () {
      final d = parseUseCase('@startuml\n'
          'actor User\n'
          'usecase Login as UC1\n'
          '@enduml\n');
      final actor = d.nodes.firstWhere((n) => n.alias == 'User');
      expect(actor.kind, UseCaseNodeKind.actor);
    });

    test('"newpage" is consumed as a no-op between relations', () {
      // Use case diagrams don't render page breaks, but the keyword must
      // still parse cleanly so that multi-page sources don't error. Both
      // bare `newpage` and `newpage <title>` should be accepted.
      final d = parseUseCase('@startuml\n'
          ':actor1: --> (Usecase1)\n'
          'newpage\n'
          ':actor2: --> (Usecase2)\n'
          'newpage Page Three\n'
          ':actor3: --> (Usecase3)\n'
          '@enduml\n');
      expect(d.relations, hasLength(3));
      expect(d.nodes.where((n) => n.kind == UseCaseNodeKind.actor),
          hasLength(3));
      expect(d.nodes.where((n) => n.kind == UseCaseNodeKind.useCase),
          hasLength(3));
    });

    test('"ignore newpage" is consumed as a no-op', () {
      final d = parseUseCase('@startuml\n'
          'ignore newpage\n'
          ':actor1: --> (Usecase1)\n'
          'newpage\n'
          ':actor2: --> (Usecase2)\n'
          '@enduml\n');
      expect(d.relations, hasLength(2));
    });

    test('parses an actor with quoted name and alias', () {
      final d = parseUseCase('@startuml\n'
          'actor "Admin User" as Admin\n'
          'usecase Login as UC1\n'
          '@enduml\n');
      final actor = d.nodes.firstWhere((n) => n.alias == 'Admin');
      expect(actor.label, 'Admin User');
      expect(actor.kind, UseCaseNodeKind.actor);
    });

    test('parses a bare usecase', () {
      final d = parseUseCase('@startuml\nusecase Login\n@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'Login');
      expect(n.kind, UseCaseNodeKind.useCase);
    });

    test('parses usecase with quoted name and alias', () {
      final d = parseUseCase('@startuml\n'
          'usecase "Browse Products" as UC1\n'
          '@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'UC1');
      expect(n.label, 'Browse Products');
      expect(n.kind, UseCaseNodeKind.useCase);
    });

    test('parses mixed bare-paren and usecase-keyword declarations', () {
      // Covers four declaration shapes in a single diagram:
      //   1. `(Name)`                       — bare ellipse, alias=label
      //   2. `(Name) as (Alias)`            — bare ellipse with paren alias
      //   3. `usecase ID`                   — keyword + identifier
      //   4. `usecase (Display\n...) as ID` — keyword + paren display + alias,
      //      with an embedded `\n` escape converted to a literal newline.
      final d = parseUseCase('@startuml\n'
          '(First usecase)\n'
          '(Another usecase) as (UC2)\n'
          'usecase UC3\n'
          'usecase (Last\\nusecase) as UC4\n'
          '@enduml\n');
      expect(d.nodes, hasLength(4));
      expect(d.nodes[0].alias, 'First usecase');
      expect(d.nodes[0].label, 'First usecase');
      expect(d.nodes[0].kind, UseCaseNodeKind.useCase);
      expect(d.nodes[1].alias, 'UC2');
      expect(d.nodes[1].label, 'Another usecase');
      expect(d.nodes[1].kind, UseCaseNodeKind.useCase);
      expect(d.nodes[2].alias, 'UC3');
      expect(d.nodes[2].label, 'UC3');
      expect(d.nodes[2].kind, UseCaseNodeKind.useCase);
      expect(d.nodes[3].alias, 'UC4');
      expect(d.nodes[3].label, 'Last\nusecase');
      expect(d.nodes[3].kind, UseCaseNodeKind.useCase);
    });

    test('consumes trailing "/" hidden-node marker on use case declarations',
        () {
      // PlantUML marks a node as "phantom"/hidden with a trailing `/` on the
      // declaration. The marker may appear after every declaration shape:
      //   1. `(Name)/`                            — bare ellipse + slash
      //   2. `(Name)/ as (Alias)`                 — bare ellipse + slash + alias
      //   3. `usecase/ ID`                        — keyword + slash + identifier
      //   4. `usecase/ (Display\n...) as Alias`   — keyword + slash + paren
      //                                              display + alias
      // The slash is currently consumed as a no-op (visual hiding deferred);
      // the four declarations must still produce four nodes.
      final d = parseUseCase('@startuml\n'
          '(First usecase)/\n'
          '(Another usecase)/ as (UC2)\n'
          'usecase/ UC3\n'
          'usecase/ (Last\\nusecase) as UC4\n'
          '@enduml\n');
      expect(d.nodes, hasLength(4));
      expect(d.nodes[0].alias, 'First usecase');
      expect(d.nodes[0].kind, UseCaseNodeKind.useCase);
      expect(d.nodes[1].alias, 'UC2');
      expect(d.nodes[1].label, 'Another usecase');
      expect(d.nodes[2].alias, 'UC3');
      expect(d.nodes[3].alias, 'UC4');
      expect(d.nodes[3].label, 'Last\nusecase');
    });

    test('consumes trailing "/" hidden-node marker on actor declarations', () {
      // Same phantom marker applies to actor declarations. Covers the four
      // canonical shapes:
      //   1. `:Display:/`                  — colon-wrapped + slash
      //   2. `:Display:/ as Alias`         — colon-wrapped + slash + alias
      //   3. `actor/ ID`                   — keyword + slash + identifier
      //   4. `actor/ :Display: as Alias`   — keyword + slash + colon-wrapped
      //                                       + alias
      final d = parseUseCase('@startuml\n'
          ':First Actor:/\n'
          ':Another\\nactor:/ as Man2\n'
          'actor/ Woman3\n'
          'actor/ :Last actor: as Person1\n'
          '@enduml\n');
      final actors =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.actor).toList();
      expect(actors, hasLength(4));
    });

    test('parses every PlantUML element-type keyword as <kind> <name>', () {
      // Verifies that every PlantUML element-shape keyword can be used in the
      // canonical `<kind> <name>` form within a single use case / mixed
      // diagram. The use-case AST currently coerces non-actor/usecase shapes
      // to actor-kind nodes (rendering-shape mapping is deferred); the test
      // only asserts that the parse succeeds and 30 nodes are declared.
      final d = parseUseCase('@startuml\n'
          'action action\n'
          'actor actor\n'
          'actor/ "actor/"\n'
          'agent agent\n'
          'artifact artifact\n'
          'boundary boundary\n'
          'card card\n'
          'circle circle\n'
          'cloud cloud\n'
          'collections collections\n'
          'component component\n'
          'control control\n'
          'database database\n'
          'entity entity\n'
          'file file\n'
          'folder folder\n'
          'frame frame\n'
          'hexagon hexagon\n'
          'interface interface\n'
          'label label\n'
          'node node\n'
          'package package\n'
          'person person\n'
          'process process\n'
          'queue queue\n'
          'rectangle rectangle\n'
          'stack stack\n'
          'storage storage\n'
          'usecase usecase\n'
          'usecase/ "usecase/"\n'
          '@enduml\n');
      // 28 shapes map to nodes; `rectangle` and `package` lower to boundaries
      // (no node), so 30 declarations -> 28 nodes + 2 boundaries.
      expect(d.nodes, hasLength(28));
      expect(d.boundaries, hasLength(2));
    });

    test('parses rectangle boundary with contained use cases', () {
      final d = parseUseCase('@startuml\n'
          'rectangle "System" {\n'
          '  usecase Login as UC1\n'
          '  usecase Logout as UC2\n'
          '}\n'
          '@enduml\n');
      expect(d.boundaries, hasLength(1));
      final b = d.boundaries.single;
      expect(b.label, 'System');
      expect(b.containedAliases, ['UC1', 'UC2']);
      expect(d.nodes.map((n) => n.alias), ['UC1', 'UC2']);
    });

    test('parses anonymous rectangle boundary', () {
      final d = parseUseCase('@startuml\n'
          'rectangle {\n'
          '  usecase Foo\n'
          '}\n'
          '@enduml\n');
      expect(d.boundaries.single.label, isNull);
      expect(d.boundaries.single.containedAliases, ['Foo']);
    });

    test('parses actor-to-usecase relationship', () {
      final d = parseUseCase('@startuml\n'
          'actor User\n'
          'usecase Login as UC1\n'
          'User --> UC1\n'
          '@enduml\n');
      expect(d.relations, hasLength(1));
      final r = d.relations.single;
      expect(r.from, 'User');
      expect(r.to, 'UC1');
      expect(r.lineStyle, LineStyle.solid);
      expect(r.head, ArrowHead.open);
    });

    test('parses include stereotype dashed dependency', () {
      final d = parseUseCase('@startuml\n'
          'usecase A\n'
          'usecase B\n'
          'A ..> B : <<include>>\n'
          '@enduml\n');
      final r = d.relations.single;
      expect(r.lineStyle, LineStyle.dashed);
      expect(r.head, ArrowHead.open);
      expect(r.label, '<<include>>');
    });

    test('parses extend stereotype dashed dependency', () {
      final d = parseUseCase('@startuml\n'
          'usecase A\n'
          'usecase B\n'
          'A ..> B : <<extend>>\n'
          '@enduml\n');
      final r = d.relations.single;
      expect(r.label, '<<extend>>');
      expect(r.lineStyle, LineStyle.dashed);
    });

    test('parses plain association --', () {
      final d = parseUseCase('@startuml\n'
          'actor U\n'
          'usecase X\n'
          'U -- X\n'
          '@enduml\n');
      final r = d.relations.single;
      expect(r.head, isNull);
      expect(r.lineStyle, LineStyle.solid);
    });

    test('full system example parses end-to-end', () {
      final d = parseUseCase('@startuml\n'
          'actor User\n'
          'actor Admin\n'
          'rectangle System {\n'
          '  usecase "Browse Products" as UC1\n'
          '  usecase "Place Order" as UC2\n'
          '  usecase "Manage Inventory" as UC3\n'
          '  usecase Login as UC4\n'
          '}\n'
          'User --> UC1\n'
          'User --> UC2\n'
          'Admin --> UC3\n'
          'Admin --> UC4\n'
          'UC2 ..> UC4 : <<include>>\n'
          'UC3 ..> UC4 : <<include>>\n'
          '@enduml\n');
      expect(
          d.nodes.where((n) => n.kind == UseCaseNodeKind.actor), hasLength(2));
      expect(d.nodes.where((n) => n.kind == UseCaseNodeKind.useCase),
          hasLength(4));
      expect(d.boundaries.single.label, 'System');
      expect(
          d.boundaries.single.containedAliases, ['UC1', 'UC2', 'UC3', 'UC4']);
      expect(d.relations, hasLength(6));
    });

    test('parses usecase with multi-line label and internal separators', () {
      final d = parseUseCase('@startuml\n'
          'usecase UC1 as "You can use\n'
          'several lines to define your usecase.\n'
          'You can also use separators.\n'
          '--\n'
          'Several separators are possible.\n'
          '==\n'
          'And you can add titles:\n'
          '..Conclusion..\n'
          'This allows large description."\n'
          '@enduml\n');
      expect(d.nodes, hasLength(1));
      final n = d.nodes.single;
      expect(n.alias, 'UC1');
      expect(n.kind, UseCaseNodeKind.useCase);
      expect(n.label, contains('You can use\n'));
      final spans = n.labelSpans!;
      final separators =
          spans.whereType<UseCaseLabelSeparatorSpan>().toList();
      expect(separators.map((s) => s.kind), [
        UseCaseLabelSeparator.thin,
        UseCaseLabelSeparator.thick,
        UseCaseLabelSeparator.labeled,
      ]);
      expect(separators.last.text, 'Conclusion');
      // Sandwich text spans between every separator.
      final texts = spans.whereType<UseCaseLabelText>().toList();
      expect(texts, hasLength(4));
    });

    test('parses actor + use case with various arrow lengths', () {
      final d = parseUseCase('@startuml\n'
          'User -> (Start)\n'
          'User --> (Use the application) : A small label\n'
          ':Main Admin: ---> (Use the application) : This is\\nyet another\\nlabel\n'
          '@enduml\n');
      final actors =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.actor).toList();
      expect(actors.map((n) => n.alias).toSet(), {'User', 'MainAdmin'});
      final useCases =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.useCase).toList();
      expect(useCases.map((n) => n.alias).toSet(),
          {'Start', 'Use the application'});
      // Three relations with progressively longer dashed bodies.
      expect(d.relations, hasLength(3));
      expect(d.relations[0].from, 'User');
      expect(d.relations[0].to, 'Start');
      expect(d.relations[1].label, 'A small label');
      expect(d.relations[2].from, 'MainAdmin');
      expect(d.relations[2].to, 'Use the application');
      expect(d.relations[2].label, contains('\n'));
    });

    test('parses minimal use case with colon-wrapped actor and ellipse', () {
      final d = parseUseCase('@startuml\n'
          ':user: --> (Use case 1)\n'
          ':user: -> (Use case 2)\n'
          '@enduml\n');
      expect(d.relations, hasLength(2));
      final actors =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.actor).toList();
      expect(actors.single.alias, 'user');
      final useCases =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.useCase).toList();
      expect(useCases.map((n) => n.alias).toSet(),
          {'Use case 1', 'Use case 2'});
      for (final r in d.relations) {
        expect(r.from, 'user');
      }
    });

    test('parses colon-wrapped actor with explicit as alias', () {
      // Routes to the use-case parser via the trailing `-> (Start)` arrow
      // on a use-case ellipse.
      final d = parseUseCase('@startuml\n'
          ':Main Admin: as Admin\n'
          'Admin -> (Start)\n'
          '@enduml\n');
      final actor = d.nodes.firstWhere((n) => n.alias == 'Admin');
      expect(actor.label, 'Main Admin');
      expect(actor.kind, UseCaseNodeKind.actor);
    });

    test('parses parenthesized use case with parenthesized alias', () {
      final d = parseUseCase('@startuml\n'
          '(Use the application) as (Use)\n'
          'User -> (Use)\n'
          '@enduml\n');
      final uc = d.nodes.firstWhere((n) => n.alias == 'Use');
      expect(uc.label, 'Use the application');
      expect(uc.kind, UseCaseNodeKind.useCase);
      // The relation should reference the ellipse by its overriden alias.
      expect(d.relations, hasLength(1));
      expect(d.relations.single.from, 'User');
      expect(d.relations.single.to, 'Use');
    });

    test('parses parenthesized use case with bare alias', () {
      final d = parseUseCase('@startuml\n'
          '(Browse) as B\n'
          'User -> (Browse)\n'
          '@enduml\n');
      final uc = d.nodes.firstWhere((n) => n.alias == 'B');
      expect(uc.label, 'Browse');
    });

    test('parses inline note right of actor', () {
      final d = parseUseCase('@startuml\n'
          'actor Admin\n'
          'Admin -> (Start)\n'
          'note right of Admin : This is an example.\n'
          '@enduml\n');
      expect(d.notes, hasLength(1));
      final n = d.notes.single;
      expect(n.text, 'This is an example.');
      expect(n.position, NotePosition.rightOf);
      expect(n.attachedTo, 'Admin');
      expect(n.isFreeStanding, isFalse);
    });

    test('parses multi-line note right of parenthesized use case', () {
      final d = parseUseCase('@startuml\n'
          '(Use the application) as (Use)\n'
          'User -> (Use)\n'
          'note right of (Use)\n'
          '  A note can also\n'
          '  be on several lines\n'
          'end note\n'
          '@enduml\n');
      expect(d.notes, hasLength(1));
      final n = d.notes.single;
      expect(n.position, NotePosition.rightOf);
      expect(n.attachedTo, 'Use');
      expect(n.text, contains('A note can also'));
      expect(n.text, contains('be on several lines'));
    });

    test('parses free-standing note with alias', () {
      final d = parseUseCase('@startuml\n'
          'User -> (Start)\n'
          'note "This note is connected\\nto several objects." as N2\n'
          '@enduml\n');
      expect(d.notes, hasLength(1));
      final n = d.notes.single;
      expect(n.alias, 'N2');
      expect(n.text, 'This note is connected\nto several objects.');
      expect(n.position, isNull);
      expect(n.attachedTo, isNull);
      expect(n.isFreeStanding, isTrue);
    });

    test('parses dotted note connection lines', () {
      final d = parseUseCase('@startuml\n'
          'note "Floating" as N2\n'
          '(Start) .. N2\n'
          'N2 .. (Use)\n'
          '@enduml\n');
      expect(d.noteConnections, hasLength(2));
      expect(d.noteConnections[0].from, 'Start');
      expect(d.noteConnections[0].to, 'N2');
      expect(d.noteConnections[1].from, 'N2');
      expect(d.noteConnections[1].to, 'Use');
      // The note should not be promoted to a use-case node.
      expect(d.nodes.any((n) => n.alias == 'N2'), isFalse);
      // The connected use cases SHOULD be auto-declared.
      expect(d.nodes.where((n) => n.alias == 'Start'), hasLength(1));
      expect(d.nodes.where((n) => n.alias == 'Use'), hasLength(1));
    });

    test('parses the full notes-and-connections example end-to-end', () {
      final d = parseUseCase('@startuml\n'
          ':Main Admin: as Admin\n'
          '(Use the application) as (Use)\n'
          '\n'
          'User -> (Start)\n'
          'User --> (Use)\n'
          '\n'
          'Admin ---> (Use)\n'
          '\n'
          'note right of Admin : This is an example.\n'
          '\n'
          'note right of (Use)\n'
          '  A note can also\n'
          '  be on several lines\n'
          'end note\n'
          '\n'
          'note "This note is connected\\nto several objects." as N2\n'
          '(Start) .. N2\n'
          'N2 .. (Use)\n'
          '@enduml\n');
      // 2 actors + 2 use cases.
      final actors =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.actor).toList();
      expect(actors.map((a) => a.alias).toSet(), {'Admin', 'User'});
      final useCases =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.useCase).toList();
      expect(useCases.map((u) => u.alias).toSet(), {'Use', 'Start'});
      // 3 arrow relations.
      expect(d.relations, hasLength(3));
      // 3 notes: two attached + one free-standing.
      expect(d.notes, hasLength(3));
      expect(d.notes.where((n) => n.isFreeStanding), hasLength(1));
      expect(d.notes.where((n) => !n.isFreeStanding), hasLength(2));
      // 2 dotted note connections.
      expect(d.noteConnections, hasLength(2));
    });

    test('direction-hint arrows -left-> / -right-> / -up-> / -down-> '
        'parse without error', () {
      final d = parseUseCase('@startuml\n'
          ':user: -left-> (dummyLeft)\n'
          ':user: -right-> (dummyRight)\n'
          ':user: -up-> (dummyUp)\n'
          ':user: -down-> (dummyDown)\n'
          '@enduml\n');
      expect(d.relations, hasLength(4));
    });

    test('package block with left to right direction', () {
      final d = parseUseCase('@startuml\n'
          'left to right direction\n'
          'actor Guest as g\n'
          'package Professional {\n'
          '  actor Chef as c\n'
          '  actor "Food Critic" as fc\n'
          '}\n'
          'package Restaurant {\n'
          '  usecase "Eat Food" as UC1\n'
          '  usecase "Pay for Food" as UC2\n'
          '}\n'
          'g --> UC1\n'
          '@enduml\n');
      expect(d.leftToRightDirection, isTrue);
      expect(d.boundaries, hasLength(2));
      // Professional contains Chef + fc.
      expect(d.boundaries[0].label, 'Professional');
      expect(d.boundaries[0].containedAliases, ['c', 'fc']);
      // Restaurant contains UC1 + UC2.
      expect(d.boundaries[1].label, 'Restaurant');
      expect(d.boundaries[1].containedAliases, ['UC1', 'UC2']);
    });

    test('keyword-less "Name" as Alias declares actor implicitly', () {
      final d = parseUseCase('@startuml\n'
          'skinparam actorStyle Hollow\n'
          ':User: --> (Use)\n'
          '"Main Admin" as Admin\n'
          '"Use the application" as (Use)\n'
          '@enduml\n');
      final admin = d.nodes.firstWhere((n) => n.alias == 'Admin');
      expect(admin.kind, UseCaseNodeKind.actor);
      expect(admin.label, 'Main Admin');
      final use = d.nodes.firstWhere((n) => n.alias == 'Use');
      expect(use.kind, UseCaseNodeKind.useCase);
      expect(use.label, 'Use the application');
    });

    test('skinparam line is consumed without error in use case diagram', () {
      // Two different actorStyle values must both parse.
      parseUseCase('@startuml\n'
          'skinparam actorStyle awesome\n'
          ':User: --> (Use)\n'
          '@enduml\n');
      parseUseCase('@startuml\n'
          'skinparam actorStyle Hollow\n'
          ':User: --> (Use)\n'
          '@enduml\n');
    });

    test('generalization arrow <|-- emits triangle head and reverses '
        'direction', () {
      final d = parseUseCase('@startuml\n'
          'User <|-- Admin\n'
          '(Start) <|-- (Use)\n'
          '@enduml\n');
      expect(d.relations, hasLength(2));
      // `User <|-- Admin` means User is parent. After the reverse swap the
      // relation flows child→parent so the triangle head sits at the parent.
      expect(d.relations[0].from, 'Admin');
      expect(d.relations[0].to, 'User');
      expect(d.relations[0].head, ArrowHead.triangle);
      expect(d.relations[1].from, 'Use');
      expect(d.relations[1].to, 'Start');
      expect(d.relations[1].head, ArrowHead.triangle);
    });

    test('parses trailing << Stereotype >> on all node declaration shapes',
        () {
      // Exercises the four declaration forms that need to accept an optional
      // trailing `<< Stereotype >>` annotation:
      //   - bare identifier actor:  `User << Human >>`
      //   - colon-wrapped actor:    `:Display: as Alias << Application >>`
      //   - bare paren use case:    `(Start) << One Shot >>`
      //   - paren use case + alias: `(Display) as (Alias) << Main >>`
      final d = parseUseCase('@startuml\n'
          'User << Human >>\n'
          ':Main Database: as MySql << Application >>\n'
          '(Start) << One Shot >>\n'
          '(Use the application) as (Use) << Main >>\n'
          'User -> (Start)\n'
          'User --> (Use)\n'
          'MySql --> (Use)\n'
          '@enduml\n');
      expect(d.nodes, hasLength(4));
      final byAlias = {for (final n in d.nodes) n.alias: n};
      expect(byAlias['User']?.stereotype, 'Human');
      expect(byAlias['User']?.kind, UseCaseNodeKind.actor);
      expect(byAlias['MySql']?.stereotype, 'Application');
      expect(byAlias['MySql']?.label, 'Main Database');
      expect(byAlias['MySql']?.kind, UseCaseNodeKind.actor);
      expect(byAlias['Start']?.stereotype, 'One Shot');
      expect(byAlias['Start']?.kind, UseCaseNodeKind.useCase);
      expect(byAlias['Use']?.stereotype, 'Main');
      expect(byAlias['Use']?.label, 'Use the application');
      expect(byAlias['Use']?.kind, UseCaseNodeKind.useCase);
      expect(d.relations, hasLength(3));
    });

    test('parses << Stereotype >> on actor/usecase keyword declarations', () {
      final d = parseUseCase('@startuml\n'
          'actor User << Human >>\n'
          'usecase Login << Auth >>\n'
          '@enduml\n');
      final byAlias = {for (final n in d.nodes) n.alias: n};
      expect(byAlias['User']?.stereotype, 'Human');
      expect(byAlias['Login']?.stereotype, 'Auth');
    });

    test('accepts !option directive and stereotype-keyed skinparam usecase',
        () {
      // Reproduces the PlantUML "use case skinparam block + !option" sample.
      // `!option` is a global directive the preprocessor already drops, and a
      // `skinparam usecase { ... }` block may carry per-stereotype overrides
      // such as `BackgroundColor<< Main >> YellowGreen` that the parser
      // currently has no model for — those lines should be consumed without
      // error so the diagram parses cleanly.
      final d = parseUseCase('@startuml\n'
          '!option handwritten true\n'
          'skinparam usecase {\n'
          '  BackgroundColor DarkSeaGreen\n'
          '  BorderColor DarkSlateGray\n'
          '  BackgroundColor<< Main >> YellowGreen\n'
          '  BorderColor<< Main >> YellowGreen\n'
          '  ArrowColor Olive\n'
          '  ActorBorderColor black\n'
          '  ActorFontName Courier\n'
          '  ActorBackgroundColor<< Human >> Gold\n'
          '}\n'
          'User << Human >>\n'
          ':Main Database: as MySql << Application >>\n'
          '(Start) << One Shot >>\n'
          '(Use the application) as (Use) << Main >>\n'
          'User -> (Start)\n'
          'User --> (Use)\n'
          'MySql --> (Use)\n'
          '@enduml\n');
      expect(d.nodes, hasLength(4));
      final byAlias = {for (final n in d.nodes) n.alias: n};
      expect(byAlias['User']?.stereotype, 'Human');
      expect(byAlias['MySql']?.stereotype, 'Application');
      expect(byAlias['Start']?.stereotype, 'One Shot');
      expect(byAlias['Use']?.stereotype, 'Main');
      expect(d.relations, hasLength(3));
    });

    test('accepts -- and .> relations inside a rectangle boundary', () {
      // Reproduces the checkout/extends/include sample: undirected `--`
      // relations between an actor and a use case, plus dashed `.>` arrows
      // carrying `: include` / `: extends` labels, all nested inside a
      // `rectangle checkout { ... }` boundary block.
      final d = parseUseCase('@startuml\n'
          'left to right direction\n'
          'skinparam packageStyle rectangle\n'
          'actor customer\n'
          'actor clerk\n'
          'rectangle checkout {\n'
          '  customer -- (checkout)\n'
          '  (checkout) .> (payment) : include\n'
          '  (help) .> (checkout) : extends\n'
          '  (checkout) -- clerk\n'
          '}\n'
          '@enduml\n');
      final actors =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.actor).toList();
      final useCases =
          d.nodes.where((n) => n.kind == UseCaseNodeKind.useCase).toList();
      expect(actors.map((n) => n.alias), containsAll(['customer', 'clerk']));
      expect(useCases.map((n) => n.alias),
          containsAll(['checkout', 'payment', 'help']));
      expect(d.relations, hasLength(4));
      // The `.>` arrow tokenizes as a dashed body with an open head; this
      // mirrors the visual style PlantUML uses for include / extends edges.
      final dashed =
          d.relations.where((r) => r.lineStyle == LineStyle.dashed).toList();
      expect(dashed, hasLength(2));
      expect(dashed.map((r) => r.label),
          containsAll(['include', 'extends']));
    });

    test('parses inline-style arrow modifiers on relations', () {
      // PlantUML allows `#<color>;line:<c>;line.<style>;text:<c>` after the
      // target of a relation. All four relations must materialize with their
      // labels, line colors, line styles, and text colors recorded on the
      // AST so the renderer can apply the inline style.
      final d = parseUseCase('@startuml\n'
          'actor foo\n'
          'foo --> (bar) : normal\n'
          'foo --> (bar1) #line:red;line.bold;text:red : red bold\n'
          'foo --> (bar2) #green;line.dashed;text:green : green dashed\n'
          'foo --> (bar3) #blue;line.dotted;text:blue : blue dotted\n'
          '@enduml\n');
      expect(d.relations, hasLength(4));
      expect(d.relations.map((r) => r.label),
          containsAll(['normal', 'red bold', 'green dashed', 'blue dotted']));
      final byLabel = {for (final r in d.relations) r.label: r};
      // Unstyled relation: no inline modifiers.
      final plain = byLabel['normal']!;
      expect(plain.lineColor, isNull);
      expect(plain.textColor, isNull);
      expect(plain.inlineLineStyle, isNull);
      // `#line:red;line.bold;text:red`.
      final red = byLabel['red bold']!;
      expect(red.lineColor, const Color(0xFFFF0000));
      expect(red.textColor, const Color(0xFFFF0000));
      expect(red.inlineLineStyle, UseCaseLineStyle.bold);
      // `#green;line.dashed;text:green` — head color carries the line color.
      final green = byLabel['green dashed']!;
      expect(green.lineColor, const Color(0xFF008000));
      expect(green.textColor, const Color(0xFF008000));
      expect(green.inlineLineStyle, UseCaseLineStyle.dashed);
      // `#blue;line.dotted;text:blue`.
      final blue = byLabel['blue dotted']!;
      expect(blue.lineColor, const Color(0xFF0000FF));
      expect(blue.textColor, const Color(0xFF0000FF));
      expect(blue.inlineLineStyle, UseCaseLineStyle.dotted);
    });

    test('parses inline-style modifiers on node declarations', () {
      // PlantUML allows `#<bg>;line:<c>;line.<style>;text:<c>` after an
      // `actor` or `usecase` declaration. Visual styling is deferred — the
      // parse must succeed and all four nodes must materialize.
      final d = parseUseCase('@startuml\n'
          'actor a\n'
          'actor b #pink;line:red;line.bold;text:red\n'
          'usecase c #palegreen;line:green;line.dashed;text:green\n'
          'usecase d #aliceblue;line:blue;line.dotted;text:blue\n'
          '@enduml\n');
      expect(d.nodes, hasLength(4));
      expect(d.nodes.where((n) => n.kind == UseCaseNodeKind.actor),
          hasLength(2));
      expect(d.nodes.where((n) => n.kind == UseCaseNodeKind.useCase),
          hasLength(2));
    });
  });

  group('activity diagram', () {
    ActivityDiagram parseActivity(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as ActivityDiagram;
    }

    test('parses start/stop with single action', () {
      final d = parseActivity('@startuml\n'
          'start\n'
          ':Process Order;\n'
          'stop\n'
          '@enduml\n');
      expect(d.nodes, hasLength(3));
      expect(d.nodes[0], isA<StartNode>());
      expect(d.nodes[1], isA<Action>());
      expect((d.nodes[1] as Action).text, 'Process Order');
      expect(d.nodes[2], isA<StopNode>());
    });

    test('parses `- text` bullet shortcut as Action nodes', () {
      final d = parseActivity('@startuml\n'
          '- Action 1\n'
          '- Action 2\n'
          '- Action 3\n'
          '@enduml\n');
      expect(d.nodes, hasLength(3));
      for (final n in d.nodes) {
        expect(n, isA<Action>());
      }
      expect((d.nodes[0] as Action).text, 'Action 1');
      expect((d.nodes[1] as Action).text, 'Action 2');
      expect((d.nodes[2] as Action).text, 'Action 3');
    });

    test('skips common diagram decorations before activity nodes', () {
      final d = parseActivity('@startuml\n'
          'title Release Pipeline\n'
          'header Draft\n'
          'caption Offline render\n'
          'start\n'
          ':Create release branch;\n'
          'stop\n'
          '@enduml\n');
      expect(d.nodes, hasLength(3));
      expect(d.nodes[0], isA<StartNode>());
      expect((d.nodes[1] as Action).text, 'Create release branch');
      expect(d.nodes[2], isA<StopNode>());
    });

    test('parses end keyword as EndNode', () {
      final d = parseActivity('@startuml\n'
          'start\n'
          ':Done;\n'
          'end\n'
          '@enduml\n');
      expect(d.nodes.last, isA<EndNode>());
    });

    test('parses if/then/else/endif', () {
      final d = parseActivity('@startuml\n'
          'start\n'
          'if (in stock?) then (yes)\n'
          '  :Ship item;\n'
          'else (no)\n'
          '  :Notify customer;\n'
          'endif\n'
          'stop\n'
          '@enduml\n');
      final ifBlock = d.nodes[1] as IfBlock;
      expect(ifBlock.branches, hasLength(1));
      expect(ifBlock.branches.first.condition, 'in stock?');
      expect(ifBlock.branches.first.thenLabel, 'yes');
      expect((ifBlock.branches.first.body.single as Action).text, 'Ship item');
      expect(ifBlock.elseLabel, 'no');
      expect((ifBlock.elseBody.single as Action).text, 'Notify customer');
    });

    test('parses elseif into multiple branches', () {
      final d = parseActivity('@startuml\n'
          'if (a) then (1)\n'
          '  :A;\n'
          'elseif (b) then (2)\n'
          '  :B;\n'
          'else\n'
          '  :C;\n'
          'endif\n'
          '@enduml\n');
      final ifBlock = d.nodes.single as IfBlock;
      expect(ifBlock.branches, hasLength(2));
      expect(ifBlock.branches[0].condition, 'a');
      expect(ifBlock.branches[1].condition, 'b');
      expect((ifBlock.elseBody.single as Action).text, 'C');
    });

    test('parses while/endwhile with labels', () {
      final d = parseActivity('@startuml\n'
          'while (more items?) is (yes)\n'
          '  :Next item;\n'
          'endwhile (no)\n'
          '@enduml\n');
      final w = d.nodes.single as WhileBlock;
      expect(w.condition, 'more items?');
      expect(w.isLabel, 'yes');
      expect(w.endLabel, 'no');
      expect((w.body.single as Action).text, 'Next item');
    });

    test('parses repeat/repeat while', () {
      final d = parseActivity('@startuml\n'
          'repeat\n'
          '  :Task;\n'
          'repeat while (more?)\n'
          '@enduml\n');
      final r = d.nodes.single as RepeatBlock;
      expect(r.whileCondition, 'more?');
      expect((r.body.single as Action).text, 'Task');
    });

    test('parses repeat while with is (label) modifier', () {
      final d = parseActivity('@startuml\n'
          'repeat\n'
          '  :Task;\n'
          'repeat while (c) is (yes)\n'
          '@enduml\n');
      final r = d.nodes.single as RepeatBlock;
      expect(r.whileCondition, 'c');
      expect(r.isLabel, 'yes');
      expect(r.notLabel, isNull);
    });

    test('parses repeat while with is and not label modifiers', () {
      final d = parseActivity('@startuml\n'
          'repeat\n'
          '  :Task;\n'
          'repeat while (c) is (yes) not (no)\n'
          '@enduml\n');
      final r = d.nodes.single as RepeatBlock;
      expect(r.whileCondition, 'c');
      expect(r.isLabel, 'yes');
      expect(r.notLabel, 'no');
    });

    test('parses repeat while with only not (label) modifier', () {
      final d = parseActivity('@startuml\n'
          'repeat\n'
          '  :Task;\n'
          'repeat while (c) not (no)\n'
          '@enduml\n');
      final r = d.nodes.single as RepeatBlock;
      expect(r.whileCondition, 'c');
      expect(r.isLabel, isNull);
      expect(r.notLabel, 'no');
    });

    test('parses while (c) is (yes) ... endwhile (no)', () {
      final d = parseActivity('@startuml\n'
          'while (c) is (yes)\n'
          '  :Step;\n'
          'endwhile (no)\n'
          '@enduml\n');
      final w = d.nodes.single as WhileBlock;
      expect(w.condition, 'c');
      expect(w.isLabel, 'yes');
      expect(w.endLabel, 'no');
    });

    test('parses fork/fork again/end fork', () {
      final d = parseActivity('@startuml\n'
          'fork\n'
          '  :Task A;\n'
          'fork again\n'
          '  :Task B;\n'
          'end fork\n'
          '@enduml\n');
      final f = d.nodes.single as ForkBlock;
      expect(f.branches, hasLength(2));
      expect((f.branches[0].single as Action).text, 'Task A');
      expect((f.branches[1].single as Action).text, 'Task B');
    });

    test('parses partition with body', () {
      final d = parseActivity('@startuml\n'
          'partition Login {\n'
          '  :Enter credentials;\n'
          '  :Submit;\n'
          '}\n'
          '@enduml\n');
      final p = d.nodes.single as Partition;
      expect(p.name, 'Login');
      expect(p.body, hasLength(2));
    });

    test('parses the spec example end-to-end', () {
      final d = parseActivity('@startuml\n'
          'start\n'
          ':Process Order;\n'
          'if (in stock?) then (yes)\n'
          '  :Ship item;\n'
          '  :Send email;\n'
          'else (no)\n'
          '  :Notify customer;\n'
          'endif\n'
          'while (more items?) is (yes)\n'
          '  :Next item;\n'
          'endwhile (no)\n'
          'fork\n'
          '  :Task A;\n'
          'fork again\n'
          '  :Task B;\n'
          'end fork\n'
          ':Final step;\n'
          'stop\n'
          '@enduml\n');
      expect(d.nodes, hasLength(7));
      expect(d.nodes[0], isA<StartNode>());
      expect(d.nodes[1], isA<Action>());
      expect(d.nodes[2], isA<IfBlock>());
      expect(d.nodes[3], isA<WhileBlock>());
      expect(d.nodes[4], isA<ForkBlock>());
      expect(d.nodes[5], isA<Action>());
      expect(d.nodes[6], isA<StopNode>());
    });

    test('parses detach terminator after an action', () {
      final d = parseActivity('@startuml\n'
          'start\n'
          ':Do something;\n'
          'detach\n'
          '@enduml\n');
      expect(d.nodes, hasLength(3));
      expect(d.nodes[0], isA<StartNode>());
      expect(d.nodes[1], isA<Action>());
      expect(d.nodes[2], isA<Detach>());
    });

    test('parses break terminator inside a loop body', () {
      final d = parseActivity('@startuml\n'
          'while (cond?) is (yes)\n'
          '  :Step;\n'
          '  break\n'
          'endwhile (no)\n'
          '@enduml\n');
      final w = d.nodes.single as WhileBlock;
      expect(w.body, hasLength(2));
      expect(w.body[0], isA<Action>());
      expect(w.body[1], isA<Break>());
    });

    test('parses kill terminator after an action', () {
      final d = parseActivity('@startuml\n'
          'start\n'
          ':Do something;\n'
          'kill\n'
          '@enduml\n');
      expect(d.nodes, hasLength(3));
      expect(d.nodes[2], isA<Kill>());
    });

    test('parses detach inside an if branch', () {
      final d = parseActivity('@startuml\n'
          'if (dup?) then (yes)\n'
          '  :Attach;\n'
          '  detach\n'
          'else (no)\n'
          '  :Create;\n'
          'endif\n'
          '@enduml\n');
      final ifBlock = d.nodes.single as IfBlock;
      expect(ifBlock.branches.single.body, hasLength(2));
      expect(ifBlock.branches.single.body[1], isA<Detach>());
      expect(ifBlock.elseBody.single, isA<Action>());
    });
  });

  group('state diagram', () {
    StateDiagram parseState(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as StateDiagram;
    }

    test('parses initial pseudo-state transition', () {
      final d = parseState('@startuml\n[*] --> Idle\n@enduml\n');
      expect(d.transitions, hasLength(1));
      final t = d.transitions.single;
      expect(t.from, '[*]');
      expect(t.to, 'Idle');
      expect(d.states.map((s) => s.name), ['Idle']);
    });

    test('parses final pseudo-state transition', () {
      final d = parseState('@startuml\nRunning --> [*]\n@enduml\n');
      final t = d.transitions.single;
      expect(t.from, 'Running');
      expect(t.to, '[*]');
    });

    test('parses transition with label', () {
      final d = parseState(
          '@startuml\n[*] --> Idle\nIdle --> Running : start\n@enduml\n');
      final t = d.transitions[1];
      expect(t.from, 'Idle');
      expect(t.to, 'Running');
      expect(t.label, 'start');
    });

    test('parses bare state declaration', () {
      final d = parseState('@startuml\nstate Foo\n@enduml\n');
      expect(d.states.single.name, 'Foo');
      expect(d.states.single.displayName, isNull);
    });

    test('parses state alias form', () {
      final d = parseState('@startuml\nstate "Display Name" as Foo\n@enduml\n');
      final s = d.states.single;
      expect(s.name, 'Foo');
      expect(s.displayName, 'Display Name');
    });

    test('parses composite state with nested transitions', () {
      final d = parseState('@startuml\n'
          'state Authenticated {\n'
          '  [*] --> Browsing\n'
          '  Browsing --> Editing : edit\n'
          '  Editing --> Browsing : save\n'
          '}\n'
          '@enduml\n');
      expect(d.states, hasLength(1));
      final outer = d.states.single;
      expect(outer.name, 'Authenticated');
      expect(outer.nestedStates.map((s) => s.name),
          containsAll(['Browsing', 'Editing']));
      expect(outer.nestedTransitions, hasLength(3));
      expect(outer.concurrentRegions, isEmpty);
    });

    test('parses composite with concurrent regions split by --', () {
      final d = parseState('@startuml\n'
          'state Composite {\n'
          '  [*] --> A\n'
          '  A --> B\n'
          '  --\n'
          '  [*] --> C\n'
          '  C --> D\n'
          '}\n'
          '@enduml\n');
      final outer = d.states.single;
      expect(outer.name, 'Composite');
      expect(outer.concurrentRegions, hasLength(2));
      expect(outer.concurrentRegions[0].map((s) => s.name),
          containsAll(['A', 'B']));
      expect(outer.concurrentRegions[1].map((s) => s.name),
          containsAll(['C', 'D']));
      expect(outer.nestedTransitions, hasLength(4));
    });

    group('dotted-name composite nesting', () {
      test('repro: dotted decls nest into composites A and B', () {
        final d = parseState('@startuml\n'
            'state A.X\n'
            'state A.Y\n'
            'state B.Z\n'
            'X --> Z\n'
            'Z --> Y\n'
            '@enduml\n');
        expect(d.states.map((s) => s.name), ['A', 'B']);
        // No flat literal dotted/leaf states leaked to the top level.
        expect(d.states.map((s) => s.name),
            isNot(anyElement(anyOf('A.X', 'X', 'Y', 'Z'))));
        final a = d.states.firstWhere((s) => s.name == 'A');
        final b = d.states.firstWhere((s) => s.name == 'B');
        expect(a.nestedStates.map((s) => s.name), ['X', 'Y']);
        expect(b.nestedStates.map((s) => s.name), ['Z']);
        expect(
          d.transitions.map((t) => '${t.from}->${t.to}'),
          ['X->Z', 'Z->Y'],
        );
      });

      test('three-segment name nests A { B { C } }', () {
        final d = parseState('@startuml\nstate A.B.C\n@enduml\n');
        expect(d.states.map((s) => s.name), ['A']);
        final a = d.states.single;
        expect(a.nestedStates.map((s) => s.name), ['B']);
        final bInner = a.nestedStates.single;
        expect(bInner.nestedStates.map((s) => s.name), ['C']);
        expect(bInner.nestedStates.single.nestedStates, isEmpty);
      });

      test('decls sharing a prefix merge, preserving order', () {
        final d = parseState('@startuml\n'
            'state A.X\n'
            'state A.Y\n'
            '@enduml\n');
        expect(d.states.map((s) => s.name), ['A']);
        expect(d.states.single.nestedStates.map((s) => s.name), ['X', 'Y']);
      });

      test('leaf carries description from its dotted decl', () {
        final d = parseState('@startuml\n'
            'state A.X : hello\n'
            'state A.Y\n'
            '@enduml\n');
        final a = d.states.single;
        final x = a.nestedStates.firstWhere((s) => s.name == 'X');
        expect(x.descriptions, ['hello']);
      });

      test('quoted name with a dot is not split', () {
        final d = parseState('@startuml\nstate "A.X" as Foo\n@enduml\n');
        expect(d.states.single.name, 'Foo');
        expect(d.states.single.nestedStates, isEmpty);
      });

      test('regression: brace composite unchanged', () {
        final d = parseState('@startuml\n'
            'state A {\n'
            '  state X { }\n'
            '  state Y { }\n'
            '}\n'
            '@enduml\n');
        expect(d.states.map((s) => s.name), ['A']);
        expect(d.states.single.nestedStates.map((s) => s.name), ['X', 'Y']);
      });
    });

    group('nested forward-ref to a top-level participant', () {
      test('does not duplicate a top-level leaf as a nested stub', () {
        final d = parseState('@startuml\n'
            '[*] -> State1\n'
            'State1 --> State2 : Succeeded\n'
            'State2 --> State3 : Succeeded\n'
            'state State3 {\n'
            '  [*] --> long1\n'
            '  State2 --> [H]: Resume\n'
            '}\n'
            'State3 --> State2 : Pause\n'
            '@enduml\n');
        // State2 is a real top-level participant; it stays at top level once.
        expect(d.states.where((s) => s.name == 'State2'), hasLength(1));
        final state3 = d.states.firstWhere((s) => s.name == 'State3');
        // The spurious nested State2 stub is pruned; long1 remains nested.
        expect(state3.nestedStates.map((s) => s.name), ['long1']);
        expect(state3.nestedStates.map((s) => s.name), isNot(contains('State2')));
        // The naming transition survives as a cross-boundary edge.
        expect(
          state3.nestedTransitions.map((t) => '${t.from}->${t.to}'),
          contains('State2->[H]'),
        );
      });

      test('cross-container member is not pruned (state C { B }, A --> B)', () {
        final d = parseState('@startuml\n'
            'state C {\n'
            '  B\n'
            '}\n'
            'A --> B : enter\n'
            '@enduml\n');
        // B is a genuine nested member of C, not a top-level participant, so
        // it must remain nested.
        expect(d.states.map((s) => s.name), isNot(contains('B')));
        final c = d.states.firstWhere((s) => s.name == 'C');
        expect(c.nestedStates.map((s) => s.name), ['B']);
      });
    });

    test('parses full state diagram example', () {
      final d = parseState('@startuml\n'
          '[*] --> Idle\n'
          'Idle --> Running : start\n'
          'Running --> Idle : stop\n'
          'Running --> Paused : pause\n'
          'Paused --> Running : resume\n'
          'Running --> [*] : crash\n'
          '@enduml\n');
      expect(d.transitions, hasLength(6));
      expect(
        d.states.map((s) => s.name),
        containsAll(['Idle', 'Running', 'Paused']),
      );
    });

    test(
        'cross-container transitions do not duplicate nested states '
        'at top level', () {
      final d = parseState('@startuml\n'
          'state A {\n'
          '  state X {\n'
          '  }\n'
          '  state Y {\n'
          '  }\n'
          '}\n'
          'state B {\n'
          '  state Z {\n'
          '  }\n'
          '}\n'
          'X --> Z\n'
          'Z --> Y\n'
          '@enduml\n');
      // Only the two composite containers should appear at top level.
      expect(d.states.map((s) => s.name), ['A', 'B']);
      final a = d.states.firstWhere((s) => s.name == 'A');
      final b = d.states.firstWhere((s) => s.name == 'B');
      expect(a.nestedStates.map((s) => s.name), containsAll(['X', 'Y']));
      expect(b.nestedStates.map((s) => s.name), contains('Z'));
      // The two cross-container transitions survive verbatim at top level.
      expect(d.transitions, hasLength(2));
      expect(d.transitions[0].from, 'X');
      expect(d.transitions[0].to, 'Z');
      expect(d.transitions[1].from, 'Z');
      expect(d.transitions[1].to, 'Y');
    });

    test('state-keyword wins over class dispatcher', () {
      final tokens = Lexer().tokenize('@startuml\n'
          'state Foo\n'
          'Foo --> Bar\n'
          '@enduml\n');
      final d = Parser().parse(tokens);
      expect(d, isA<StateDiagram>());
    });

    test('[*] discriminator routes to state diagram', () {
      final tokens =
          Lexer().tokenize('@startuml\n[*] --> Idle\nIdle --> [*]\n@enduml\n');
      final d = Parser().parse(tokens);
      expect(d, isA<StateDiagram>());
    });

    test('S1 frame container flattens into state diagram', () {
      final d = parseState('@startuml\n'
          'frame frame {\n'
          '  state a\n'
          '}\n'
          'state b\n'
          'a --> b\n'
          'b--> [*]\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), containsAll(['a', 'b']));
      expect(d.transitions, hasLength(2));
    });

    test('S2 mainframe directive is consumed', () {
      final d = parseState('@startuml\n'
          'mainframe mainframe\n'
          'state a\n'
          'state b\n'
          'a --> b\n'
          'b--> [*]\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), containsAll(['a', 'b']));
    });

    test('S3 hide empty description + member descriptions', () {
      final d = parseState('@startuml\n'
          'hide empty description\n'
          'state s0\n'
          'state "This is the State 1" as s1 {\n'
          '  s1: State description\n'
          '  state s2\n'
          '  state s3: long descr.\n'
          '  state s4\n'
          '  s4: long descr.\n'
          '}\n'
          '[*] -> s0\n'
          's0 --> s2\n'
          's2 -> s3\n'
          's3 -> s4\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), contains('s1'));
    });

    test('S4 state descriptions with quoted literal on same line', () {
      final d = parseState('@startuml\n'
          'state alias1 : ""state alias1""\n'
          'state "alias2" : ""state "alias2"""\n'
          'state "long name" as alias3 : ""state "long name" as alias3""\n'
          'state alias4 as "long name" : ""state alias4 as "long name"""\n'
          'alias1 -> alias2\n'
          'alias2 -> alias3\n'
          'alias3 -> alias4\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), contains('alias1'));
      expect(d.states.map((s) => s.name), contains('alias3'));
      expect(d.states.map((s) => s.name), contains('alias4'));
    });

    test('S5 state descriptions on separate lines', () {
      final d = parseState('@startuml\n'
          'state alias1\n'
          'state "alias2"\n'
          'state "long name" as alias3\n'
          'state alias4 as "long name"\n'
          'alias1 : ""state alias1""\n'
          'alias2 : ""state "alias2"""\n'
          'alias3 : ""state "long name" as alias3""\n'
          'alias4 : ""state alias4 as "long name"""\n'
          'alias1 -> alias2\n'
          'alias2 -> alias3\n'
          'alias3 -> alias4\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), contains('alias1'));
      expect(d.states.map((s) => s.name), contains('alias3'));
      expect(d.states.map((s) => s.name), contains('alias4'));
    });

    test('S6 inline #color;line:X;text:Y styles on state', () {
      final d = parseState('@startuml\n'
          'state s1 : s1 description\n'
          'state s2 #pink;line:red;line.bold;text:red : s2 description\n'
          'state s3 #palegreen;line:green;line.dashed;text:green : s3 description\n'
          'state s4 #aliceblue;line:blue;line.dotted;text:blue : s4 description\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name),
          containsAll(['s1', 's2', 's3', 's4']));
    });

    test('S7 gradient colors + nested composite states with inline styles',
        () {
      final d = parseState('@startuml\n'
          'state FooGradient #red-green;line:00FFFF\n'
          'state FooDashed #red|green;line.dashed;line:blue {\n'
          '}\n'
          'state FooDotted #line.dotted;line:blue {\n'
          '}\n'
          'state FooBold #line.bold {\n'
          '}\n'
          'state Foo1 #line.dotted;line:green {\n'
          '  state inner1 #line.dotted;line:yellow\n'
          '}\n'
          'state out #line.dotted;line:gold\n'
          'state Foo2 #line.bold;line:green {\n'
          '  state inner2 #line.dotted;line:yellow\n'
          '}\n'
          'inner1 -> inner2\n'
          'out -> inner2\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), contains('FooGradient'));
      expect(d.states.map((s) => s.name), contains('Foo1'));
      expect(d.states.map((s) => s.name), contains('Foo2'));
    });

    test('S8 ##color border modifier syntax', () {
      final d = parseState('@startuml\n'
          'state FooGradient #red-green ##00FFFF\n'
          'state FooDashed #red|green ##[dashed]blue {\n'
          '}\n'
          'state FooDotted ##[dotted]blue {\n'
          '}\n'
          'state FooBold ##[bold] {\n'
          '}\n'
          'state Foo1 ##[dotted]green {\n'
          '  state inner1 ##[dotted]yellow\n'
          '}\n'
          'state out ##[dotted]gold\n'
          'state Foo2 ##[bold]green {\n'
          '  state inner2 ##[dotted]yellow\n'
          '}\n'
          'inner1 -> inner2\n'
          'out -> inner2\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), contains('FooGradient'));
      expect(d.states.map((s) => s.name), contains('FooBold'));
    });

    test('S9 skinparam State block + state descriptions', () {
      final d = parseState('@startuml\n'
          'skinparam State {\n'
          '  AttributeFontColor blue\n'
          '  AttributeFontName serif\n'
          '  AttributeFontSize 9\n'
          '  AttributeFontStyle italic\n'
          '  BackgroundColor palegreen\n'
          '  BorderColor violet\n'
          '  EndColor gold\n'
          '  FontColor red\n'
          '  FontName Sansserif\n'
          '  FontSize 15\n'
          '  FontStyle bold\n'
          '  StartColor silver\n'
          '}\n'
          'state A : a a a\\na\n'
          'state B : b b b\\nb\n'
          '[*] -> A : start\n'
          'A -> B : a2b\n'
          'B -> [*] : end\n'
          '@enduml\n');
      expect(d.states.map((s) => s.name), containsAll(['A', 'B']));
    });

    test('S10 composite states with #color and -[hidden]-> arrows', () {
      final d = parseState('@startuml\n'
          'state CurrentSite #pink {\n'
          '  state HardwareSetup #lightblue {\n'
          '    state Site #brown\n'
          '    Site -[hidden]-> Controller\n'
          '    Controller -[hidden]-> Devices\n'
          '  }\n'
          '  state PresentationSetup{\n'
          '    Groups -[hidden]-> PlansAndGraphics\n'
          '  }\n'
          '  state Trends #FFFF77\n'
          '  state Schedule #magenta\n'
          '  state AlarmSupression\n'
          '}\n'
          '@enduml\n');
      expect(d.states.single.name, 'CurrentSite');
    });
  });

  group('component diagram', () {
    ComponentDiagram parseComponent(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as ComponentDiagram;
    }

    test('parses bare component declaration', () {
      final d = parseComponent('@startuml\ncomponent Web\n@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'Web');
      expect(n.label, 'Web');
      expect(n.kind, ComponentNodeKind.component);
    });

    test('parses component with display name and alias', () {
      final d = parseComponent('@startuml\n'
          'component "Web Server" as Web\n'
          '@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'Web');
      expect(n.label, 'Web Server');
      expect(n.kind, ComponentNodeKind.component);
    });

    test('parses [Name] bracket shorthand', () {
      final d = parseComponent('@startuml\n[Auth Service]\n@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'Auth Service');
      expect(n.kind, ComponentNodeKind.component);
    });

    test('parses [Name] bracket shorthand with alias', () {
      final d =
          parseComponent('@startuml\n[Cache Service] as Cache\n@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'Cache');
      expect(n.label, 'Cache Service');
      expect(n.kind, ComponentNodeKind.component);
    });

    test('parses interface declaration', () {
      final d = parseComponent('@startuml\n'
          'interface "HTTP API" as HTTP\n'
          'component Web\n'
          '@enduml\n');
      final iface = d.nodes.firstWhere((n) => n.alias == 'HTTP');
      expect(iface.label, 'HTTP API');
      expect(iface.kind, ComponentNodeKind.interface);
    });

    test('parses () interface shorthand', () {
      final d = parseComponent('@startuml\n'
          '() "REST" as REST\n'
          'component Web\n'
          '@enduml\n');
      final iface = d.nodes.firstWhere((n) => n.alias == 'REST');
      expect(iface.label, 'REST');
      expect(iface.kind, ComponentNodeKind.interface);
    });

    test('parses package container with bracketed components', () {
      final d = parseComponent('@startuml\n'
          'package "Backend" {\n'
          '  [Service A]\n'
          '  [Service B]\n'
          '}\n'
          '@enduml\n');
      expect(d.containers, hasLength(1));
      final c = d.containers.single;
      expect(c.label, 'Backend');
      expect(c.kind, ContainerKind.package);
      expect(c.nodeAliases, ['Service A', 'Service B']);
      expect(d.nodes.map((n) => n.alias), ['Service A', 'Service B']);
    });

    test('parses node container', () {
      final d = parseComponent('@startuml\n'
          'node "Server 1" {\n'
          '  [Process]\n'
          '}\n'
          '@enduml\n');
      expect(d.containers.single.kind, ContainerKind.node);
      expect(d.containers.single.label, 'Server 1');
    });

    test('parses cloud container', () {
      final d = parseComponent('@startuml\n'
          'cloud "AWS" {\n'
          '  [Lambda]\n'
          '}\n'
          '@enduml\n');
      expect(d.containers.single.kind, ContainerKind.cloud);
    });

    test('parses frame container', () {
      final d = parseComponent('@startuml\n'
          'frame "Foo" {\n'
          '  [Bar]\n'
          '}\n'
          '@enduml\n');
      expect(d.containers.single.kind, ContainerKind.frame);
    });

    test('parses nested containers', () {
      final d = parseComponent('@startuml\n'
          'package "Outer" {\n'
          '  node "Inner" {\n'
          '    [Inside]\n'
          '  }\n'
          '}\n'
          '@enduml\n');
      expect(d.containers, hasLength(1));
      final outer = d.containers.single;
      expect(outer.kind, ContainerKind.package);
      expect(outer.nestedContainers, hasLength(1));
      final inner = outer.nestedContainers.single;
      expect(inner.kind, ContainerKind.node);
      expect(inner.nodeAliases, ['Inside']);
      expect(d.nodes.map((n) => n.alias), ['Inside']);
    });

    test('parses anonymous container without label', () {
      final d = parseComponent('@startuml\n'
          'package {\n'
          '  [A]\n'
          '}\n'
          '@enduml\n');
      expect(d.containers.single.label, isNull);
      expect(d.containers.single.nodeAliases, ['A']);
    });

    test('parses component relations with aliases and brackets', () {
      final d = parseComponent('@startuml\n'
          'component Web\n'
          'interface "HTTP API" as HTTP\n'
          '[DB]\n'
          'Web --> HTTP\n'
          'HTTP -- DB\n'
          '@enduml\n');
      expect(d.relations, hasLength(2));
      expect(d.relations[0].from, 'Web');
      expect(d.relations[0].to, 'HTTP');
      expect(d.relations[0].head, ArrowHead.open);
      expect(d.relations[1].head, isNull);
    });

    test('parses dashed dependency relation', () {
      final d = parseComponent('@startuml\n'
          '[A] ..> [B]\n'
          '@enduml\n');
      final r = d.relations.single;
      expect(r.from, 'A');
      expect(r.to, 'B');
      expect(r.lineStyle, LineStyle.dashed);
      expect(r.head, ArrowHead.open);
    });

    test('parses relation with label', () {
      final d = parseComponent('@startuml\n'
          '[A] --> [B] : uses\n'
          '@enduml\n');
      expect(d.relations.single.label, 'uses');
    });

    test('full spec example parses end-to-end', () {
      final d = parseComponent('@startuml\n'
          'component "Web Server" as Web\n'
          'component DB\n'
          '[Auth Service]\n'
          '[Cache Service] as Cache\n'
          'interface "HTTP API" as HTTP\n'
          '() "REST" as REST\n'
          'package "Backend" {\n'
          '  [Service A]\n'
          '  [Service B]\n'
          '}\n'
          'cloud "AWS" {\n'
          '  [Lambda]\n'
          '}\n'
          'node "Server 1" {\n'
          '  [Process]\n'
          '}\n'
          'Web --> HTTP\n'
          'HTTP -- [Auth Service]\n'
          '@enduml\n');
      expect(d.nodes.where((n) => n.kind == ComponentNodeKind.component),
          hasLength(8));
      expect(d.nodes.where((n) => n.kind == ComponentNodeKind.interface),
          hasLength(2));
      expect(d.containers, hasLength(3));
      expect(d.relations, hasLength(2));
    });

    test('component keyword routes to component diagram, not class', () {
      final tokens = Lexer().tokenize('@startuml\n'
          'component Foo\n'
          'interface Bar\n'
          '@enduml\n');
      final d = Parser().parse(tokens);
      expect(d, isA<ComponentDiagram>());
    });

    test('parses bracketed forms incl. \\n in name', () {
      // Bug 62: line-start `[Name]`, `[Name] as Alias`, `component Name`,
      // and `component [Name] as Alias` all parse, with `\n` literal
      // converted to a real newline inside the bracketed name.
      final d = parseComponent('@startuml\n'
          '[First component]\n'
          '[Another component] as Comp2\n'
          'component Comp3\n'
          'component [Last\\ncomponent] as Comp4\n'
          '@enduml\n');
      expect(d.nodes.map((n) => n.alias).toList(),
          ['First component', 'Comp2', 'Comp3', 'Comp4']);
      final comp4 = d.nodes.firstWhere((n) => n.alias == 'Comp4');
      expect(comp4.label, 'Last\ncomponent');
    });

    test('parses \$-prefixed names and remove directive', () {
      // Bug 63: `$` identifier-start, standalone bare reference, and
      // `remove <name>` directives all parse without error.
      final d = parseComponent('@startuml\n'
          'component [\$C1]\n'
          'component [\$C2]\n'
          '\$C2\n'
          'component [\$C2] as dollarC2\n'
          'remove \$C1\n'
          'remove \$C2\n'
          'remove dollarC2\n'
          '@enduml\n');
      // Components with bracketed `$C1`, `$C2` and aliased `dollarC2`.
      final aliases = d.nodes.map((n) => n.alias).toSet();
      expect(aliases.contains('\$C1'), isTrue);
      expect(aliases.contains('\$C2'), isTrue);
      expect(aliases.contains('dollarC2'), isTrue);
    });

    test('parses backward interface arrows with bracketed source', () {
      // Bug 64: `<--` and `<-` arrows with bare interface identifiers on
      // the left and bracketed components on the right parse as a
      // component diagram (not sequence).
      final d = parseComponent('@startuml\n'
          'Interface1 <-- [Component]\n'
          'Interface2 <- [Component]\n'
          '@enduml\n');
      expect(d.relations, hasLength(2));
    });

    test('bracketed shorthand routes to component diagram', () {
      final tokens = Lexer().tokenize('@startuml\n'
          '[A]\n'
          '[B]\n'
          '[A] --> [B]\n'
          '@enduml\n');
      final d = Parser().parse(tokens);
      expect(d, isA<ComponentDiagram>());
    });

    test('database keyword parses as database node when not a container', () {
      final d = parseComponent('@startuml\n'
          'package "P" {\n'
          '  [A]\n'
          '}\n'
          'database "Orders DB" as ODB\n'
          '@enduml\n');
      final n = d.nodes.firstWhere((n) => n.alias == 'ODB');
      expect(n.label, 'Orders DB');
      expect(n.kind, ComponentNodeKind.database);
    });

    test('queue keyword parses as queue node when not a container', () {
      final d = parseComponent('@startuml\n'
          'package "P" {\n'
          '  [A]\n'
          '}\n'
          'queue "Q" as QQ\n'
          '@enduml\n');
      final n = d.nodes.firstWhere((n) => n.alias == 'QQ');
      expect(n.label, 'Q');
      expect(n.kind, ComponentNodeKind.queue);
    });

    test('storage keyword parses as storage node when not a container', () {
      final d = parseComponent('@startuml\n'
          'package "P" {\n'
          '  [A]\n'
          '}\n'
          'storage "Object Store" as S3\n'
          '@enduml\n');
      final n = d.nodes.firstWhere((n) => n.alias == 'S3');
      expect(n.label, 'Object Store');
      expect(n.kind, ComponentNodeKind.storage);
    });

    test('storage keyword nested inside a node container', () {
      final d = parseComponent('@startuml\n'
          'node "Server" {\n'
          '  storage "Object Store" as S3\n'
          '}\n'
          '@enduml\n');
      expect(d.containers, hasLength(1));
      expect(d.containers.single.nodeAliases, ['S3']);
      final n = d.nodes.firstWhere((n) => n.alias == 'S3');
      expect(n.kind, ComponentNodeKind.storage);
    });

    test('storage with a body parses as a container', () {
      final d = parseComponent('@startuml\n'
          'storage "Bucket" {\n'
          '  [Object1]\n'
          '}\n'
          '@enduml\n');
      expect(d.containers.single.kind, ContainerKind.storage);
      expect(d.containers.single.label, 'Bucket');
    });

    test('deeply nested containers (4 levels) parse', () {
      final d = parseComponent('@startuml\n'
          'frame "AWS" {\n'
          '  node "VPC" {\n'
          '    node "Subnet" {\n'
          '      node "Pod" {\n'
          '        component "Web" as W\n'
          '      }\n'
          '    }\n'
          '  }\n'
          '}\n'
          '@enduml\n');
      expect(d.containers, hasLength(1));
      final frame = d.containers.single;
      expect(frame.nestedContainers, hasLength(1));
      final vpc = frame.nestedContainers.single;
      expect(vpc.nestedContainers, hasLength(1));
      final subnet = vpc.nestedContainers.single;
      expect(subnet.nestedContainers, hasLength(1));
      final pod = subnet.nestedContainers.single;
      expect(pod.nodeAliases, ['W']);
    });

    test('cloud container as alias is captured on the container', () {
      final d = parseComponent('@startuml\n'
          'cloud "Payment Gateway" as PG\n'
          '[A] --> PG\n'
          '@enduml\n');
      expect(d.containers.single.alias, 'PG');
      expect(d.relations.single.to, 'PG');
    });
  });

  group('deployment / artifact', () {
    ComponentDiagram parseDeployment(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as ComponentDiagram;
    }

    test('parses bare artifact declaration', () {
      final d = parseDeployment('@startuml\nartifact Foo\n@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'Foo');
      expect(n.label, 'Foo');
      expect(n.kind, ComponentNodeKind.artifact);
    });

    test('parses artifact with display name and alias', () {
      final d = parseDeployment('@startuml\n'
          'artifact "config.yml" as Config\n'
          '@enduml\n');
      final n = d.nodes.single;
      expect(n.alias, 'Config');
      expect(n.label, 'config.yml');
      expect(n.kind, ComponentNodeKind.artifact);
    });

    test('artifact-only source routes to component diagram', () {
      final tokens = Lexer().tokenize('@startuml\n'
          'artifact Foo\n'
          'artifact Bar\n'
          '@enduml\n');
      final d = Parser().parse(tokens);
      expect(d, isA<ComponentDiagram>());
    });

    test('artifact mixes with components and nodes inside a node container',
        () {
      final d = parseDeployment('@startuml\n'
          'node "Web Server" {\n'
          '  component Apache\n'
          '  artifact "config.yml" as Config\n'
          '}\n'
          'Apache --> Config\n'
          '@enduml\n');
      expect(d.containers, hasLength(1));
      expect(d.containers.single.nodeAliases, ['Apache', 'Config']);
      final apache = d.nodes.firstWhere((n) => n.alias == 'Apache');
      final config = d.nodes.firstWhere((n) => n.alias == 'Config');
      expect(apache.kind, ComponentNodeKind.component);
      expect(config.kind, ComponentNodeKind.artifact);
      expect(config.label, 'config.yml');
      expect(d.relations.single.from, 'Apache');
      expect(d.relations.single.to, 'Config');
    });
  });

  group('timing diagram', () {
    TimingDiagram parseTiming(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as TimingDiagram;
    }

    test('parses robust and concise lane declarations', () {
      final d = parseTiming('@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "User"\n'
          '@enduml\n');
      expect(d.lanes, hasLength(2));
      expect(d.lanes[0].kind, TimingLaneKind.robust);
      expect(d.lanes[0].alias, 'WB');
      expect(d.lanes[0].label, 'Web Browser');
      expect(d.lanes[1].kind, TimingLaneKind.concise);
      expect(d.lanes[1].alias, 'User');
      expect(d.lanes[1].label, 'User');
    });

    test('parses clock lane with period', () {
      final d = parseTiming('@startuml\n'
          'clock "Clock" with period 50\n'
          '@enduml\n');
      expect(d.lanes.single.kind, TimingLaneKind.clock);
      expect(d.lanes.single.clockPeriod, 50);
    });

    test('parses @time markers and state changes', () {
      final d = parseTiming('@startuml\n'
          'robust "WB" as WB\n'
          '@0\n'
          'WB is Idle\n'
          '@100\n'
          'WB is Loading\n'
          '@enduml\n');
      expect(d.events, hasLength(2));
      final first = d.events[0] as StateChange;
      expect(first.time, 0);
      expect(first.lane, 'WB');
      expect(first.state, 'Idle');
      final second = d.events[1] as StateChange;
      expect(second.time, 100);
      expect(second.state, 'Loading');
    });

    test('parses arrow annotation between lanes', () {
      final d = parseTiming('@startuml\n'
          'robust "WB" as WB\n'
          'concise "User"\n'
          '@100\n'
          'User -> WB : open\n'
          '@enduml\n');
      expect(d.events, hasLength(1));
      final arrow = d.events.single as TimingArrow;
      expect(arrow.time, 100);
      expect(arrow.from, 'User');
      expect(arrow.to, 'WB');
      expect(arrow.label, 'open');
    });

    test('discriminator routes timing source to TimingDiagram', () {
      final tokens = Lexer().tokenize('@startuml\n'
          'robust "WB" as WB\n'
          '@0\n'
          'WB is Idle\n'
          '@enduml\n');
      final d = Parser().parse(tokens);
      expect(d, isA<TimingDiagram>());
    });

    // Sources 66.1-66.11 from the timing-diagram regression set. Each test
    // pins down the minimum-viable contract: the source parses without
    // throwing. Visual rendering of the new constructs is deferred.
    test('66.1 clock with period, labeled anchors and arithmetic', () {
      const src = '@startuml\n'
          'clock clk with period 1\n'
          'binary "enable" as EN\n'
          'concise "dataBus" as db\n'
          '@0 as :start\n'
          '@5 as :en_high\n'
          '@10 as :en_low\n'
          '@:en_high-2 as :en_highMinus2\n'
          '@:start\n'
          'EN is low\n'
          'db is "0x0000"\n'
          '@:en_high\n'
          'EN is high\n'
          '@:en_low\n'
          'EN is low\n'
          '@:en_highMinus2\n'
          'db is "0xf23a"\n'
          '@:en_high+6\n'
          'db is "0x0000"\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.2 relative +N anchors within @<lane> focus', () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          '@WB\n'
          '0 is idle\n'
          '+200 is Proc.\n'
          '+100 is Waiting\n'
          '@WU\n'
          '0 is Waiting\n'
          '+500 is ok\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.3 multi-value {low,high} state', () {
      const src = '@startuml\n'
          'clock "Clock" as C with period 2\n'
          'binary "Enable" as EN\n'
          '@0\n'
          'EN is low\n'
          '@1\n'
          'EN is high\n'
          '@3\n'
          'EN is low\n'
          '@5\n'
          'EN is {low,high}\n'
          '@10\n'
          'EN is low\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.4 negative time anchor @-200', () {
      const src = '@startuml\n'
          'robust "R-Deci" as RD\n'
          'concise "R-Algo-0" as RA0\n'
          'robust "R-Algo-1" as RA1\n'
          '@200\n'
          'RD is 0\n'
          'RA0 is 0\n'
          '@-200\n'
          'RD is 1\n'
          'RA0 is 3\n'
          '@100\n'
          'RD is 0\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.5 H:M:S time format with note-on-state', () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          '@1:15:00\n'
          'WU is Idle\n'
          'WB is Idle\n'
          '@1:16:30\n'
          'WU is Waiting : some note\n'
          'WB is Processing : some other note\n'
          '@1:17:30\n'
          'WB is Waiting\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.6 date format anchors with scale/manual/use directives', () {
      const src = '@startuml\n'
          'scale 31536000 as 40 pixels\n'
          'manual time-axis\n'
          'use date format "yy-MM"\n'
          'concise "OpenGL Desktop" as OD\n'
          '@1992/01/01\n'
          'OD is {hidden}\n'
          '@1992/06/30\n'
          'OD is 1.0\n'
          '@1997/03/04\n'
          'OD is 1.1\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.7 note top/bottom of <lane>', () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          '@0\n'
          'WU is Idle\n'
          'WB is Idle\n'
          '@100\n'
          'WU is Waiting\n'
          'WB is Processing\n'
          r'note top of WU : first note\non several\nlines'
          '\n'
          r'note bottom of WU : second note\non several\nlines'
          '\n'
          '@300\n'
          'WB is Waiting\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.8 highlight ranges and cross-lane annotation arrows', () {
      const src = '@startuml\n'
          'scale 5 as 150 pixels\n'
          'clock clk with period 1\n'
          'binary "enable" as en\n'
          'concise "dataBus" as db\n'
          'concise "address bus" as addr\n'
          '@0\n'
          'en is low\n'
          'db is "0x0"\n'
          'addr is "0x03f4"\n'
          '@5 as :write_beg\n'
          'en is high\n'
          'db is "0xf23a"\n'
          'addr is "0x0300"\n'
          '@10 as :write_end\n'
          'en is low\n'
          '@15 as :read_beg\n'
          'addr is "0x0301"\n'
          '@20 as :read_end\n'
          'en is high\n'
          'highlight :write_beg to :write_end #Gold:Write\n'
          'highlight :read_beg to :read_end #lightBlue:Read\n'
          'db@:write_beg-1 <-> @:write_end : setup time\n'
          'db@:write_beg-1 -> addr@:write_end+1 : hold\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.9 mode compact directive', () {
      const src = '@startuml\n'
          'mode compact\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          'robust "Web Browser2" as WB2\n'
          '@0\n'
          'WU is Waiting\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('66.10 analog lane type', () {
      const src = '@startuml\n'
          'title Between 0-max (by default)\n'
          'analog "Analog" as A\n'
          '@0\n'
          'A is 350\n'
          '@100\n'
          'A is 450\n'
          '@300\n'
          'A is 350\n'
          '@enduml\n';
      final d = parseTiming(src);
      expect(d.lanes.single.kind, TimingLaneKind.analog);
    });

    test('66.11 analog with cross-lane arrows', () {
      const src = '@startuml\n'
          'analog "Vcore" as VDD\n'
          'analog "VCC" as VCC\n'
          '@0\n'
          'VDD is 0\n'
          'VCC is 3\n'
          '@2\n'
          'VDD is 0\n'
          '@3\n'
          'VDD is 6\n'
          'VCC is 6\n'
          'VDD@1 -> VCC@2 : "test"\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T1 rectangle lane type parses', () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          'rectangle "Rect. Web User" as RWU\n'
          '@0\n'
          'WU is Idle\n'
          'RWU is Idle\n'
          'WB is Idle\n'
          '@100\n'
          'WU is Waiting\n'
          'RWU is Waiting\n'
          'WB is Processing\n'
          '@300\n'
          'WB is Waiting\n'
          '@enduml\n';
      final d = parseTiming(src);
      expect(d.lanes, hasLength(3));
      expect(d.lanes[2].kind, TimingLaneKind.rectangle);
      expect(d.lanes[2].alias, 'RWU');
    });

    test('T2 clock with period N pulse M offset O parses', () {
      const src = '@startuml\n'
          'clock "Clock_0" as C0 with period 50\n'
          'clock "Clock_1" as C1 with period 50 pulse 15 offset 10\n'
          'binary "Binary" as B\n'
          '@0\n'
          'B is high\n'
          '@enduml\n';
      final d = parseTiming(src);
      expect(d.lanes, hasLength(3));
      expect(d.lanes[0].kind, TimingLaneKind.clock);
      expect(d.lanes[0].clockPeriod, 50);
      expect(d.lanes[1].kind, TimingLaneKind.clock);
      expect(d.lanes[1].clockPeriod, 50);
    });

    test('T4 decimal time anchors parse', () {
      const src = '@startuml\n'
          'binary "enable" as EN\n'
          '@3 as :start\n'
          '@5.5 as :en_high\n'
          '@10 as :en_low\n'
          '@:en_high-2 as :en_highMinus2\n'
          '@:start\n'
          'EN is low\n'
          '@:en_high+1.2\n'
          'EN is high\n'
          '@10.5\n'
          'EN is low\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T5 has value enumeration parses', () {
      const src = '@startuml\n'
          'robust "Signal1" as S1\n'
          'robust "Signal2" as S2\n'
          'S1 has 0,1,2,hello\n'
          'S2 has 0,1,2\n'
          '@0\n'
          'S1 is 0\n'
          'S2 is 0\n'
          '@100\n'
          'S1 is {0,1} #SlateGrey\n'
          'S2 is {0,1}\n'
          '@200\n'
          'S1 is 1\n'
          'S2 is 0\n'
          '@300\n'
          'S1 is hello\n'
          'S2 is {0,2}\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T6 {-} shorthand and {hidden} parse', () {
      const src = '@startuml\n'
          'concise "Web User" as WU\n'
          '@0\n'
          'WU is {-}\n'
          '@100\n'
          'WU is A1\n'
          '@200\n'
          'WU is {-}\n'
          '@300\n'
          'WU is {hidden}\n'
          '@400\n'
          'WU is A3\n'
          '@500\n'
          'WU is {-}\n'
          '@enduml\n';
      final d = parseTiming(src);
      // `{-}` should be normalized to `{hidden}`.
      final hiddenChanges = d.events
          .whereType<StateChange>()
          .where((e) => e.state == '{hidden}')
          .toList();
      expect(hiddenChanges, hasLength(4));
    });

    test('T3 cross-lane message mid-lane parses', () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          'rectangle "Rect. Web User" as RWU\n'
          '@0\n'
          'WU is Idle\n'
          'RWU is Idle\n'
          'WB is Idle\n'
          '@100\n'
          'WU -> WB : URL\n'
          'WU is Waiting\n'
          'RWU is Waiting\n'
          'WB is Processing\n'
          '@300\n'
          'WB is Waiting\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T7 @lane focus with integer anchors and {hidden} parses', () {
      const src = '@startuml\n'
          'scale 1 as 50 pixels\n'
          'concise state0\n'
          'concise substate1\n'
          'robust bit2\n'
          'bit2 has HIGH,LOW\n'
          '@state0\n'
          '0 is 18_start\n'
          '6 is s_dPause\n'
          '8 is 10_data\n'
          '14 is {hidden}\n'
          '@substate1\n'
          '0 is sSeq\n'
          '4 is sPause\n'
          '6 is {hidden}\n'
          '8 is dSeq\n'
          '12 is dPause\n'
          '14 is {hidden}\n'
          '@bit2\n'
          '0 is HIGH\n'
          '2 is LOW\n'
          '4 is {hidden}\n'
          '8 is HIGH\n'
          '10 is LOW\n'
          '12 is {hidden}\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T8 <-> annotation arrows with {label} and relative anchor parse',
        () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          'WB is Initializing\n'
          'WU is Absent\n'
          '@WB\n'
          '0 is idle\n'
          '+200 is Processing\n'
          '+100 is Waiting\n'
          'WB@0 <-> @50 : {50 ms lag}\n'
          '@WU\n'
          '0 is Waiting\n'
          '+500 is ok\n'
          '@200 <-> @+150 : {150 ms}\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T9 inline styles on is value and highlight ranges parse', () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          '@0\n'
          'WU is Idle\n'
          'WB is Idle\n'
          '@100\n'
          'WU -> WB : URL\n'
          'WU is Waiting #LightCyan;line:Aqua\n'
          '@200\n'
          'WB is Proc.\n'
          '@300\n'
          'WU -> WB@350 : URL2\n'
          'WB is Waiting\n'
          '@+200\n'
          'WU is ok\n'
          '@+200\n'
          'WB is Idle\n'
          'highlight 200 to 450 #Gold;line:DimGrey : This is my caption\n'
          'highlight 600 to 700 : This is another\\nhighlight\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T10 title/header/footer/legend/caption alongside timing parse', () {
      const src = '@startuml\n'
          'Title This is my title\n'
          'header: some header\n'
          'footer: some footer\n'
          'legend\n'
          'Some legend\n'
          'end legend\n'
          'caption some caption\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          '@0\n'
          'WU is Idle\n'
          'WB is Idle\n'
          '@100\n'
          'WU is Waiting\n'
          'WB is Processing\n'
          '@300\n'
          'WB is Waiting\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    // Sources T11-T22 cover advanced timing-diagram constructs from the
    // regression set. Each pins down the minimum-viable contract: the source
    // parses without throwing. Visual rendering of the new constructs is
    // deferred.
    test('T11 HTTP cache detailed timing with @+N cross-lane target parses',
        () {
      const src = '@startuml\n'
          'concise "Client" as Client\n'
          'concise "Server" as Server\n'
          'concise "Response freshness" as Cache\n'
          'Server is idle\n'
          'Client is idle\n'
          '@Client\n'
          '0 is send\n'
          'Client -> Server@+25 : GET\n'
          '+25 is await\n'
          '+75 is recv\n'
          '+25 is idle\n'
          '+25 is send\n'
          'Client -> Server@+25 : GET\\nIf-Modified-Since: 150\n'
          '+25 is await\n'
          '+50 is recv\n'
          '+25 is idle\n'
          '@100 <-> @275 : no need to re-request from server\n'
          '@Server\n'
          '25 is recv\n'
          '+25 is work\n'
          '+25 is send\n'
          'Server -> Client@+25 : 200 OK\\nExpires: 275\n'
          '+25 is idle\n'
          '+75 is recv\n'
          '+25 is send\n'
          'Server -> Client@+25 : 304 Not Modified\n'
          '+25 is idle\n'
          '@Cache\n'
          '75 is fresh\n'
          '+200 is stale\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T12 inline color on initial state parses', () {
      const src = '@startuml\n'
          'concise "LR" as LR\n'
          'concise "ST" as ST\n'
          'LR is AtPlace #palegreen\n'
          'ST is AtLoad #gray\n'
          '@LR\n'
          '0 is Lowering\n'
          '100 is Lowered #pink\n'
          '350 is Releasing\n'
          '@ST\n'
          '200 is Moving\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T13 <-> annotation arrows (regression) parses', () {
      const src = '@startuml\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          'WB is Initializing\n'
          'WU is Absent\n'
          '@WB\n'
          '0 is idle\n'
          '+200 is Processing\n'
          '+100 is Waiting\n'
          'WB@0 <-> @50 : {50 ms lag}\n'
          '@WU\n'
          '0 is Waiting\n'
          '+500 is ok\n'
          '@200 <-> @+150 : {150 ms}\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T14 <style> block with nested element rules parses', () {
      const src = '@startuml\n'
          '<style>\n'
          'timingDiagram {\n'
          '  document {\n'
          '    BackGroundColor SandyBrown\n'
          '  }\n'
          '  constraintArrow {\n'
          '    LineStyle 2-1\n'
          '    LineThickness 3\n'
          '    LineColor Blue\n'
          '  }\n'
          '}\n'
          '</style>\n'
          'robust "Web Browser" as WB\n'
          'concise "Web User" as WU\n'
          'WB is Initializing\n'
          'WU is Absent\n'
          '@WB\n'
          '0 is idle\n'
          '+200 is Processing\n'
          '+100 is Waiting\n'
          'WB@0 <-> @50 : {50 ms lag}\n'
          '@WU\n'
          '0 is Waiting\n'
          '+500 is ok\n'
          '@200 <-> @+150 : {150 ms}\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T15 <style> with .class and <<class>> reference on lane parses', () {
      const src = '@startuml\n'
          '<style>\n'
          'timingDiagram {\n'
          '  .red {\n'
          '    LineColor red\n'
          '  }\n'
          '  .blue {\n'
          '    LineColor blue\n'
          '    LineThickness 5\n'
          '  }\n'
          '}\n'
          '</style>\n'
          'clock clk with period 1\n'
          'binary "Input Signal 1" as IS1\n'
          'binary "Input Signal 2" as IS2 <<blue>>\n'
          'binary "Output Signal 1" as OS1 <<red>>\n'
          '@0\n'
          'IS1 is low\n'
          'IS2 is high\n'
          'OS1 is low\n'
          '@2\n'
          'OS1 is high\n'
          '@4\n'
          'OS1 is low\n'
          '@5\n'
          'IS1 is high\n'
          'OS1 is high\n'
          '@6\n'
          'IS2 is low\n'
          '@10\n'
          'IS1 is low\n'
          'OS1 is low\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T16 compact modifier prefix on lane declaration parses', () {
      const src = '@startuml\n'
          'compact robust "Web Browser" as WB\n'
          'compact concise "Web User" as WU\n'
          'robust "Web Browser2" as WB2\n'
          '@0\n'
          'WU is Waiting\n'
          'WB is Idle\n'
          'WB2 is Idle\n'
          '@200\n'
          'WB is Proc.\n'
          '@300\n'
          'WB is Waiting\n'
          'WB2 is Waiting\n'
          '@500\n'
          'WU is ok\n'
          '@700\n'
          'WB is Idle\n'
          '@enduml\n';
      final d = parseTiming(src);
      expect(d.lanes, hasLength(3));
      expect(d.lanes[0].alias, 'WB');
      expect(d.lanes[1].alias, 'WU');
      expect(d.lanes[2].alias, 'WB2');
    });

    test('T17 analog "X" between A and B as Y parses', () {
      const src = '@startuml\n'
          'title Between min-max\n'
          'analog "Analog" between 350 and 450 as A\n'
          '@0\n'
          'A is 350\n'
          '@100\n'
          'A is 450\n'
          '@300\n'
          'A is 350\n'
          '@enduml\n';
      final d = parseTiming(src);
      expect(d.lanes.single.kind, TimingLaneKind.analog);
      expect(d.lanes.single.alias, 'A');
    });

    test('T18 analog between with negative bounds + ticks + pixels height '
        'parses', () {
      const src = '@startuml\n'
          'analog "Vcore" as VDD\n'
          'analog "VCC" between -4.5 and 6.5 as VCC\n'
          'VCC ticks num on multiple 3\n'
          'VCC is 200 pixels height\n'
          '@0\n'
          'VDD is 0\n'
          'VCC is 3\n'
          '@2\n'
          'VDD is 0\n'
          '@3\n'
          'VDD is 6\n'
          'VCC is 6\n'
          'VDD@1 -> VCC@2 : "test"\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T19 has comma-separated enumeration of values parses', () {
      const src = '@startuml\n'
          'robust "Flow rate" as rate\n'
          'rate has high,low,none\n'
          '@0\n'
          'rate is high\n'
          '@5\n'
          'rate is none\n'
          '@6\n'
          'rate is low\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T20 has "label" as alias enumeration parses', () {
      const src = '@startuml\n'
          'robust "Flow rate" as rate\n'
          'rate has "35 gpm" as high\n'
          'rate has "15 gpm" as low\n'
          'rate has "0 gpm" as none\n'
          '@0\n'
          'rate is high\n'
          '@5\n'
          'rate is none\n'
          '@6\n'
          'rate is low\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T21 @clk*N clock multiplier anchor parses', () {
      const src = '@startuml\n'
          'clock "clk" as clk with period 50\n'
          'concise "Signal1" as S1\n'
          'robust "Signal2" as S2\n'
          'binary "Signal3" as S3\n'
          '@clk*0\n'
          'S1 is 0\n'
          'S2 is 0\n'
          '@clk*1\n'
          'S1 is 1\n'
          'S3 is high\n'
          '@clk*2\n'
          'S3 is down\n'
          '@clk*3\n'
          'S1 is 1\n'
          'S2 is 1\n'
          'S3 is 1\n'
          '@clk*4\n'
          'S3 is down\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });

    test('T22 inline `: description` after state and top-level <-> '
        'annotation parses', () {
      const src = '@startuml\n'
          'binary "Binary Serial Data" as D\n'
          'robust "Robust" as R\n'
          'concise "Concise" as C\n'
          '@-3\n'
          'D is low: idle\n'
          'R is lo: idle\n'
          'C is 1: idle\n'
          '@-1\n'
          'D is high: start\n'
          'R is hi: start\n'
          'C is 0: start\n'
          '@0\n'
          'D is low: 1 lsb\n'
          'R is lo: 1 lsb\n'
          'C is 1: lsb\n'
          '@1\n'
          'D is high: 0\n'
          'R is hi: 0\n'
          'C is 0\n'
          '@6\n'
          'D is low: 1\n'
          'R is lo: 1\n'
          'C is 1\n'
          '@7\n'
          'D is high: 0 msb\n'
          'R is hi: 0 msb\n'
          'C is 0: msb\n'
          '@8\n'
          'D is low: stop\n'
          'R is lo: stop\n'
          'C is 1: stop\n'
          '@0 <-> @8 : Serial data bits for ASCII "A" (Little Endian)\n'
          '@enduml\n';
      expect(() => parseTiming(src), returnsNormally);
    });
  });

  group('mindmap diagram', () {
    MindmapDiagram parseMindmap(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as MindmapDiagram;
    }

    test('parses root only', () {
      final d = parseMindmap('@startmindmap\n* Root\n@endmindmap\n');
      expect(d.root, isNotNull);
      expect(d.root!.text, 'Root');
      expect(d.root!.depth, 1);
      expect(d.root!.children, isEmpty);
    });

    test('parses a tree with multiple depths', () {
      final d = parseMindmap('@startmindmap\n'
          '* Root\n'
          '** Branch A\n'
          '*** Leaf A1\n'
          '*** Leaf A2\n'
          '** Branch B\n'
          '@endmindmap\n');
      final root = d.root!;
      expect(root.text, 'Root');
      expect(root.children.map((c) => c.text), ['Branch A', 'Branch B']);
      final branchA = root.children[0];
      expect(branchA.depth, 2);
      expect(branchA.children.map((c) => c.text), ['Leaf A1', 'Leaf A2']);
    });

    test('parses + and - side prefixes', () {
      final d = parseMindmap('@startmindmap\n'
          '* Root\n'
          '+** Right\n'
          '-** Left\n'
          '@endmindmap\n');
      final root = d.root!;
      expect(root.children, hasLength(2));
      expect(root.children[0].text, 'Right');
      expect(root.children[0].side, MindmapSide.right);
      expect(root.children[1].text, 'Left');
      expect(root.children[1].side, MindmapSide.left);
    });

    test('parses color modifier', () {
      final d = parseMindmap('@startmindmap\n'
          '* Root\n'
          '**[#FF0000] Red node\n'
          '@endmindmap\n');
      final node = d.root!.children.single;
      expect(node.text, 'Red node');
      expect(node.color, const Color(0xFFFF0000));
    });

    test('accepts multiple depth-1 nodes by attaching to first root', () {
      // PlantUML mindmap sources in the wild sometimes use bare `*` for every
      // level, relying on document order rather than marker depth to convey
      // hierarchy. The mindmap parser is intentionally lenient here (matching
      // the WBS parser): additional depth-1 nodes become children of the
      // initial root rather than triggering a "may have only one root node"
      // error.
      final d = parseMindmap('@startmindmap\n* One\n* Two\n@endmindmap\n');
      expect(d.root, isNotNull);
      expect(d.root!.text, 'One');
      expect(d.root!.children.map((c) => c.text), ['Two']);
    });

    test('accepts flat depth-1 mindmap with styled nodes', () {
      // Verbatim reproduction of a user-reported source that previously failed
      // with "Mindmap may have only one root node". After the lenient fix
      // (W2), the source parses without throwing.
      const source = '@startmindmap\n'
          '<style>\n'
          'mindmapDiagram {\n'
          '.green { BackgroundColor lightgreen }\n'
          '.rose { BackgroundColor #FFBBCC }\n'
          '.your_style_name { BackgroundColor lightblue }\n'
          '}\n'
          '</style>\n'
          '* root node\n'
          '* some first level node <<green>>\n'
          '* second level node <<rose>>\n'
          '* another second level node <<your_style_name>>\n'
          '* another first level node <<green>>\n'
          '@endmindmap\n';
      expect(() => parseMindmap(source), returnsNormally);
    });
  });

  group('wbs diagram', () {
    WbsDiagram parseWbs(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as WbsDiagram;
    }

    test('parses root only', () {
      final d = parseWbs('@startwbs\n* Root\n@endwbs\n');
      expect(d.root, isNotNull);
      expect(d.root!.text, 'Root');
      expect(d.root!.depth, 1);
      expect(d.root!.children, isEmpty);
    });

    test('parses a tree with multiple depths', () {
      final d = parseWbs('@startwbs\n'
          '* Business Plan\n'
          '** Goals\n'
          '*** Increase sales\n'
          '*** Reduce costs\n'
          '** Risks\n'
          '*** Market risk\n'
          '** Schedule\n'
          '@endwbs\n');
      final root = d.root!;
      expect(root.text, 'Business Plan');
      expect(
        root.children.map((c) => c.text),
        ['Goals', 'Risks', 'Schedule'],
      );
      final goals = root.children[0];
      expect(goals.depth, 2);
      expect(
        goals.children.map((c) => c.text),
        ['Increase sales', 'Reduce costs'],
      );
      final risks = root.children[1];
      expect(risks.children.map((c) => c.text), ['Market risk']);
      expect(root.children[2].children, isEmpty);
    });

    test('accepts multiple depth-1 nodes by attaching to first root', () {
      // PlantUML WBS sources in the wild sometimes use bare `*` (or `+`)
      // for every level, relying on document order rather than marker depth
      // to convey hierarchy. The WBS parser is intentionally lenient here:
      // additional depth-1 nodes become children of the initial root rather
      // than triggering a "may have only one root node" error.
      final d = parseWbs('@startwbs\n* One\n* Two\n@endwbs\n');
      expect(d.root, isNotNull);
      expect(d.root!.text, 'One');
      expect(d.root!.children.map((c) => c.text), ['Two']);
    });

    test('parses +/- depth markers (PlantUML WBS syntax)', () {
      const source = '@startwbs\n'
          '+ New Job\n'
          '++ Decide on Job Requirements\n'
          '+++ Identity gaps\n'
          '+++ Review JDs\n'
          '++++ Sign-Up for courses\n'
          '++++ Volunteer\n'
          '++++ Reading\n'
          '++- Checklist\n'
          '+++- Responsibilities\n'
          '+++- Location\n'
          '++ CV Upload Done\n'
          '+++ CV Updated\n'
          '++++ Spelling & Grammar\n'
          '++++ Check dates\n'
          '---- Skills\n'
          '+++ Recruitment sites chosen\n'
          '@endwbs\n';
      final d = parseWbs(source);
      final root = d.root!;
      expect(root.text, 'New Job');
      expect(root.depth, 1);

      int count(MindmapNode n) =>
          1 + n.children.fold<int>(0, (a, c) => a + count(c));
      expect(count(root), 16);
    });
  });

  group('json diagram', () {
    DataDiagram parseJson(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as DataDiagram;
    }

    test('parses a flat object preserving key order', () {
      final d = parseJson('@startjson\n'
          '{"name": "Alice", "age": 30}\n'
          '@endjson\n');
      expect(d.format, DataFormat.json);
      final root = d.root as DataObject;
      expect(root.entries.map((e) => e.key), ['name', 'age']);
      final name = root.entries[0].value as DataScalar;
      expect(name.kind, ScalarKind.string);
      expect(name.value, 'Alice');
      final age = root.entries[1].value as DataScalar;
      expect(age.kind, ScalarKind.number);
      expect(age.value, '30');
    });

    test('parses nested objects', () {
      final d = parseJson('@startjson\n'
          '{"address": {"city": "Seoul", "zip": "12345"}}\n'
          '@endjson\n');
      final root = d.root as DataObject;
      final addr = root.entries.single.value as DataObject;
      expect(addr.entries.map((e) => e.key), ['city', 'zip']);
    });

    test('parses arrays and scalar kinds', () {
      final d = parseJson('@startjson\n'
          '{"tags": ["admin", "user"], "active": true, "ref": null}\n'
          '@endjson\n');
      final root = d.root as DataObject;
      final tags = root.entries[0].value as DataArray;
      expect(tags.items, hasLength(2));
      final t0 = tags.items[0] as DataScalar;
      expect(t0.value, 'admin');
      expect(t0.kind, ScalarKind.string);
      final active = root.entries[1].value as DataScalar;
      expect(active.kind, ScalarKind.boolean);
      expect(active.value, 'true');
      final ref = root.entries[2].value as DataScalar;
      expect(ref.kind, ScalarKind.null_);
    });

    test('preserves order across multi-line input', () {
      final d = parseJson('@startjson\n'
          '{\n'
          '  "b": 1,\n'
          '  "a": 2,\n'
          '  "c": 3\n'
          '}\n'
          '@endjson\n');
      final root = d.root as DataObject;
      expect(root.entries.map((e) => e.key), ['b', 'a', 'c']);
    });

    test('rejects malformed JSON', () {
      expect(
        () => parseJson('@startjson\n{ bad }\n@endjson\n'),
        throwsA(isA<ParserException>()),
      );
    });

    test('accepts <style> block and #highlight directives (source 21)', () {
      final d = parseJson('@startjson\n'
          '<style>\n'
          '.h1 {\n'
          '  BackGroundColor green\n'
          '  FontColor white\n'
          '  FontStyle italic\n'
          '}\n'
          '.h2 {\n'
          '  BackGroundColor red\n'
          '  FontColor white\n'
          '  FontStyle bold\n'
          '}\n'
          '</style>\n'
          '#highlight "lastName"\n'
          '#highlight "address" / "city" <<h1>>\n'
          '#highlight "phoneNumbers" / "0" / "number" <<h2>>\n'
          '{\n'
          '  "firstName": "John",\n'
          '  "lastName": "Smith",\n'
          '  "address": {\n'
          '    "city": "Seoul"\n'
          '  },\n'
          '  "phoneNumbers": [\n'
          '    { "number": "555-1234" }\n'
          '  ]\n'
          '}\n'
          '@endjson\n');
      expect(d.format, DataFormat.json);
      final root = d.root as DataObject;
      expect(root.entries.map((e) => e.key),
          ['firstName', 'lastName', 'address', 'phoneNumbers']);
    });

    test('accepts nested jsonDiagram <style> block and #highlight (source 22)',
        () {
      final d = parseJson('@startjson\n'
          '<style>\n'
          'jsonDiagram {\n'
          '  node {\n'
          '    BackGroundColor Khaki\n'
          '    LineColor lightblue\n'
          '    separator {\n'
          '      LineThickness 0.5\n'
          '    }\n'
          '  }\n'
          '  arrow {\n'
          '    LineColor red\n'
          '  }\n'
          '  highlight {\n'
          '    BackGroundColor red\n'
          '  }\n'
          '}\n'
          '</style>\n'
          '#highlight "1" / "hr"\n'
          '[\n'
          '  { "name": "Mark McGwire", "hr": 65 },\n'
          '  { "name": "Sammy Sosa", "hr": 63 }\n'
          ']\n'
          '@endjson\n');
      expect(d.format, DataFormat.json);
      final root = d.root as DataArray;
      expect(root.items, hasLength(2));
    });
  });

  group('allowmixing + inline json regressions', () {
    Diagram parseAny(String src) {
      final tokens = Lexer().tokenize(src);
      return Parser().parse(tokens);
    }

    test('use case + allowmixing + json (source 20)', () {
      final d = parseAny('@startuml\n'
          'allowmixing\n'
          'actor Actor\n'
          'usecase Usecase\n'
          'json JSON {\n'
          '  "fruit":"Apple",\n'
          '  "size":"Large",\n'
          '  "color": ["Red", "Green"]\n'
          '}\n'
          '@enduml\n') as UseCaseDiagram;
      final aliases = d.nodes.map((n) => n.alias).toSet();
      expect(aliases, containsAll(<String>{'Actor', 'Usecase'}));
    });

    test('class + object + json without allowmixing (source 23)', () {
      final d = parseAny('@startuml\n'
          'class Class\n'
          'object Object\n'
          'json JSON {\n'
          '  "fruit":"Apple",\n'
          '  "size":"Large",\n'
          '  "color": ["Red", "Green"]\n'
          '}\n'
          '@enduml\n') as ClassDiagram;
      final names = d.classes.map((c) => c.name).toSet();
      expect(names, containsAll(<String>{'Class', 'Object'}));
    });

    test('inline json with title alias inside @startuml (source 24)', () {
      final d = parseAny('@startuml\n'
          'json "<b>JSON basic element" as J {\n'
          '  "null": null,\n'
          '  "true": true,\n'
          '  "false": false,\n'
          '  "JSON_Number": [-1, -1.1, "<color:green>TBC"],\n'
          '  "JSON_String": "a\\nb\\rc\\td <color:green>TBC...",\n'
          '  "JSON_Object": {\n'
          '    "{}": {},\n'
          '    "k_int": 123,\n'
          '    "k_str": "abc",\n'
          '    "k_obj": {"k": "v"}\n'
          '  },\n'
          '  "JSON_Array" : [\n'
          '    [],\n'
          '    [true, false],\n'
          '    [-1, 1],\n'
          '    ["a", "b", "c"],\n'
          '    ["mix", null, true, 1, {"k": "v"}]\n'
          '  ]\n'
          '}\n'
          '@enduml\n') as DataDiagram;
      expect(d.format, DataFormat.json);
      // Body structure is deferred — current implementation parses the
      // header and swallows the brace-balanced body. We assert only that
      // the diagram is recognised as JSON-shaped.
      expect(d.root, isA<DataObject>());
    });

    test('allowmixing + many element types + json (source 25)', () {
      final d = parseAny('@startuml\n'
          'allowmixing\n'
          'component Component\n'
          'actor Actor\n'
          'usecase Usecase\n'
          '() Interface\n'
          'node Node\n'
          'cloud Cloud\n'
          'json JSON {\n'
          '  "fruit":"Apple",\n'
          '  "size":"Large",\n'
          '  "color": ["Red", "Green"]\n'
          '}\n'
          '@enduml\n') as UseCaseDiagram;
      // Use case parser hosts because `usecase` appears at line start.
      final aliases = d.nodes.map((n) => n.alias).toSet();
      expect(aliases, contains('Actor'));
      expect(aliases, contains('Usecase'));
    });

    test('allowmixing + agent + stack { json } + database (source 26)', () {
      final d = parseAny('@startuml\n'
          'allowmixing\n'
          'agent Agent\n'
          'stack {\n'
          '  json "JSON_file.json" as J {\n'
          '    "fruit":"Apple",\n'
          '    "size":"Large",\n'
          '    "color": ["Red", "Green"]\n'
          '  }\n'
          '}\n'
          'database Database\n'
          'Agent -> J\n'
          'J -> Database\n'
          '@enduml\n') as ComponentDiagram;
      final aliases = d.nodes.map((n) => n.alias).toSet();
      expect(aliases, contains('Agent'));
      expect(aliases, contains('Database'));
      // stack lowered to a package container in the AST.
      expect(d.containers, isNotEmpty);
    });

    test('state + free brace block + json without allowmixing (source 27)',
        () {
      final d = parseAny('@startuml\n'
          'state "A" as stateA\n'
          'state "C" as stateC\n'
          '{\n'
          '  state B\n'
          '}\n'
          'json J {\n'
          '  "fruit":"Apple",\n'
          '  "size":"Large",\n'
          '  "color": ["Red", "Green"]\n'
          '}\n'
          '@enduml\n') as StateDiagram;
      final names = d.states.map((s) => s.name).toSet();
      expect(names, containsAll(<String>{'stateA', 'stateC', 'B'}));
    });
  });

  group('yaml diagram', () {
    DataDiagram parseYaml(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as DataDiagram;
    }

    test('parses a flat mapping', () {
      final d = parseYaml('@startyaml\n'
          'name: Alice\n'
          'age: 30\n'
          '@endyaml\n');
      expect(d.format, DataFormat.yaml);
      final root = d.root as DataObject;
      expect(root.entries.map((e) => e.key), ['name', 'age']);
      final name = root.entries[0].value as DataScalar;
      expect(name.kind, ScalarKind.string);
      expect(name.value, 'Alice');
      final age = root.entries[1].value as DataScalar;
      expect(age.kind, ScalarKind.number);
      expect(age.value, '30');
    });

    test('parses nested mapping via indentation', () {
      final d = parseYaml('@startyaml\n'
          'address:\n'
          '  city: Seoul\n'
          '  zip: "12345"\n'
          '@endyaml\n');
      final root = d.root as DataObject;
      final addr = root.entries.single.value as DataObject;
      expect(addr.entries.map((e) => e.key), ['city', 'zip']);
      final zip = addr.entries[1].value as DataScalar;
      expect(zip.kind, ScalarKind.string);
      expect(zip.value, '12345');
    });

    test('parses a sequence of scalars', () {
      final d = parseYaml('@startyaml\n'
          'tags:\n'
          '  - admin\n'
          '  - user\n'
          '@endyaml\n');
      final root = d.root as DataObject;
      final tags = root.entries.single.value as DataArray;
      expect(tags.items, hasLength(2));
      final t0 = tags.items[0] as DataScalar;
      expect(t0.value, 'admin');
    });

    test('parses booleans and null', () {
      final d = parseYaml('@startyaml\n'
          'active: true\n'
          'ref: null\n'
          '@endyaml\n');
      final root = d.root as DataObject;
      final active = root.entries[0].value as DataScalar;
      expect(active.kind, ScalarKind.boolean);
      final ref = root.entries[1].value as DataScalar;
      expect(ref.kind, ScalarKind.null_);
    });

    test('accepts <style> block and #highlight directives', () {
      final d = parseYaml('@startyaml\n'
          '<style>\n'
          '.h1 {\n'
          '  BackGroundColor green\n'
          '  FontColor white\n'
          '  FontStyle italic\n'
          '}\n'
          '.h2 {\n'
          '  BackGroundColor red\n'
          '  FontColor white\n'
          '  FontStyle italic\n'
          '}\n'
          '</style>\n'
          '#highlight "french-hens" <<h1>>\n'
          '#highlight "xmas-fifth-day" / "partridges" <<h2>>\n'
          'doe: "a deer, a female deer"\n'
          'ray: "a drop of golden sun"\n'
          'pi: 3.14159\n'
          'xmas: true\n'
          'french-hens: 3\n'
          'calling-birds:\n'
          '  - huey\n'
          '  - dewey\n'
          '  - louie\n'
          '  - fred\n'
          'xmas-fifth-day:\n'
          '  calling-birds: four\n'
          '  french-hens: 3\n'
          '  golden-rings: 5\n'
          'partridges:\n'
          '  count: 1\n'
          '  location: "a pear tree"\n'
          'turtle-doves: two\n'
          '@endyaml\n');
      expect(d.format, DataFormat.yaml);
      final root = d.root as DataObject;
      expect(root.entries.map((e) => e.key), [
        'doe',
        'ray',
        'pi',
        'xmas',
        'french-hens',
        'calling-birds',
        'xmas-fifth-day',
        'partridges',
        'turtle-doves',
      ]);
    });
  });

  group('salt diagram', () {
    SaltDiagram parseSalt(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as SaltDiagram;
    }

    test('parses a label cell', () {
      final d = parseSalt('@startsalt\n{\nName\n}\n@endsalt\n');
      expect(d.rows, hasLength(1));
      final cell = d.rows[0].cells.single as SaltLabel;
      expect(cell.text, 'Name');
    });

    test('parses a button cell', () {
      final d = parseSalt('@startsalt\n{\n[Submit]\n}\n@endsalt\n');
      final cell = d.rows[0].cells.single as SaltButton;
      expect(cell.label, 'Submit');
    });

    test('parses a text field cell', () {
      final d = parseSalt('@startsalt\n{\n"Alice"\n}\n@endsalt\n');
      final cell = d.rows[0].cells.single as SaltTextField;
      expect(cell.value, 'Alice');
    });

    test('parses radio buttons (selected and unselected)', () {
      final d = parseSalt('@startsalt\n'
          '{\n'
          '(X) Yes\n'
          '( ) No\n'
          '}\n'
          '@endsalt\n');
      final r1 = d.rows[0].cells.single as SaltRadio;
      expect(r1.selected, isTrue);
      expect(r1.label, 'Yes');
      final r2 = d.rows[1].cells.single as SaltRadio;
      expect(r2.selected, isFalse);
      expect(r2.label, 'No');
    });

    test('parses checkboxes (checked and unchecked)', () {
      final d = parseSalt('@startsalt\n'
          '{\n'
          '[X] Done\n'
          '[ ] Todo\n'
          '}\n'
          '@endsalt\n');
      final c1 = d.rows[0].cells.single as SaltCheckbox;
      expect(c1.checked, isTrue);
      expect(c1.label, 'Done');
      final c2 = d.rows[1].cells.single as SaltCheckbox;
      expect(c2.checked, isFalse);
      expect(c2.label, 'Todo');
    });

    test('splits cells on | separator', () {
      final d = parseSalt('@startsalt\n'
          '{\n'
          'Name | "Alice"\n'
          '}\n'
          '@endsalt\n');
      expect(d.rows[0].cells, hasLength(2));
      expect((d.rows[0].cells[0] as SaltLabel).text, 'Name');
      expect((d.rows[0].cells[1] as SaltTextField).value, 'Alice');
    });

    test('recognizes -- as a divider row', () {
      final d = parseSalt('@startsalt\n'
          '{\n'
          'A\n'
          '--\n'
          'B\n'
          '}\n'
          '@endsalt\n');
      expect(d.rows, hasLength(3));
      expect(d.rows[1].isDivider, isTrue);
      expect(d.rows[1].cells, isEmpty);
    });
  });

  group('gantt diagram', () {
    GanttDiagram parseGantt(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as GanttDiagram;
    }

    test('parses project start date', () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '@endgantt\n');
      expect(d.projectStart, DateTime.parse('2026-01-01'));
      expect(d.items, isEmpty);
    });

    test('parses task with lasts N days', () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '[Design] lasts 10 days\n'
          '@endgantt\n');
      expect(d.items, hasLength(1));
      final t = d.items.single as GanttTask;
      expect(t.name, 'Design');
      expect(t.duration, const Duration(days: 10));
      expect(t.start, DateTime.parse('2026-01-01'));
    });

    test('converts weeks and months to days', () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '[A] lasts 2 weeks\n'
          '[B] lasts 1 month\n'
          '@endgantt\n');
      final a = d.items[0] as GanttTask;
      final b = d.items[1] as GanttTask;
      expect(a.duration, const Duration(days: 14));
      expect(b.duration, const Duration(days: 30));
    });

    test('parses task with explicit start date', () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '[A] lasts 5 days\n'
          '[A] starts 2026-02-15\n'
          '@endgantt\n');
      final a = d.items.single as GanttTask;
      expect(a.start, DateTime.parse('2026-02-15'));
      expect(a.duration, const Duration(days: 5));
    });

    test('resolves starts at [X]\'s end to absolute date', () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '[A] lasts 10 days\n'
          "[B] lasts 5 days\n"
          "[B] starts at [A]'s end\n"
          '@endgantt\n');
      final a = d.items[0] as GanttTask;
      final b = d.items[1] as GanttTask;
      expect(a.start, DateTime.parse('2026-01-01'));
      expect(b.start, DateTime.parse('2026-01-11'));
    });

    test("resolves starts at [X]'s start to X's start", () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '[A] starts 2026-03-01\n'
          '[A] lasts 7 days\n'
          "[B] lasts 3 days\n"
          "[B] starts at [A]'s start\n"
          '@endgantt\n');
      final b = d.items[1] as GanttTask;
      expect(b.start, DateTime.parse('2026-03-01'));
    });

    test('parses milestone with happens at [X]\'s end', () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '[Test] lasts 7 days\n'
          "[Release] happens at [Test]'s end\n"
          '@endgantt\n');
      expect(d.items, hasLength(2));
      final m = d.items[1] as GanttMilestone;
      expect(m.name, 'Release');
      expect(m.date, DateTime.parse('2026-01-08'));
    });

    test('parses section divider', () {
      final d = parseGantt('@startgantt\n'
          'Project starts 2026-01-01\n'
          '[A] lasts 3 days\n'
          '-- Milestone --\n'
          '@endgantt\n');
      expect(d.items, hasLength(2));
      final s = d.items[1] as GanttSection;
      expect(s.title, 'Milestone');
    });

    test('parses requires syntax with days/weeks and compound durations', () {
      final d = parseGantt('@startgantt\n'
          '[Prototype design] requires 15 days\n'
          '[Test prototype] requires 10 days\n'
          '-- All example --\n'
          '[Task 1 (1 day)] requires 1 day\n'
          '[T2 (5 days)] requires 5 days\n'
          '[T3 (1 week)] requires 1 week\n'
          '[T4 (1 week and 4 days)] requires 1 week and 4 days\n'
          '[T5 (2 weeks)] requires 2 weeks\n'
          '@endgantt\n');
      final tasks = d.items.whereType<GanttTask>().toList();
      final sections = d.items.whereType<GanttSection>().toList();
      expect(tasks, hasLength(7));
      expect(sections, hasLength(1));
      expect(sections.single.title, 'All example');
      expect(tasks[0].name, 'Prototype design');
      expect(tasks[0].duration, const Duration(days: 15));
      expect(tasks[1].duration, const Duration(days: 10));
      expect(tasks[2].duration, const Duration(days: 1));
      expect(tasks[3].duration, const Duration(days: 5));
      expect(tasks[4].duration, const Duration(days: 7));
      expect(tasks[5].duration, const Duration(days: 11));
      expect(tasks[6].duration, const Duration(days: 14));
    });
  });

  group('network diagram', () {
    NetworkDiagram parseNwdiag(String src) {
      final tokens = Lexer().tokenize(src);
      final d = Parser().parse(tokens);
      return d as NetworkDiagram;
    }

    test('parses a single empty network block', () {
      final d = parseNwdiag('@startnwdiag\n'
          'network dmz {\n'
          '}\n'
          '@endnwdiag\n');
      expect(d.networks, hasLength(1));
      expect(d.networks.single.name, 'dmz');
      expect(d.networks.single.nodes, isEmpty);
    });

    test('parses nodes inside a network', () {
      final d = parseNwdiag('@startnwdiag\n'
          'network dmz {\n'
          '  web01 [address = "210.0.0.1"]\n'
          '  web02 [address = "210.0.0.2"]\n'
          '}\n'
          '@endnwdiag\n');
      final seg = d.networks.single;
      expect(seg.nodes, hasLength(2));
      expect(seg.nodes[0].name, 'web01');
      expect(seg.nodes[0].address, '210.0.0.1');
      expect(seg.nodes[1].name, 'web02');
      expect(seg.nodes[1].address, '210.0.0.2');
    });

    test('parses segment-level address', () {
      final d = parseNwdiag('@startnwdiag\n'
          'network dmz {\n'
          '  address = "210.0.0.0/24"\n'
          '  web01 [address = "210.0.0.1"]\n'
          '}\n'
          '@endnwdiag\n');
      final seg = d.networks.single;
      expect(seg.address, '210.0.0.0/24');
      expect(seg.nodes, hasLength(1));
    });

    test('parses multiple networks with shared node names', () {
      final d = parseNwdiag('@startnwdiag\n'
          'network dmz {\n'
          '  web01 [address = "210.0.0.1"]\n'
          '}\n'
          'network internal {\n'
          '  web01 [address = "172.0.0.1"]\n'
          '  db01 [address = "172.0.0.100"]\n'
          '}\n'
          '@endnwdiag\n');
      expect(d.networks, hasLength(2));
      expect(d.networks[0].name, 'dmz');
      expect(d.networks[1].name, 'internal');
      expect(d.networks[1].nodes.map((n) => n.name), ['web01', 'db01']);
    });

    test('accepts a node without attributes', () {
      final d = parseNwdiag('@startnwdiag\n'
          'network dmz {\n'
          '  web01\n'
          '}\n'
          '@endnwdiag\n');
      expect(d.networks.single.nodes.single.name, 'web01');
      expect(d.networks.single.nodes.single.address, isNull);
    });

    test('parses nwdiag wrapper with network address', () {
      final d = parseNwdiag('@startnwdiag\n'
          'nwdiag {\n'
          '  network dmz {\n'
          '    address = "210.x.x.x/24"\n'
          '  }\n'
          '}\n'
          '@endnwdiag\n');
      expect(d.networks, hasLength(1));
      expect(d.networks.single.name, 'dmz');
      expect(d.networks.single.address, '210.x.x.x/24');
    });

    test('parses networks with nested groups, properties, and comments', () {
      final d = parseNwdiag('@startnwdiag\n'
          'network Sample_front {\n'
          '  address = "192.168.10.0/24";\n'
          '  // define group\n'
          '  group web {\n'
          '    web01 [address = ".1"];\n'
          '    web02 [address = ".2"];\n'
          '  }\n'
          '}\n'
          'network Sample_back {\n'
          '  address = "192.168.20.0/24";\n'
          '  web01 [address = ".1"];\n'
          '  web02 [address = ".2"];\n'
          '  db01 [address = ".101"];\n'
          '  db02 [address = ".102"];\n'
          '  // define network using defined nodes\n'
          '  group db {\n'
          '    db01;\n'
          '    db02;\n'
          '  }\n'
          '}\n'
          '@endnwdiag\n');
      expect(d.networks, hasLength(2));
      expect(d.networks[0].name, 'Sample_front');
      expect(d.networks[0].address, '192.168.10.0/24');
      expect(d.networks[0].nodes.map((n) => n.name),
          containsAll(['web01', 'web02']));
      expect(d.networks[1].name, 'Sample_back');
      expect(d.networks[1].address, '192.168.20.0/24');
      expect(d.networks[1].nodes.map((n) => n.name),
          containsAll(['web01', 'web02', 'db01', 'db02']));
    });

    test('parses anonymous top-level group with color', () {
      final d = parseNwdiag('@startnwdiag\n'
          '// define group outside of network definitions\n'
          'group {\n'
          '  color = "#FFAAAA";\n'
          '  web01;\n'
          '  web02;\n'
          '  db01;\n'
          '}\n'
          'network dmz {\n'
          '  web01;\n'
          '  web02;\n'
          '}\n'
          'network internal {\n'
          '  web01;\n'
          '  web02;\n'
          '  db01;\n'
          '  db02;\n'
          '}\n'
          '@endnwdiag\n');
      expect(d.networks, hasLength(2));
      expect(d.networks[0].name, 'dmz');
      expect(d.networks[0].nodes.map((n) => n.name), ['web01', 'web02']);
      expect(d.networks[1].name, 'internal');
      expect(d.networks[1].nodes.map((n) => n.name),
          ['web01', 'web02', 'db01', 'db02']);
    });

    test('parses !include directives, multi-address values and '
        'description attributes', () {
      final d = parseNwdiag('@startnwdiag\n'
          '!include <office/Servers/application_server>\n'
          '!include <office/Servers/database_server>\n'
          'nwdiag {\n'
          '  network dmz {\n'
          '    address = "210.x.x.x/24"\n'
          '    // set multiple addresses (using comma)\n'
          '    web01 [address = "210.x.x.1, 210.x.x.20", '
          'description = "<\$application_server>\\n web01"]\n'
          '    web02 [address = "210.x.x.2", '
          'description = "<\$application_server>\\n web02"];\n'
          '  }\n'
          '  network internal {\n'
          '    address = "172.x.x.x/24";\n'
          '    web01 [address = "172.x.x.1"];\n'
          '    web02 [address = "172.x.x.2"];\n'
          '    db01 [address = "172.x.x.100", '
          'description = "<\$database_server>\\n db01"];\n'
          '    db02 [address = "172.x.x.101", '
          'description = "<\$database_server>\\n db02"];\n'
          '  }\n'
          '}\n'
          '@endnwdiag\n');
      expect(d.networks, hasLength(2));
      final dmz = d.networks[0];
      expect(dmz.name, 'dmz');
      expect(dmz.address, '210.x.x.x/24');
      expect(dmz.nodes.map((n) => n.name), ['web01', 'web02']);
      // Multi-address values are preserved verbatim as a single string.
      expect(dmz.nodes[0].address, '210.x.x.1, 210.x.x.20');
      expect(dmz.nodes[1].address, '210.x.x.2');
      final internal = d.networks[1];
      expect(internal.name, 'internal');
      expect(internal.address, '172.x.x.x/24');
      expect(internal.nodes.map((n) => n.name),
          ['web01', 'web02', 'db01', 'db02']);
      expect(internal.nodes.map((n) => n.address), [
        '172.x.x.1',
        '172.x.x.2',
        '172.x.x.100',
        '172.x.x.101',
      ]);
    });
  });

  group('ebnf', () {
    EbnfDiagram parseEbnf(String src) {
      final tokens = Lexer().tokenize(src);
      return Parser().parse(tokens) as EbnfDiagram;
    }

    test('parses a simple terminal rule', () {
      final d = parseEbnf('@startebnf\n'
          'a = "x" ;\n'
          '@endebnf\n');
      expect(d.rules, hasLength(1));
      final rule = d.rules.single;
      expect(rule.name, 'a');
      final term = rule.expression as EbnfTerminal;
      expect(term.value, 'x');
      expect(d.text, isEmpty);
    });

    test('parses an alternation of terminals', () {
      final d = parseEbnf('@startebnf\n'
          'a = "x" | "y" | "z" ;\n'
          '@endebnf\n');
      final rule = d.rules.single;
      final alt = rule.expression as EbnfAlternation;
      expect(alt.items, hasLength(3));
      expect((alt.items[0] as EbnfTerminal).value, 'x');
      expect((alt.items[2] as EbnfTerminal).value, 'z');
    });

    test('parses a sequence of terminals', () {
      final d = parseEbnf('@startebnf\n'
          'a = "x" , "y" ;\n'
          '@endebnf\n');
      final seq = d.rules.single.expression as EbnfSequence;
      expect(seq.items, hasLength(2));
    });

    test('parses optional and repetition', () {
      final d = parseEbnf('@startebnf\n'
          'a = [ "x" ] , { "y" } ;\n'
          '@endebnf\n');
      final seq = d.rules.single.expression as EbnfSequence;
      expect(seq.items[0], isA<EbnfOptional>());
      expect(seq.items[1], isA<EbnfRepetition>());
    });

    test('parses group with non-terminals', () {
      final d = parseEbnf('@startebnf\n'
          'a = ( foo | bar ) , baz ;\n'
          '@endebnf\n');
      final seq = d.rules.single.expression as EbnfSequence;
      final group = seq.items[0] as EbnfGroup;
      final alt = group.inner as EbnfAlternation;
      expect((alt.items[0] as EbnfNonTerminal).name, 'foo');
      expect((seq.items[1] as EbnfNonTerminal).name, 'baz');
    });

    test('parses special sequence', () {
      final d = parseEbnf('@startebnf\n'
          'quoted = ? any character ? ;\n'
          '@endebnf\n');
      final special = d.rules.single.expression as EbnfSpecial;
      expect(special.text, 'any character');
    });

    test('parses the failing sample subset grammar (11 rules)', () {
      final d = parseEbnf('@startebnf\n'
          'title Mini PlantUML subset grammar\n'
          '\n'
          'diagram = start_directive , { statement } , end_directive ;\n'
          'start_directive = "@startuml" | "@startjson" | "@startyaml" ;\n'
          'end_directive = "@enduml" | "@endjson" | "@endyaml" ;\n'
          'statement = participant | message | block | note | raw_line ;\n'
          'participant = ( "participant" | "actor" | "database" ) , quoted_name , [ "as" , identifier ] ;\n'
          'message = identifier , arrow , identifier , ":" , text ;\n'
          'arrow = "->" | "-->" | "<-" | "<--" | "->>" ;\n'
          'block = ( "alt" | "loop" | "par" | "group" ) , text , { statement } , "end" ;\n'
          'note = "note" , ( "left" | "right" | "over" ) , text , "end note" ;\n'
          'identifier = letter , { letter | digit | "_" } ;\n'
          'quoted_name = \'"\' , { ? any character except quote ? } , \'"\' ;\n'
          '@endebnf\n');
      expect(d.rules, hasLength(11));
      expect(d.rules.map((r) => r.name), [
        'diagram',
        'start_directive',
        'end_directive',
        'statement',
        'participant',
        'message',
        'arrow',
        'block',
        'note',
        'identifier',
        'quoted_name',
      ]);
    });

    test('falls back to text for unparseable trailing content', () {
      final d = parseEbnf('@startebnf\n'
          'a = "x" ;\n'
          'gibberish~no~rule\n'
          '@endebnf\n');
      expect(d.rules, hasLength(1));
      expect(d.text, isNotEmpty);
    });
  });

  group('universal decorations', () {
    Diagram parseAny(String src) {
      final tokens = Lexer().tokenize(src);
      return Parser().parse(tokens);
    }

    test('class diagram accepts title at top', () {
      final d = parseAny('@startuml\n'
          'title My Class Diagram\n'
          'class Foo\n'
          '@enduml\n') as ClassDiagram;
      expect(d.decorations.title, 'My Class Diagram');
    });

    test('usecase diagram accepts title at top', () {
      final d = parseAny('@startuml\n'
          'title Use Cases\n'
          'actor User\n'
          'usecase Login\n'
          'User --> Login\n'
          '@enduml\n') as UseCaseDiagram;
      expect(d.decorations.title, 'Use Cases');
    });

    test('state diagram accepts title at top', () {
      final d = parseAny('@startuml\n'
          'title States\n'
          '[*] --> Idle\n'
          '@enduml\n') as StateDiagram;
      expect(d.decorations.title, 'States');
    });

    test('component diagram accepts title at top', () {
      final d = parseAny('@startuml\n'
          'title Components\n'
          'component Web\n'
          '@enduml\n') as ComponentDiagram;
      expect(d.decorations.title, 'Components');
    });

    test('activity diagram accepts title at top', () {
      final d = parseAny('@startuml\n'
          'title Pipeline\n'
          'start\n'
          ':Step;\n'
          'stop\n'
          '@enduml\n') as ActivityDiagram;
      expect(d.decorations.title, 'Pipeline');
    });

    test('class diagram accepts header / footer / caption / legend', () {
      final d = parseAny('@startuml\n'
          'header My Header\n'
          'footer My Footer\n'
          'caption My Caption\n'
          'legend\n'
          'L1\n'
          'endlegend\n'
          'class Foo\n'
          '@enduml\n') as ClassDiagram;
      expect(d.decorations.header!.text, 'My Header');
      expect(d.decorations.footer!.text, 'My Footer');
      expect(d.decorations.caption, 'My Caption');
      expect(d.decorations.legend!.text, 'L1');
    });

    test('state diagram accepts skinparam backgroundColor', () {
      final d = parseAny('@startuml\n'
          'skinparam backgroundColor #FFEEDD\n'
          '[*] --> Idle\n'
          '@enduml\n') as StateDiagram;
      expect(d.decorations.skin.backgroundColor, const Color(0xFFFFEEDD));
    });

    test('component diagram accepts header and skinparam', () {
      final d = parseAny('@startuml\n'
          'header Top\n'
          'skinparam defaultFontSize 14\n'
          'component Web\n'
          '@enduml\n') as ComponentDiagram;
      expect(d.decorations.header!.text, 'Top');
      expect(d.decorations.skin.defaultFontSize, 14.0);
    });

    test('usecase "left to right direction" sets the flag', () {
      final d = parseAny('@startuml\n'
          'left to right direction\n'
          'actor User\n'
          'usecase Login\n'
          'User --> Login\n'
          '@enduml\n') as UseCaseDiagram;
      expect(d.leftToRightDirection, isTrue);
    });

    test('usecase "top to bottom direction" leaves the flag false', () {
      final d = parseAny('@startuml\n'
          'top to bottom direction\n'
          'actor User\n'
          'usecase Login\n'
          'User --> Login\n'
          '@enduml\n') as UseCaseDiagram;
      expect(d.leftToRightDirection, isFalse);
    });

    test('usecase defaults leftToRightDirection to false', () {
      final d = parseAny('@startuml\n'
          'actor User\n'
          'usecase Login\n'
          'User --> Login\n'
          '@enduml\n') as UseCaseDiagram;
      expect(d.leftToRightDirection, isFalse);
    });
  });

  group('sample integration smoke tests', () {
    void smoke(String name, String src) {
      test('$name parses + lays out without throwing', () {
        final tokens = Lexer().tokenize(src);
        final diagram = Parser().parse(tokens);
        final measurer = _StubMeasurer();
        final scene = const AutoLayout().layout(diagram, measurer);
        expect(scene.shapes, isNotEmpty);
      });
    }

    smoke('class_order_domain', '''@startuml
title Order Domain
class Customer {
  +String id
  +String name
  +placeOrder(cart)
}
class Order {
  +String orderNo
  +Money total
  +submit()
  +cancel()
}
class OrderLine {
  +String sku
  +int quantity
  +Money price
}
class Payment {
  +authorize()
  +capture()
}

Customer "1" --> "0..*" Order
Order "1" *-- "1..*" OrderLine
Order "1" --> "0..1" Payment
@enduml
''');

    smoke('component_checkout', '''@startuml
title Checkout Components
package "Frontend" {
  [Cart UI]
  [Checkout UI]
}
package "Backend" {
  [Order Service]
  [Payment Adapter]
  [Inventory Service]
}
cloud "Payment Gateway" as PG
database "Orders DB" as ODB

[Cart UI] --> [Checkout UI]
[Order Service] --> [Inventory Service]
[Order Service] --> [Payment Adapter]
[Payment Adapter] --> PG
[Order Service] --> ODB
@enduml
''');

    smoke('deployment_cloud_edges', '''@startuml
title Multi-region deployment with artifacts and network boundaries

skinparam componentStyle rectangle

node "User Device" as device {
  artifact "omni-viewer.app" as app
}

cloud "Public Internet" {
  node "CDN Edge\\n{global}" as cdn
}

frame "AWS us-east-1" {
  node "VPC" {
    node "Public Subnet" {
      node "ALB" as alb
    }
    node "Private Subnet A" {
      component "Viewer API" as api1
      database "Metadata\\nPostgreSQL" as db
    }
    node "Private Subnet B" {
      component "Conversion Worker" as worker
      queue "Job Queue" as queue
      storage "Object Store\\nS3" as s3
    }
  }
}

frame "AWS eu-west-1" {
  node "Read Replica Region" {
    database "Metadata Replica" as replica
    storage "S3 Replica" as s3replica
  }
}

app --> cdn : HTTPS
cdn --> alb : origin request
alb --> api1 : mTLS
api1 --> db : SQL
api1 --> queue : enqueue conversion
worker --> queue : poll
worker --> s3 : read/write files
db ..> replica : logical replication
s3 ..> s3replica : CRR
@enduml
''');

    smoke('state_document_review', '''@startuml
title Document Review State
[*] --> Draft
Draft --> InReview: submit
InReview --> Draft: request changes
InReview --> Approved: approve
Approved --> Published: publish
Published --> Archived: archive
Archived --> [*]
@enduml
''');

    smoke('usecase_share_file', '''@startuml
title Share File Use Cases
left to right direction
actor Developer
actor Reviewer
rectangle "Omni Viewer" {
  usecase "Open file" as Open
  usecase "Upload share link" as Upload
  usecase "Copy link" as Copy
  usecase "Open shared link" as OpenLink
}
Developer --> Open
Developer --> Upload
Upload --> Copy
Reviewer --> OpenLink
@enduml
''');

    smoke('class_generics_annotations', '''@startuml
title Domain model with generics, stereotypes, notes, and constraints

hide empty members
skinparam classAttributeIconSize 0

package "ordering.domain" <<Layer>> {
  abstract class AggregateRoot<ID> {
    - id: ID
    + pullEvents(): List<DomainEvent>
  }

  interface Repository<T extends AggregateRoot<ID>, ID> {
    + findById(id: ID): Optional<T>
    + save(entity: T): Unit
  }

  annotation Audited {
    + reason: String
  }

  class Order <<Aggregate>> {
    - lines: List<OrderLine>
    - status: OrderStatus
    + place(command: PlaceOrder): Order
    + cancel(reason: String): void
  }

  class OrderLine <<ValueObject>> {
    + sku: SKU
    + quantity: Quantity
    + price: Money
  }

  enum OrderStatus {
    Draft
    Placed
    Paid
    Cancelled
  }

  record Money {
    amount: BigDecimal
    currency: Currency
  }
}

Repository <|.. OrderRepository
AggregateRoot <|-- Order
Order "1" *-- "1..*" OrderLine : contains >
Order --> OrderStatus
OrderLine --> Money
Audited .. Order

note right of Order
  Invariants:
  * total must be positive
  * cannot cancel after shipment
  * status transitions are monotonic
end note

note "Generic bound and record syntax are intentionally parser-hostile." as N1
N1 .. Repository
@enduml
''');
  });

  group('arrow duration annotation', () {
    test('basic ->(N) trailing on forward and (N)<- leading on backward', () {
      final d = parseSequence('@startuml\n'
          'A ->(10) B: text 10\n'
          'B ->(10) A: text 10\n'
          '\n'
          'A ->(10) B: text 10\n'
          'A (10)<- B: text 10\n'
          '@enduml\n');
      final ms = d.events.whereType<Message>().toList();
      expect(ms, hasLength(4));
      expect(ms[0].from, 'A');
      expect(ms[0].to, 'B');
      expect(ms[0].duration, 10);
      expect(ms[0].direction, MessageDirection.forward);
      expect(ms[0].head, ArrowHead.filled);
      expect(ms[0].synchronized, isFalse);
      expect(ms[1].from, 'B');
      expect(ms[1].to, 'A');
      expect(ms[1].duration, 10);
      expect(ms[1].direction, MessageDirection.forward);
      // Backward `(10)<-` form: source is on the right ("B"), target on the
      // left ("A"). Parser keeps `from = A, to = B` and flips direction.
      expect(ms[3].from, 'A');
      expect(ms[3].to, 'B');
      expect(ms[3].duration, 10);
      expect(ms[3].direction, MessageDirection.backward);
      expect(ms[3].head, ArrowHead.filled);
    });

    test('->(N) combined with activation suffix', () {
      final d = parseSequence('@startuml\n'
          'A ->(40) B++: Rq\n'
          'B -->(20) A--: Rs\n'
          '@enduml\n');
      final ms = d.events.whereType<Message>().toList();
      expect(ms, hasLength(2));
      expect(ms[0].from, 'A');
      expect(ms[0].to, 'B');
      expect(ms[0].duration, 40);
      expect(ms[0].lineStyle, LineStyle.solid);
      expect(ms[0].activation, ActivationSuffix.activateTarget);
      expect(ms[1].from, 'B');
      expect(ms[1].to, 'A');
      expect(ms[1].duration, 20);
      expect(ms[1].lineStyle, LineStyle.dashed);
      expect(ms[1].activation, ActivationSuffix.deactivateSource);
      // A subsequent Activate(B) event is emitted by the parser as a
      // secondary event after the first message with `++`.
      final activates = d.events.whereType<Activate>().toList();
      expect(activates.any((a) => a.participant == 'B'), isTrue);
      // Source-deactivate `--` emits Deactivate(from) = Deactivate(B) for
      // the second message.
      final deactivates = d.events.whereType<Deactivate>().toList();
      expect(deactivates.any((da) => da.participant == 'B'), isTrue);
    });

    test('& parallel/sync marker combined with ->(N)', () {
      final d = parseSequence('@startuml\n'
          '!pragma teoz true\n'
          'A ->(50) C: Starts\\nwhen \'B\' sends\n'
          '& B ->(25) C: \\nBut B\'s message\\n arrives before A\'s\n'
          '@enduml\n');
      final ms = d.events.whereType<Message>().toList();
      expect(ms, hasLength(2));
      expect(ms[0].from, 'A');
      expect(ms[0].to, 'C');
      expect(ms[0].duration, 50);
      expect(ms[0].synchronized, isFalse);
      expect(ms[1].from, 'B');
      expect(ms[1].to, 'C');
      expect(ms[1].duration, 25);
      expect(ms[1].synchronized, isTrue);
    });

    test('regression: arrow without (N) parses with duration == null', () {
      final d = parseSequence('@startuml\nA -> B\n@enduml\n');
      final m = d.events.single as Message;
      expect(m.duration, isNull);
      expect(m.synchronized, isFalse);
    });
  });

  group('multi-line delay block', () {
    test('parses `...\\nSome ~~text~~\\n...` form without lexer error', () {
      const src = '''
@startuml
participant Alice
participant "The **Famous** Bob" as Bob
Alice -> Bob : hello --there--
...
Some ~~long delay~~
...
Bob -> Alice : ok
@enduml
''';
      // Just assert it parses; structure of the delay is not asserted here.
      expect(() => parseSequence(src), returnsNormally);
    });
  });

  group('participant stereotype', () {
    test('parses participant declarations with `<< Stereotype >>` trailers',
        () {
      final d = parseSequence(
        '@startuml\n'
        'skinparam guillemet false\n'
        'participant "Famous Bob" as Bob << Generated >>\n'
        'participant Alice << (C,#ADD1B2) Testable >>\n'
        'Bob->Alice: First message\n'
        '@enduml\n',
      );
      expect(d.participants, hasLength(2));
      final byAlias = {for (final p in d.participants) p.alias: p};
      expect(byAlias['Bob']!.displayName, 'Famous Bob');
      expect(byAlias['Bob']!.stereotype, 'Generated');
      expect(byAlias['Alice']!.stereotype, '(C,#ADD1B2) Testable');
      // Message between the two declared participants still parses.
      final messages = d.events.whereType<Message>().toList();
      expect(messages, hasLength(1));
      expect(messages.single.from, 'Bob');
      expect(messages.single.to, 'Alice');
    });
  });

  group('state transition arrow direction', () {
    StateDiagram parseState(String source) {
      final d = Parser().parse(Lexer().tokenize(source));
      return d as StateDiagram;
    }

    StateTransition transitionFor(StateDiagram d, String from, String to) =>
        d.transitions.firstWhere((t) => t.from == from && t.to == to);

    test('classifies dash length and explicit direction words', () {
      final d = parseState(
        '@startuml\n'
        '[*] --> A\n'
        'A -> B\n'
        'A --> C\n'
        'A -up-> D\n'
        'A -left-> E\n'
        '@enduml\n',
      );
      expect(transitionFor(d, 'A', 'B').direction, StateArrowDirection.right);
      expect(transitionFor(d, 'A', 'C').direction, StateArrowDirection.down);
      expect(transitionFor(d, 'A', 'D').direction, StateArrowDirection.up);
      expect(transitionFor(d, 'A', 'E').direction, StateArrowDirection.left);
    });
  });
}

class _StubMeasurer implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) {
    final fontSize = style.fontSize ?? 12.0;
    return Size(text.length * fontSize * 0.6, fontSize * 1.2);
  }
}
