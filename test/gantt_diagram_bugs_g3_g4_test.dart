import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/ast/diagram.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression tests for Gantt source samples G3 and G4. G3 exercises
/// `projectscale` + `zoom`, natural-language `Project starts the Nth of
/// MonthName YYYY`, gradient-style `is colored in C1/C2`, raw `->`
/// dependency arrows, and `YYYY-MM-DD to YYYY-MM-DD are colored in Color`
/// date-range coloring. G4 exercises `printscale weekly with week
/// numbering from N`, resource assignment `[Task] on {Name[:N%]}`, and
/// `then`-chained `requires` clauses.
void main() {
  GanttDiagram parseGantt(String src) {
    final tokens = Lexer().tokenize(src);
    final diagram = Parser().parse(tokens);
    expect(diagram, isA<GanttDiagram>());
    return diagram as GanttDiagram;
  }

  group('gantt diagram bugs G3-G4', () {
    test('G3 — projectscale + zoom + natural date + dep arrow + range color',
        () {
      const source = '@startgantt\n'
          'projectscale yearly\n'
          'zoom 2\n'
          'Project starts the 1st of october 2020\n'
          '[Prototype design] as [TASK1] requires 700 days\n'
          '[TASK1] is colored in Lavender/LightBlue\n'
          '[Testing] requires 200 days\n'
          '[TASK1]->[Testing]\n'
          '2021-01-18 to 2021-03-22 are colored in salmon\n'
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });

    test('G4 — printscale + resource assignment + then chaining', () {
      const source = '@startgantt\n'
          'printscale weekly with week numbering from 1\n'
          'Project starts the 6th of July 2020\n'
          '[Task1] on {Alice} requires 2 weeks\n'
          '[Task2] on {Bob:50%} requires 2 weeks then [Task3] on {Alice:25%} requires 3 days\n'
          '@endgantt\n';
      final d = parseGantt(source);
      expect(d.items, isNotEmpty);
    });
  });
}
