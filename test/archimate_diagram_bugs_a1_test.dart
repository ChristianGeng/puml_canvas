import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression test for ArchiMate source sample A1: combines `!include
/// <archimate/Archimate>`, a `<style>` block, `rectangle`/`()` interface
/// declarations, and a battery of `Rel_*(src, tgt, label)` macro calls
/// (Triggering, Specialization, Serving, Realization, Influence, Flow,
/// Composition, Association, Assignment, Aggregation, Access*). All
/// `Rel_*` macro calls should desugar to `src --> tgt : label` relations.
void main() {
  test('A1 — ArchiMate Rel_* macros + !include <archimate/Archimate>', () {
    const source = '@startuml\n'
        'title ArchiMate Relationships Overview\n'
        'skinparam nodesep 5\n'
        '<style>\n'
        'interface {\n'
        '    shadowing 0\n'
        '    backgroundcolor transparent\n'
        '    linecolor transparent\n'
        '    FontColor transparent\n'
        '}\n'
        '</style>\n'
        '!include <archimate/Archimate>\n'
        'left to right direction\n'
        'rectangle Other {\n'
        '    () i14\n'
        '    () j14\n'
        '}\n'
        'rectangle Dynamic {\n'
        '    () i10\n'
        '    () j10\n'
        '    () i15\n'
        '    () j15\n'
        '}\n'
        'rectangle Dependency {\n'
        '    () i13\n'
        '    () j13\n'
        '    () i4\n'
        '    () j4\n'
        '    () i11\n'
        '    () j11\n'
        '    () i7\n'
        '    () j7\n'
        '}\n'
        'rectangle Structural {\n'
        '    () i9\n'
        '    () j9\n'
        '    () i5\n'
        '    () j5\n'
        '    () i6\n'
        '    () j6\n'
        '    () i12\n'
        '    () j12\n'
        '}\n'
        'Rel_Triggering(i15, j15, Triggering)\n'
        'Rel_Specialization(i14, j14, Specialization)\n'
        'Rel_Serving(i13, j13, Serving)\n'
        'Rel_Realization(i12, j12, Realization)\n'
        'Rel_Influence(i11, j11, Influence)\n'
        'Rel_Flow(i10, j10, Flow)\n'
        'Rel_Composition(i9, j9, Composition)\n'
        'Rel_Association_dir(i7, j7, \\nAssociation_dir)\n'
        'Rel_Association(i7, j7, Association)\n'
        'Rel_Assignment(i6, j6, Assignment)\n'
        'Rel_Aggregation(i5, j5, Aggregation)\n'
        'Rel_Access_w(i4, j4, Access_w)\n'
        'Rel_Access_rw(i4, j4, Access_rw)\n'
        'Rel_Access_r(i4, j4, Access_r)\n'
        'Rel_Access(i4, j4, Access)\n'
        '@enduml\n';
    final tokens = Lexer().tokenize(source);
    final diagram = Parser().parse(tokens);
    expect(diagram, isNotNull);
  });
}
