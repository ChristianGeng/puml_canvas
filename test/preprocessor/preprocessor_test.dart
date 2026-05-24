import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/puml_canvas.dart';

void main() {
  group('Preprocessor', () {
    test('passes through source with no directives unchanged', () {
      const source = '@startuml\nA -> B : hi\n@enduml\n';
      expect(Preprocessor().preprocess(source), source);
    });

    test('!define substitutes a simple macro', () {
      final out = Preprocessor().preprocess(
        '!define X 42\nvalue=X\n',
      );
      expect(out.trim(), 'value=42');
    });

    test('!define with function-like macro substitutes arguments', () {
      final out = Preprocessor().preprocess(
        '!define ADD(a,b) a+b\nresult=ADD(1,2)\n',
      );
      expect(out.trim(), 'result=1+2');
    });

    test('!undef removes a previously defined macro', () {
      final out = Preprocessor().preprocess(
        '!define X 42\n!undef X\nvalue=X\n',
      );
      expect(out.trim(), 'value=X');
    });

    test('!if defined(X) includes block when defined', () {
      final out = Preprocessor().preprocess(
        '!define X 1\n!if defined(X)\nyes\n!endif\n',
      );
      expect(out.trim(), 'yes');
    });

    test('!if defined(X) excludes block when undefined', () {
      final out = Preprocessor().preprocess(
        '!if defined(X)\nyes\n!endif\n',
      );
      expect(out.trim(), '');
    });

    test('!if X == 1 selects then branch', () {
      final out = Preprocessor().preprocess(
        '!define X 1\n!if X == 1\nyes\n!else\nno\n!endif\n',
      );
      expect(out.trim(), 'yes');
    });

    test('!if X == 1 selects else branch when false', () {
      final out = Preprocessor().preprocess(
        '!define X 2\n!if X == 1\nyes\n!else\nno\n!endif\n',
      );
      expect(out.trim(), 'no');
    });

    test('!elseif selects matching branch', () {
      final out = Preprocessor().preprocess(
        '!define X 2\n'
        '!if X == 1\nfirst\n'
        '!elseif X == 2\nsecond\n'
        '!elseif X == 3\nthird\n'
        '!else\nfallback\n'
        '!endif\n',
      );
      expect(out.trim(), 'second');
    });

    test('nested !if works inside !if', () {
      final out = Preprocessor().preprocess(
        '!define X 1\n!define Y 2\n'
        '!if X == 1\n'
        '  outer\n'
        '  !if Y == 2\n'
        '    inner\n'
        '  !endif\n'
        '!endif\n',
      );
      expect(out, contains('outer'));
      expect(out, contains('inner'));
    });

    test('nested !if where outer is false skips inner', () {
      final out = Preprocessor().preprocess(
        '!define X 0\n'
        '!if X == 1\n'
        '  outer\n'
        '  !if defined(Z)\n'
        '    inner\n'
        '  !endif\n'
        '!endif\n',
      );
      expect(out.trim(), '');
    });

    test('!include inlines another file via FileLoader', () {
      String loader(String p) {
        if (p == 'other.puml') return 'A -> B : from other\n';
        throw StateError('unexpected path: $p');
      }

      final out = Preprocessor(fileLoader: loader).preprocess(
        '@startuml\n!include other.puml\n@enduml\n',
      );
      expect(out, contains('A -> B : from other'));
      expect(out, contains('@startuml'));
      expect(out, contains('@enduml'));
    });

    test('!include without FileLoader throws PreprocessorException', () {
      expect(
        () => Preprocessor().preprocess('!include other.puml\n'),
        throwsA(isA<PreprocessorException>()),
      );
    });

    test('!startsub / !endsub / !includesub captures and reuses content', () {
      String loader(String p) {
        if (p == 'lib.puml') {
          return '!startsub greet\n'
              'A -> B : hi\n'
              '!endsub\n'
              '!startsub bye\n'
              'A -> B : bye\n'
              '!endsub\n';
        }
        throw StateError('unexpected path: $p');
      }

      final out = Preprocessor(fileLoader: loader).preprocess(
        '@startuml\n'
        '!includesub lib.puml!greet\n'
        '@enduml\n',
      );
      expect(out, contains('A -> B : hi'));
      expect(out, isNot(contains('A -> B : bye')));
    });

    test('!pragma is ignored', () {
      final out = Preprocessor().preprocess(
        '!pragma layout dot\nhello\n',
      );
      expect(out.trim(), 'hello');
    });

    test('macro substitution does not run inside double-quoted strings', () {
      final out = Preprocessor().preprocess(
        '!define X 42\nA -> B : "X is X"\n',
      );
      expect(out, contains('"X is X"'));
      expect(out, isNot(contains('"42 is 42"')));
    });

    test('unknown identifiers are passed through as-is', () {
      final out = Preprocessor().preprocess('A -> B : hello\n');
      expect(out.trim(), 'A -> B : hello');
    });

    test('!define value-form with no body defines empty macro', () {
      final out = Preprocessor().preprocess(
        '!define X\n!if defined(X)\nyes\n!endif\n',
      );
      expect(out.trim(), 'yes');
    });

    test('!if string equality on macro value', () {
      final out = Preprocessor().preprocess(
        '!define MODE prod\n'
        '!if MODE == "prod"\n'
        'production\n'
        '!else\n'
        'other\n'
        '!endif\n',
      );
      expect(out.trim(), 'production');
    });

    test('!if with && and || operators', () {
      final out = Preprocessor().preprocess(
        '!define X 1\n!define Y 2\n'
        '!if X == 1 && Y == 2\nboth\n!endif\n',
      );
      expect(out.trim(), 'both');
    });

    test('!if with negation', () {
      final out = Preprocessor().preprocess(
        '!if !defined(X)\nundef\n!endif\n',
      );
      expect(out.trim(), 'undef');
    });

    test('unterminated !if throws', () {
      expect(
        () => Preprocessor().preprocess('!if defined(X)\nfoo\n'),
        throwsA(isA<PreprocessorException>()),
      );
    });

    test('!endif without !if throws', () {
      expect(
        () => Preprocessor().preprocess('!endif\n'),
        throwsA(isA<PreprocessorException>()),
      );
    });

    test('!include with sub-id form (path!sub_id)', () {
      String loader(String p) {
        if (p == 'lib.puml') {
          return '!startsub one\nfirst\n!endsub\n'
              '!startsub two\nsecond\n!endsub\n';
        }
        throw StateError('unexpected path: $p');
      }

      final out = Preprocessor(fileLoader: loader)
          .preprocess('!include lib.puml!two\n');
      expect(out.trim(), 'second');
    });

    test('circular include is detected', () {
      late Preprocessor p;
      String loader(String path) {
        if (path == 'a.puml') return '!include b.puml\n';
        if (path == 'b.puml') return '!include a.puml\n';
        throw StateError('unexpected: $path');
      }

      p = Preprocessor(fileLoader: loader);
      expect(
        () => p.preprocess('!include a.puml\n'),
        throwsA(isA<PreprocessorException>()),
      );
    });
  });
}
