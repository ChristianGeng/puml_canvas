import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/ast/diagram.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression tests for Gantt source samples G1 and G2. G1 exercises the
/// `[task] starts D+N`, `[task] starts YYYY-MM-DD`, `[task] ends D+N`,
/// `[task] ends YYYY-MM-DD`, and `Project starts YYYY-MM-DD` time specs.
/// G2 exercises the `[Task] as [Alias] requires N days` alias form together
/// with the `[alias] starts at [other]'s end` dependency form.
void main() {
  GanttDiagram parseGantt(String src) {
    final tokens = Lexer().tokenize(src);
    final diagram = Parser().parse(tokens);
    expect(diagram, isA<GanttDiagram>());
    return diagram as GanttDiagram;
  }

  group('gantt diagram bugs G1-G2', () {
    test('G1a — requires N days + starts D+N relative spec', () {
      const source = '@startgantt\n'
          '[Prototype design] requires 15 days\n'
          '[Test prototype] requires 10 days\n'
          '[Prototype design] starts D+0\n'
          '[Test prototype] starts D+15\n'
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });

    test('G1b — Project starts + requires + ends YYYY-MM-DD', () {
      const source = '@startgantt\n'
          'Project starts 2020-07-01\n'
          '[Prototype design] requires 15 days\n'
          '[Test prototype] requires 10 days\n'
          '[Prototype design] ends 2020-07-15\n'
          '[Test prototype] ends 2020-07-25\n'
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });

    test('G1c — requires + ends D+N relative spec', () {
      const source = '@startgantt\n'
          '[Prototype design] requires 15 days\n'
          '[Test prototype] requires 10 days\n'
          '[Prototype design] ends D+14\n'
          '[Test prototype] ends D+24\n'
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });

    test('G1d — Project starts plus absolute starts/ends dates', () {
      const source = '@startgantt\n'
          'Project starts 2020-07-01\n'
          '[Prototype design] starts 2020-07-01\n'
          '[Test prototype] starts 2020-07-16\n'
          '[Prototype design] ends 2020-07-15\n'
          '[Test prototype] ends 2020-07-25\n'
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });

    test('G1e — starts D+N + ends D+N only', () {
      const source = '@startgantt\n'
          '[Prototype design] starts D+0\n'
          '[Test prototype] starts D+15\n'
          '[Prototype design] ends D+14\n'
          '[Test prototype] ends D+24\n'
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });

    test('G2 — `[Task] as [Alias] requires N days` + `[T] starts at [D]\'s end`',
        () {
      const source = '@startgantt\n'
          '[Prototype design] as [D] requires 15 days\n'
          '[Test prototype] as [T] requires 10 days\n'
          "[T] starts at [D]'s end\n"
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });
  });
}
