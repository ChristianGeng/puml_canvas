import 'package:flutter_test/flutter_test.dart';
import 'package:puml_canvas/src/ast/diagram.dart';
import 'package:puml_canvas/src/lexer/lexer.dart';
import 'package:puml_canvas/src/parser/parser.dart';

/// Regression test for the Mindmap source M1 sample: PlantUML supports `+` /
/// `-` markers (side selection by sign) and `_` boxless variants, mirroring
/// WBS marker semantics. The shared `_parseMindmapLine` should already accept
/// these forms — this test pins the behaviour.
void main() {
  MindmapDiagram parseMindmap(String src) {
    final tokens = Lexer().tokenize(src);
    final diagram = Parser().parse(tokens);
    expect(diagram, isA<MindmapDiagram>());
    return diagram as MindmapDiagram;
  }

  test('M1 — +/- markers plus _ boxless variants', () {
    const source = '@startmindmap\n'
        '+ root node\n'
        '++ some first level node\n'
        '+++_ second level node\n'
        '+++_ another second level node\n'
        '+++_ foo\n'
        '+++_ bar\n'
        '+++_ foobar\n'
        '++_ another first level node\n'
        '-- some first right level node\n'
        '--_ another first right level node\n'
        '@endmindmap\n';
    final d = parseMindmap(source);
    expect(d.root, isNotNull);
  });
}
