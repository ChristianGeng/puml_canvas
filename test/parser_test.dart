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

      test('nested box throws ParserException', () {
        expect(
          () => parseSequence('@startuml\n'
              'box "Outer"\n'
              'box "Inner"\n'
              'participant A\n'
              'end box\n'
              'end box\n'
              '@enduml\n'),
          throwsA(isA<ParserException>()),
        );
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

      test('autonumber resume with explicit value overrides current', () {
        final d = parseSequence('@startuml\n'
            'autonumber 5\n'
            'A -> B\n'
            'autonumber resume 100\n'
            'A -> B\n'
            '@enduml\n');
        final ms = d.events.whereType<Message>().toList();
        expect(ms.map((m) => m.label).toList(), ['5', '100']);
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

    test('bracketed shorthand routes to component diagram', () {
      final tokens = Lexer().tokenize('@startuml\n'
          '[A]\n'
          '[B]\n'
          '[A] --> [B]\n'
          '@enduml\n');
      final d = Parser().parse(tokens);
      expect(d, isA<ComponentDiagram>());
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

    test('rejects multiple roots', () {
      expect(
        () => parseMindmap('@startmindmap\n* One\n* Two\n@endmindmap\n'),
        throwsA(isA<ParserException>()),
      );
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

    test('rejects multiple roots', () {
      expect(
        () => parseWbs('@startwbs\n* One\n* Two\n@endwbs\n'),
        throwsA(isA<ParserException>()),
      );
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
}

class _StubMeasurer implements TextMeasurer {
  @override
  Size measure(String text, TextStyle style) {
    final fontSize = style.fontSize ?? 12.0;
    return Size(text.length * fontSize * 0.6, fontSize * 1.2);
  }
}
