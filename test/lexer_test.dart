import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() {
  group('Lexer', () {
    test('emits start/end uml around an empty diagram', () {
      final tokens = Lexer().tokenize('@startuml\n@enduml\n');
      final types = tokens.map((t) => t.type).toList();
      expect(types, [
        TokenType.startUml,
        TokenType.newline,
        TokenType.endUml,
        TokenType.newline,
        TokenType.eof,
      ]);
    });

    test('lexes a solid arrow with label', () {
      final tokens = Lexer().tokenize('@startuml\nA -> B : hello\n@enduml\n');
      final types = tokens.map((t) => t.type).toList();
      expect(types, [
        TokenType.startUml,
        TokenType.newline,
        TokenType.identifier,
        TokenType.arrow,
        TokenType.identifier,
        TokenType.colon,
        TokenType.text,
        TokenType.newline,
        TokenType.endUml,
        TokenType.newline,
        TokenType.eof,
      ]);
      expect(tokens[2].lexeme, 'A');
      expect(tokens[4].lexeme, 'B');
      expect(tokens[6].lexeme, 'hello');
    });

    test('distinguishes dashed arrow from solid', () {
      final tokens = Lexer().tokenize('@startuml\nA --> B\n@enduml\n');
      final arrowTokens = tokens
          .where((t) => t.type == TokenType.arrow && t.lexeme == '-->')
          .toList();
      expect(arrowTokens, hasLength(1));
    });

    group('arrow variants', () {
      const cases = <String>[
        '->',
        '-->',
        '->>',
        '-->>',
        '->o',
        '-->o',
        '->x',
        '-->x',
        '<-',
        '<--',
        '<<-',
        '<<--',
      ];
      for (final form in cases) {
        test('lexes "$form" as a single arrow token', () {
          final tokens = Lexer().tokenize('@startuml\nA $form B\n@enduml\n');
          final arrows = tokens
              .where((t) => t.type == TokenType.arrow)
              .toList();
          expect(arrows, hasLength(1));
          expect(arrows.single.lexeme, form);
        });
      }
    });

    group('arrow modifiers', () {
      const cases = <String>[
        '-[hidden]->',
        '-[#red]->',
        '--[#blue]->',
        '-[#FF00FF]->>',
        '<-[#red]-',
        '<--[#00FF00]--',
      ];
      for (final form in cases) {
        test('lexes "$form" as a single arrow token', () {
          final tokens = Lexer().tokenize('@startuml\nA $form B\n@enduml\n');
          final arrows = tokens
              .where((t) => t.type == TokenType.arrow)
              .toList();
          expect(arrows, hasLength(1));
          expect(arrows.single.lexeme, form);
        });
      }
    });

    test("ignores single-quote comments to end of line", () {
      final tokens = Lexer().tokenize("@startuml\n' this is a comment\nA -> B\n@enduml\n");
      final idents = tokens.where((t) => t.type == TokenType.identifier).toList();
      expect(idents.map((t) => t.lexeme), ['A', 'B']);
    });

    group('multi-line comments', () {
      test("'/' ... '/' between tokens is fully skipped", () {
        final tokens = Lexer().tokenize(
            "@startuml\nA /' inline skipped '/ -> B\n@enduml\n");
        final idents = tokens
            .where((t) => t.type == TokenType.identifier)
            .map((t) => t.lexeme)
            .toList();
        expect(idents, ['A', 'B']);
        for (final t in tokens) {
          expect(t.lexeme.contains('skipped'), isFalse);
          expect(t.lexeme.contains('inline'), isFalse);
        }
      });

      test('multi-line content spans multiple newlines', () {
        final tokens = Lexer().tokenize(
            "@startuml\n/'\nline one\nline two\nline three\n'/\nA -> B\n@enduml\n");
        final idents = tokens
            .where((t) => t.type == TokenType.identifier)
            .map((t) => t.lexeme)
            .toList();
        expect(idents, ['A', 'B']);
        for (final t in tokens) {
          expect(t.lexeme.contains('line one'), isFalse);
          expect(t.lexeme.contains('line two'), isFalse);
          expect(t.lexeme.contains('line three'), isFalse);
        }
        final aTok =
            tokens.firstWhere((t) => t.lexeme == 'A');
        expect(aTok.line, 7);
      });

      test("comment body containing single-line ' does not terminate", () {
        final tokens = Lexer().tokenize(
            "@startuml\n/' has a ' single quote and more text '/\nA -> B\n@enduml\n");
        final idents = tokens
            .where((t) => t.type == TokenType.identifier)
            .map((t) => t.lexeme)
            .toList();
        expect(idents, ['A', 'B']);
        for (final t in tokens) {
          expect(t.lexeme.contains('quote'), isFalse);
        }
      });

      test("unterminated /' throws LexerException", () {
        expect(
          () => Lexer().tokenize("@startuml\n/' never closed\nA -> B\n@enduml\n"),
          throwsA(isA<LexerException>()),
        );
      });
    });

    test('throws on unknown directive', () {
      expect(
        () => Lexer().tokenize('@bogus\n'),
        throwsA(isA<LexerException>()),
      );
    });

    group('activation suffixes', () {
      test('lexes "++" as plusPlus token', () {
        final tokens = Lexer().tokenize('@startuml\nA -> B ++\n@enduml\n');
        final marker = tokens
            .where((t) => t.type == TokenType.plusPlus)
            .toList();
        expect(marker, hasLength(1));
        expect(marker.single.lexeme, '++');
      });

      test('lexes standalone "--" as minusMinus token', () {
        final tokens = Lexer().tokenize('@startuml\nA -> B --\n@enduml\n');
        final marker = tokens
            .where((t) => t.type == TokenType.minusMinus)
            .toList();
        expect(marker, hasLength(1));
        expect(marker.single.lexeme, '--');
      });

      test('lexes "**" as starStar token', () {
        final tokens = Lexer().tokenize('@startuml\nA -> B **\n@enduml\n');
        final marker = tokens
            .where((t) => t.type == TokenType.starStar)
            .toList();
        expect(marker, hasLength(1));
        expect(marker.single.lexeme, '**');
      });

      test('lexes "!!" as bangBang token', () {
        final tokens = Lexer().tokenize('@startuml\nA -> B !!\n@enduml\n');
        final marker = tokens
            .where((t) => t.type == TokenType.bangBang)
            .toList();
        expect(marker, hasLength(1));
        expect(marker.single.lexeme, '!!');
      });

      test('"-->" still lexes as a single arrow, not "--" + ">"', () {
        final tokens = Lexer().tokenize('@startuml\nA --> B\n@enduml\n');
        final arrows = tokens
            .where((t) => t.type == TokenType.arrow)
            .toList();
        expect(arrows, hasLength(1));
        expect(arrows.single.lexeme, '-->');
        expect(tokens.where((t) => t.type == TokenType.minusMinus), isEmpty);
      });
    });

    group('separators', () {
      test('lexes "== Title ==" as doubleEquals, text, doubleEquals', () {
        final tokens =
            Lexer().tokenize('@startuml\n== Phase 1 ==\n@enduml\n');
        final types = tokens
            .where((t) =>
                t.type == TokenType.doubleEquals ||
                t.type == TokenType.text)
            .map((t) => t.type)
            .toList();
        expect(types, [
          TokenType.doubleEquals,
          TokenType.text,
          TokenType.doubleEquals,
        ]);
        final text = tokens
            .firstWhere((t) => t.type == TokenType.text);
        expect(text.lexeme, 'Phase 1');
      });

      test('lexes "||5||" as doublePipe, text, doublePipe', () {
        final tokens = Lexer().tokenize('@startuml\n||5||\n@enduml\n');
        final relevant = tokens
            .where((t) =>
                t.type == TokenType.doublePipe ||
                t.type == TokenType.text)
            .map((t) => t.type)
            .toList();
        expect(relevant, [
          TokenType.doublePipe,
          TokenType.text,
          TokenType.doublePipe,
        ]);
        final text =
            tokens.firstWhere((t) => t.type == TokenType.text);
        expect(text.lexeme, '5');
      });

      test('lexes "..." as a single dotDotDot token', () {
        final tokens = Lexer().tokenize('@startuml\n...\n@enduml\n');
        final dots = tokens
            .where((t) => t.type == TokenType.dotDotDot)
            .toList();
        expect(dots, hasLength(1));
        expect(dots.single.lexeme, '...');
      });

      test('lexes standalone "--" on its own line as minusMinus', () {
        final tokens = Lexer().tokenize('@startuml\n--\n@enduml\n');
        final dashes = tokens
            .where((t) => t.type == TokenType.minusMinus)
            .toList();
        expect(dashes, hasLength(1));
      });
    });

    group('mindmap directives', () {
      test('lexes @startmindmap / @endmindmap as dedicated tokens', () {
        final tokens =
            Lexer().tokenize('@startmindmap\n* Root\n@endmindmap\n');
        expect(tokens.first.type, TokenType.startMindmap);
        expect(
          tokens.any((t) => t.type == TokenType.endMindmap),
          isTrue,
        );
      });

      test('captures mindmap body lines as raw text tokens', () {
        final tokens = Lexer().tokenize('@startmindmap\n'
            '* Root\n'
            '** Child\n'
            '@endmindmap\n');
        final texts = tokens
            .where((t) => t.type == TokenType.text)
            .map((t) => t.lexeme)
            .toList();
        expect(texts, ['* Root', '** Child']);
      });
    });

    group('wbs directives', () {
      test('lexes @startwbs / @endwbs as dedicated tokens', () {
        final tokens = Lexer().tokenize('@startwbs\n* Root\n@endwbs\n');
        expect(tokens.first.type, TokenType.startWbs);
        expect(
          tokens.any((t) => t.type == TokenType.endWbs),
          isTrue,
        );
      });

      test('captures wbs body lines as raw text tokens', () {
        final tokens = Lexer().tokenize('@startwbs\n'
            '* Root\n'
            '** Child\n'
            '@endwbs\n');
        final texts = tokens
            .where((t) => t.type == TokenType.text)
            .map((t) => t.lexeme)
            .toList();
        expect(texts, ['* Root', '** Child']);
      });
    });

    group('json directives', () {
      test('lexes @startjson / @endjson as dedicated tokens', () {
        final tokens = Lexer().tokenize(
            '@startjson\n{"a": 1}\n@endjson\n');
        expect(tokens.first.type, TokenType.startJson);
        expect(
          tokens.any((t) => t.type == TokenType.endJson),
          isTrue,
        );
      });

      test('captures json body lines as raw text tokens preserving spacing',
          () {
        final tokens = Lexer().tokenize('@startjson\n'
            '{\n'
            '  "a": 1\n'
            '}\n'
            '@endjson\n');
        final texts = tokens
            .where((t) => t.type == TokenType.text)
            .map((t) => t.lexeme)
            .toList();
        expect(texts, ['{', '  "a": 1', '}']);
      });
    });

    group('yaml directives', () {
      test('lexes @startyaml / @endyaml as dedicated tokens', () {
        final tokens =
            Lexer().tokenize('@startyaml\na: 1\n@endyaml\n');
        expect(tokens.first.type, TokenType.startYaml);
        expect(
          tokens.any((t) => t.type == TokenType.endYaml),
          isTrue,
        );
      });

      test('captures yaml body lines preserving indentation', () {
        final tokens = Lexer().tokenize('@startyaml\n'
            'name: Alice\n'
            'address:\n'
            '  city: Seoul\n'
            '@endyaml\n');
        final texts = tokens
            .where((t) => t.type == TokenType.text)
            .map((t) => t.lexeme)
            .toList();
        expect(texts, ['name: Alice', 'address:', '  city: Seoul']);
      });
    });

    group('salt directives', () {
      test('lexes @startsalt / @endsalt as dedicated tokens', () {
        final tokens =
            Lexer().tokenize('@startsalt\n{\n[Ok]\n}\n@endsalt\n');
        expect(tokens.first.type, TokenType.startSalt);
        expect(
          tokens.any((t) => t.type == TokenType.endSalt),
          isTrue,
        );
      });

      test('captures salt body lines as raw text tokens', () {
        final tokens = Lexer().tokenize('@startsalt\n'
            '{\n'
            '  Name | "Alice"\n'
            '  [Ok] | [Cancel]\n'
            '}\n'
            '@endsalt\n');
        final texts = tokens
            .where((t) => t.type == TokenType.text)
            .map((t) => t.lexeme)
            .toList();
        expect(texts, [
          '{',
          '  Name | "Alice"',
          '  [Ok] | [Cancel]',
          '}',
        ]);
      });
    });

    group('gantt directives', () {
      test('lexes @startgantt / @endgantt as dedicated tokens', () {
        final tokens = Lexer()
            .tokenize('@startgantt\nProject starts 2026-01-01\n@endgantt\n');
        expect(tokens.first.type, TokenType.startGantt);
        expect(
          tokens.any((t) => t.type == TokenType.endGantt),
          isTrue,
        );
      });

      test('captures gantt body lines verbatim as text tokens', () {
        final tokens = Lexer().tokenize('@startgantt\n'
            'Project starts 2026-01-01\n'
            '[Design] lasts 10 days\n'
            '@endgantt\n');
        final texts = tokens
            .where((t) => t.type == TokenType.text)
            .map((t) => t.lexeme)
            .toList();
        expect(texts, [
          'Project starts 2026-01-01',
          '[Design] lasts 10 days',
        ]);
      });
    });

    group('nwdiag directives', () {
      test('lexes @startnwdiag / @endnwdiag as dedicated tokens', () {
        final tokens = Lexer()
            .tokenize('@startnwdiag\nnetwork dmz {\n}\n@endnwdiag\n');
        expect(tokens.first.type, TokenType.startNwdiag);
        expect(
          tokens.any((t) => t.type == TokenType.endNwdiag),
          isTrue,
        );
      });

      test('captures nwdiag body lines verbatim as text tokens', () {
        final tokens = Lexer().tokenize('@startnwdiag\n'
            'network dmz {\n'
            '  web01 [address = "210.0.0.1"]\n'
            '}\n'
            '@endnwdiag\n');
        final texts = tokens
            .where((t) => t.type == TokenType.text)
            .map((t) => t.lexeme)
            .toList();
        expect(texts, [
          'network dmz {',
          '  web01 [address = "210.0.0.1"]',
          '}',
        ]);
      });
    });

    group('angle bracket disambiguation', () {
      test('emits a stereotype token for <<Name>>', () {
        final tokens =
            Lexer().tokenize('@startuml\nclass Foo <<Aggregate>>\n@enduml\n');
        final stereos = tokens
            .where((t) => t.type == TokenType.stereotype)
            .map((t) => t.lexeme)
            .toList();
        expect(stereos, ['Aggregate']);
      });

      test('emits a generics token with balanced angle brackets', () {
        final tokens = Lexer().tokenize(
            '@startuml\nclass Foo<T extends Bar<U>, V>\n@enduml\n');
        final generics = tokens
            .where((t) => t.type == TokenType.generics)
            .map((t) => t.lexeme)
            .toList();
        expect(generics, ['T extends Bar<U>, V']);
      });

      test('preserves backward arrows after generics rule', () {
        final tokens = Lexer().tokenize('@startuml\nA <-- B\n@enduml\n');
        final arrows = tokens
            .where((t) => t.type == TokenType.arrow)
            .map((t) => t.lexeme)
            .toList();
        expect(arrows, ['<--']);
      });

      test('preserves class inheritance arrows', () {
        final tokens =
            Lexer().tokenize('@startuml\nA <|-- B\nC <|.. D\n@enduml\n');
        final arrows = tokens
            .where((t) => t.type == TokenType.arrow)
            .map((t) => t.lexeme)
            .toList();
        expect(arrows, ['<|--', '<|..']);
      });

      test('preserves <<-- backward open V arrow', () {
        final tokens = Lexer().tokenize('@startuml\nA <<-- B\n@enduml\n');
        final arrows = tokens
            .where((t) => t.type == TokenType.arrow)
            .map((t) => t.lexeme)
            .toList();
        expect(arrows, ['<<--']);
      });
    });

    group('hyphen in identifier', () {
      test('lexes Multi-region as a single identifier', () {
        final tokens = Lexer()
            .tokenize('@startuml\ntitle Multi-region deployment\n@enduml\n');
        final identifiers = tokens
            .where((t) => t.type == TokenType.identifier)
            .map((t) => t.lexeme)
            .toList();
        expect(identifiers, contains('Multi-region'));
      });

      test('hyphen between identifier characters does not break arrows', () {
        final tokens = Lexer().tokenize('@startuml\nfoo-bar -> baz\n@enduml\n');
        final identifiers = tokens
            .where((t) => t.type == TokenType.identifier)
            .map((t) => t.lexeme)
            .toList();
        final arrows = tokens
            .where((t) => t.type == TokenType.arrow)
            .map((t) => t.lexeme)
            .toList();
        expect(identifiers, ['foo-bar', 'baz']);
        expect(arrows, ['->']);
      });

      test('trailing hyphen before whitespace is not consumed', () {
        final tokens = Lexer().tokenize('@startuml\nA --> B\n@enduml\n');
        final arrows = tokens
            .where((t) => t.type == TokenType.arrow)
            .map((t) => t.lexeme)
            .toList();
        expect(arrows, ['-->']);
      });
    });

    group('string literal escapes', () {
      test('\\n inside a string becomes a real newline', () {
        final tokens =
            Lexer().tokenize('@startuml\n"first\\nsecond"\n@enduml\n');
        final str = tokens
            .firstWhere((t) => t.type == TokenType.stringLiteral)
            .lexeme;
        expect(str, 'first\nsecond');
      });

      test('\\" inside a string becomes a literal double quote', () {
        final tokens =
            Lexer().tokenize('@startuml\n"say \\"hi\\""\n@enduml\n');
        final str = tokens
            .firstWhere((t) => t.type == TokenType.stringLiteral)
            .lexeme;
        expect(str, 'say "hi"');
      });

      test('\\\\ inside a string becomes a single backslash', () {
        final tokens = Lexer().tokenize('@startuml\n"a\\\\b"\n@enduml\n');
        final str = tokens
            .firstWhere((t) => t.type == TokenType.stringLiteral)
            .lexeme;
        expect(str, 'a\\b');
      });
    });
  });
}
