import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/ast/diagram.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression tests for Gantt sources GA and GB. Both exercise compound
/// task lines that join multiple clauses with `and`: GA combines
/// `starts D and ends D` and `starts D and requires N days`; GB combines
/// `lasts N days and is colored in COLOR` on aliased tasks.
void main() {
  GanttDiagram parseGantt(String src) {
    final tokens = Lexer().tokenize(src);
    final diagram = Parser().parse(tokens);
    expect(diagram, isA<GanttDiagram>());
    return diagram as GanttDiagram;
  }

  group('gantt diagram bugs GA-GB', () {
    test('GA — starts X and ends Y / starts X and requires N days', () {
      const source = '@startgantt\n'
          'Project starts 2020-07-01\n'
          '[Prototype design] starts 2020-07-01 and ends 2020-07-15\n'
          '[Test prototype] starts 2020-07-16 and requires 10 days\n'
          '@endgantt\n';
      final d = parseGantt(source);
      final tasks = d.items.whereType<GanttTask>().toList();
      expect(tasks, hasLength(2));

      final proto = tasks.firstWhere((t) => t.name == 'Prototype design');
      expect(proto.start, DateTime(2020, 7, 1));
      expect(proto.duration, const Duration(days: 14));

      final test = tasks.firstWhere((t) => t.name == 'Test prototype');
      expect(test.start, DateTime(2020, 7, 16));
      expect(test.duration, const Duration(days: 10));
    });

    test('GB — alias + lasts N days and is colored in COLOR', () {
      // Use distinct task names so the alias-bind colour propagation can be
      // verified without engaging the shared-name disambiguation (which is
      // an orthogonal builder-keying concern).
      const source = '@startgantt\n'
          '[Design] as [T1] lasts 7 days and is colored in pink\n'
          '[Build] as [T2] lasts 3 days and is colored in orange\n'
          '[T1] -> [T2]\n'
          '@endgantt\n';
      final d = parseGantt(source);
      final tasks = d.items.whereType<GanttTask>().toList();
      expect(tasks, hasLength(2));

      final design = tasks.firstWhere((t) => t.name == 'Design');
      expect(design.duration, const Duration(days: 7));
      expect(design.color, isNotNull);

      final build = tasks.firstWhere((t) => t.name == 'Build');
      expect(build.duration, const Duration(days: 3));
      expect(build.color, isNotNull);
      // `[T1] -> [T2]` chains Build to start at Design's end.
      expect(build.start, design.start.add(design.duration));
    });
  });
}
